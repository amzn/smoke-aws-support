//
// JSONDataTests.swift
// AWSLoggingTests
//

@testable import AWSLogging
import XCTest
import Logging

class JSONDataTests: XCTestCase {

    func testSimpleJSONString() async throws {
        let fields: [(String, JSONValue)] = [("field1", .string("value1")),
                                             ("field2", .number("62"))
        ]
        
        let expected = """
            {
                "field1": "value1",
                "field2": 62
            }
            """
                
        XCTAssertEqual(expected, fields.jsonString)
    }
    
    func testEscapedJSONString() async throws {
        let fields1: [(String, JSONValue)] = [("field1", .string("value1")),
                                             ("field2", .number("62"))
        ]
        let jsonString1 = fields1.jsonString
        
        let fields2: [(String, JSONValue)] = [("fields", .string(jsonString1)),
                                             ("field22", .number("88"))
        ]
        
        // Use a raw multi-line string to compare escaping
        let expected = #"""
            {
                "fields": "{\n    \"field1\": \"value1\",\n    \"field2\": 62\n}",
                "field22": 88
            }
            """#
                
        XCTAssertEqual(expected, fields2.jsonString)
    }
    
    func testLogEntry() async throws {
        let globalMetadata: [String: Logger.MetadataValue] = ["field1": .string("Value8"),
                                                              "field3": .string("Value4")]
        
        let localMetadata: [String: Logger.MetadataValue] = ["field1": .string("Value1"),
                                                             "field2": .string("45")]
        let logEntry = LogEntry(level: .info,
                                message: "This is the message",
                                metadata: localMetadata,
                                file: "/Prefix/Packages/smoke-aws-support/Sources/AWSLogging/CloudwatchJsonStandardErrorLoggerV2.swift",
                                function: "MyFunction",
                                line: 52)
        
        let jsonMessage = logEntry.getJsonMessage(globalMetadata: globalMetadata, metadataTypes: ["field2" : MetadataType.Int])
        
        let expected = """
            {
                "field1": "Value1",
                "field2": 45,
                "field3": "Value4",
                "fileName": "AWSLogging/CloudwatchJsonStandardErrorLoggerV2.swift",
                "function": "MyFunction",
                "level": "info",
                "line": 52,
                "message": "This is the message"
            }
            """
                
        XCTAssertEqual(expected, jsonMessage)
    }
}
