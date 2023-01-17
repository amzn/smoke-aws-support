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

private struct LogEntry: Encodable {
    let stringFields: [String: String]
    let integerFields: [String: Int]
    
    func encode(to encoder: Encoder) throws {
        try self.stringFields.encode(to: encoder)
        try self.integerFields.encode(to: encoder)
    }
}

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
    
    private let jsonEncoder: JSONEncoder
    
    private let entryStream: AsyncStream<String>
    private let stream: TextOutputStream
    private let entryHander: (String) -> ()
    private let entryQueueFinishHandler: () -> ()
    private let metadataTypes: [String: MetadataType]
    
    private init(minimumLogLevel: Logger.Level,
                 metadataTypes: [String: MetadataType]) {
        self.logLevel = minimumLogLevel
        self.metadata = [:]
        self.metadataTypes = metadataTypes
        
        let theJsonEncoder = JSONEncoder()
        theJsonEncoder.outputFormatting = [.sortedKeys]
        
        self.jsonEncoder = theJsonEncoder
        
        var newEntryHandler: ((String) -> ())?
        var newEntryQueueFinishHandler: (() -> ())?
        // create an async stream with a handler for adding new elments
        // and a handler for finishing the stream
        let rawEntryStream = AsyncStream<String> { continuation in
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
        self.entryHander = newEntryHandler
        self.entryQueueFinishHandler = newEntryQueueFinishHandler
        self.stream = NonLockingStdioOutputStream.stderr
    }
    
    public func shutdown() {
        self.entryQueueFinishHandler()
    }
    
    // Consume the log entries from the entryStream.
    // This function will not return until after `shutdown()`
    // is called.
    public func run() async {
        for await jsonMessage in self.entryStream {
            var stream = self.stream
            stream.write("\(jsonMessage)\n")
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
        let shortFileName: String
        if let range = file.range(of: "Sources/") {
            let startIndex = file.index(range.lowerBound, offsetBy: sourcesSubString.count)
            shortFileName = String(file[startIndex...])
        } else {
            shortFileName = file
        }
        
        let metadataToUse: Logger.Metadata
        if let metadata = metadata {
            metadataToUse = self.metadata.merging(metadata) { (global, local) in local }
        } else {
            metadataToUse = self.metadata
        }
        
        var codableMetadata: [String: String] = [:]
        var codableMetadataInts: [String: Int] = [:]
        metadataToUse.forEach { (key, value) in
            // determine the metadata type
            let metadataType: MetadataType
            if let theMetadataType = self.metadataTypes[key] {
                metadataType = theMetadataType
            } else {
                metadataType = .String
            }
            
            // add to the appropriate dictionary, converting if necessary
            switch metadataType {
            case .String:
                codableMetadata[key] = value.description
            case .Int:
                codableMetadataInts[key] = Int(value.description)
            }
        }
        
        codableMetadata["fileName"] = shortFileName
        codableMetadataInts["line"] = Int(line)
        codableMetadata["function"] = function
        codableMetadata["level"] = level.rawValue
        codableMetadata["message"] = "\(message)"
        
        // pass to the global dispatch queue for serialization
        // schedule at a low priority to avoid disrupting request handling
        DispatchQueue.global().async(qos: .utility) {
            let logEntry = LogEntry(stringFields: codableMetadata, integerFields: codableMetadataInts)
            if let jsonData = try? self.jsonEncoder.encode(logEntry),
               let jsonMessage = String(data: jsonData, encoding: .utf8) {
                // pass to the entry queue
                self.entryHander(jsonMessage)
            }
        }
    }
}
