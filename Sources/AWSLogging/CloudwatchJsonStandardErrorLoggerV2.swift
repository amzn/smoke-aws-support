//
//  CloudWatchPendingMetricsQueueV2.swift
//  SmokeExtras
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
 */
internal struct CloudwatchJsonStandardErrorLoggerV2: LogHandler {
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
        let rawEntryStream = AsyncStream { continuation in
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
            let metadataType: MetadataType
            if let theMetadataType = self.metadataTypes[key] {
                metadataType = theMetadataType
            } else {
                metadataType = .String
            }
            
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
        
        DispatchQueue.global().async {
            let logEntry = LogEntry(stringFields: codableMetadata, integerFields: codableMetadataInts)
            if let jsonData = try? self.jsonEncoder.encode(logEntry),
               let jsonMessage = String(data: jsonData, encoding: .utf8) {
                self.entryHander(jsonMessage)
            }
        }
    }
}
