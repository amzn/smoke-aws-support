// Copyright Amazon.com, Inc. or its affiliates. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License").
// You may not use this file except in compliance with the License.
// A copy of the License is located at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// or in the "license" file accompanying this file. This file is distributed
// on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either
// express or implied. See the License for the specific language governing
// permissions and limitations under the License.
//
// CloudwatchJsonStandardErrorLoggerV2.swift
// AWSLogging
//

import Foundation
import Logging

private let sourcesSubString = "Sources/"

public enum MetadataType {
    case String
    case Int
}

/**
 Implementation of the Logger protocol that emits logs as
 required to Standard error to be picked up by Cloudwatch logs.
 
 Serialises the JSON payload of each log line on DispatchQueue.global()
 before submitting each to an AsyncSequence. This sequence is consumed
 in the `run()` function, resulting in a non-blocking implementation.
 
 Named metadata entries can be specified as a particular `MetadataType` and they will
 be emitted in the JSON structure appropriately. Unspecified metadata entries will be emitted as
 strings.
 */
public struct CloudwatchJsonStandardErrorLoggerV2: LogHandler {
    public var metadata: Logger.Metadata
    public var logLevel: Logger.Level
    
    private let entryStream: AsyncStream<LogEntry>
    private let stream: TextOutputStream & Flushable
    private let entryHandler: (LogEntry) -> ()
    private let entryQueueFinishHandler: () -> ()
    private let metadataTypes: [String: MetadataType]
    private let offTaskAsyncExecutor = OffTaskAsyncExecutor()
    
    private init(minimumLogLevel: Logger.Level,
                 metadataTypes: [String: MetadataType]) {
        self.logLevel = minimumLogLevel
        self.metadata = [:]
        self.metadataTypes = metadataTypes
        
        var newEntryHandler: ((LogEntry) -> ())?
        var newEntryQueueFinishHandler: (() -> ())?
        // create an async stream with a handler for adding new elements
        // and a handler for finishing the stream
        let rawEntryStream = AsyncStream<LogEntry> { continuation in
            newEntryHandler = { entry in
                continuation.yield(entry)
            }
            
            newEntryQueueFinishHandler = {
                continuation.finish()
            }
        }
        
        guard let newEntryHandler = newEntryHandler, let newEntryQueueFinishHandler = newEntryQueueFinishHandler else {
            fatalError()
        }
        
        self.entryStream = rawEntryStream
        self.entryHandler = newEntryHandler
        self.entryQueueFinishHandler = newEntryQueueFinishHandler
        self.stream = NonLockingStdioOutputStream.noFlushStderr
    }
    
    public func shutdown() {
        self.entryQueueFinishHandler()
    }
    
    // Consume the log entries from the entryStream.
    // This function will not return until after `shutdown()`
    // is called.
    public func run() async {
        for await logEntry in self.entryStream {
            await self.offTaskAsyncExecutor.execute(qos: .utility) {
                logEntry.writeJsonMessage(to: self.stream, globalMetadata: self.metadata, metadataTypes: self.metadataTypes)
            }
        }
    }
    
    public subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
        get {
            return metadata[metadataKey]
        }
        set {
            metadata[metadataKey] = newValue
        }
    }
    
    /**
     Set the logger implementation of the LoggerAPI to this type.
     */
    public static func enableLogging(minimumLogLevel: Logger.Level = .info,
                                     metadataTypes: [String: MetadataType] = [:]) -> CloudwatchJsonStandardErrorLoggerV2 {
        let logger = CloudwatchJsonStandardErrorLoggerV2(minimumLogLevel: minimumLogLevel, metadataTypes: metadataTypes)
        
        LoggingSystem.bootstrap { label in
            return logger
        }
        
        return logger
    }
    
    public func log(level: Logger.Level, message: Logger.Message,
                    metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        let logEntry = LogEntry(level: level, message: message, metadata: metadata,
                                file: file, function: function, line: line)
        
        // pass to the entry queue
        self.entryHandler(logEntry)
    }
}

internal struct LogEntry {
    let level: Logger.Level
    let message: Logger.Message
    let metadata: Logger.Metadata?
    let file: String
    let function: String
    let line: UInt

    func writeJsonMessage(to stream: TextOutputStream & Flushable,
                          globalMetadata: Logger.Metadata,
                          metadataTypes: [String: MetadataType]) {
        let shortFileName: String
        if let range = self.file.range(of: "Sources/") {
            let startIndex = self.file.index(range.lowerBound, offsetBy: sourcesSubString.count)
            shortFileName = String(self.file[startIndex...])
        } else {
            shortFileName = self.file
        }
        
        let metadataToUse: [String: Logger.MetadataValue]
        if let metadata = self.metadata {
            metadataToUse = globalMetadata.merging(metadata) { (global, local) in local }
        } else {
            metadataToUse = globalMetadata
        }
        
        var jsonValues: [(String, JSONValue)] = []
        for (key, value) in metadataToUse {
            // determine the metadata type
            let metadataType: MetadataType
            if let theMetadataType = metadataTypes[key] {
                metadataType = theMetadataType
            } else {
                metadataType = .String
            }
            
            // return with the appropriate JSONValue
            switch metadataType {
            case .String:
                jsonValues.append((key, .string(value.description)))
            case .Int:
                jsonValues.append((key, .number(value.description)))
            }
        }
        let lineAsString = String(self.line)
        
        jsonValues.append(("fileName", .string(shortFileName)))
        jsonValues.append(("line", .number(lineAsString)))
        jsonValues.append(("function", .string(self.function)))
        jsonValues.append(("level", .string(self.level.rawValue)))
        jsonValues.append(("message", .string("\(self.message)")))
        
        let sortedJsonValues = jsonValues.sorted { $0.0 < $1.0 }
        let jsonObject: JSONValue = .object(sortedJsonValues)
        
        // get a mutable version of the stream
        var mutableStream: TextOutputStream = stream
        jsonObject.appendBytes(to: &mutableStream)
        mutableStream.write("\n")
        var flushableStream: Flushable = stream
        flushableStream.flush()
    }
}
