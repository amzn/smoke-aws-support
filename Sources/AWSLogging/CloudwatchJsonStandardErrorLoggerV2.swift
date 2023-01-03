// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
// CloudwatchJsonStandardErrorLogger.swift
// AWSLogging
//

import Foundation
import Logging

private let sourcesSubString = "Sources/"

struct Entry {
    let level: Logger.Level
    let message: Logger.Message
    let metadata: Logger.Metadata?
    let file: String
    let function: String
    let line: UInt
    
    func log(globalMetadata: Logger.Metadata, jsonEncoder: JSONEncoder,
             stream: TextOutputStream) {
        let shortFileName: String
        if let range = file.range(of: "Sources/") {
            let startIndex = file.index(range.lowerBound, offsetBy: sourcesSubString.count)
            shortFileName = String(file[startIndex...])
        } else {
            shortFileName = file
        }
        
        let metadataToUse: Logger.Metadata
        if let metadata = metadata {
            metadataToUse = globalMetadata.merging(metadata) { (global, local) in local }
        } else {
            metadataToUse = globalMetadata
        }
        
        var codableMetadata: [String: String] = [:]
        metadataToUse.forEach { (key, value) in
            codableMetadata[key] = value.description
        }
        
        codableMetadata["fileName"] = shortFileName
        codableMetadata["line"] = "\(line)"
        codableMetadata["function"] = function
        codableMetadata["level"] = level.rawValue
        codableMetadata["message"] = "\(message)"
        
        if let jsonData = try? jsonEncoder.encode(codableMetadata),
           let jsonMessage = String(data: jsonData, encoding: .utf8) {
            var mutableStream = stream
            mutableStream.write("\(jsonMessage)\n")
        }
    }
}

/**
 Implementation of the Logger protocol that emits logs as
 required to Standard error to be picked up by Cloudwatch logs.
 */
public struct CloudwatchJsonStandardErrorLoggerV2: LogHandler {
    public var metadata: Logger.Metadata
    public var logLevel: Logger.Level
    
    private let jsonEncoder: JSONEncoder
    private let stream: TextOutputStream
    private let entryStream: AsyncStream<Entry>
    private let entryHander: (Entry) -> ()
    private let finishHandler: () -> ()
    
    private init(minimumLogLevel: Logger.Level) {
        self.logLevel = minimumLogLevel
        self.metadata = [:]
        
        let theJsonEncoder = JSONEncoder()
        theJsonEncoder.outputFormatting = [.sortedKeys]
        
        self.jsonEncoder = theJsonEncoder
        self.stream = StdioOutputStream.stderr
        
        var newEntryHandler: ((Entry) -> ())?
        var newFinishHandler: (() -> ())?
        self.entryStream = AsyncStream { continuation in
            newEntryHandler = { entry in
                continuation.yield(entry)
            }
            
            newFinishHandler = {
                continuation.finish()
            }
        }
        
        guard let newEntryHandler = newEntryHandler, let newFinishHandler = newFinishHandler else {
            fatalError()
        }
                
        self.entryHander = newEntryHandler
        self.finishHandler = newFinishHandler
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
    public static func enableLogging(minimumLogLevel: Logger.Level = .info) {
        LoggingSystem.bootstrap { label in
            return CloudwatchJsonStandardErrorLoggerV2(minimumLogLevel: minimumLogLevel)
        }
    }
    
    public func log(level: Logger.Level, message: Logger.Message,
                    metadata: Logger.Metadata?, file: String, function: String, line: UInt) {
        let entry = Entry(level: level, message: message, metadata: metadata, file: file, function: function, line: line)
        self.entryHander(entry)
    }
    
    public func start() {
        Task {
            for await entry in self.entryStream {
                Task {
                    entry.log(globalMetadata: self.metadata, jsonEncoder: self.jsonEncoder, stream: self.stream)
                }
            }
        }
    }
    
    public func stop() {
        self.finishHandler()
    }
}
