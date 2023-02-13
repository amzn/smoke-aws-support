//
// JSONDataTests.swift
// AWSLoggingTests
//

@testable import AWSLogging
import XCTest
import Logging

class StringStream: TextOutputStream & Flushable {
    var buffer: String = ""
    
    func write(_ string: String) {
        buffer.write(string)
    }
    
    func flush() {
        // nothing to do
    }
}

class JSONDataTests: XCTestCase {

    func testSimpleJSONString() async throws {
        let fields: [(String, JSONValue)] = [("field1", .string("value1")),
                                             ("field2", .number("62"))
        ]
        
        let expected =
            #"{"field1":"value1","field2":62}"#
                
        let jsonObject: JSONValue = .object(fields)
        let stringStream = StringStream()
        var output: TextOutputStream = stringStream
        jsonObject.appendBytes(to: &output)
        XCTAssertEqual(expected, stringStream.buffer)
    }
    
    func testEscapedJSONString() async throws {
        let fields1: [(String, JSONValue)] = [("field1", .string("value1")),
                                             ("field2", .number("62"))
        ]
        let jsonObject1: JSONValue = .object(fields1)
        let stringStream1 = StringStream()
        var output1: TextOutputStream = stringStream1
        jsonObject1.appendBytes(to: &output1)
        let jsonString1 = stringStream1.buffer
        
        let fields2: [(String, JSONValue)] = [("fields", .string(jsonString1)),
                                             ("field22", .number("88"))
        ]
        
        // Use a raw string to compare escaping
        let expected =
            #"{"fields":"{\"field1\":\"value1\",\"field2\":62}","field22":88}"#
                
        let jsonObject2: JSONValue = .object(fields2)
        let stringStream2 = StringStream()
        var output2: TextOutputStream = stringStream2
        jsonObject2.appendBytes(to: &output2)
        XCTAssertEqual(expected, stringStream2.buffer)
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
                
        let expected =
            #"{"field1":"Value1","field2":45,"field3":"Value4","fileName":"AWSLogging/CloudwatchJsonStandardErrorLoggerV2.swift""#
            + #","function":"MyFunction","level":"info","line":52,"message":"This is the message"}"#
            + "\n"
                
        let stringStream = StringStream()
        logEntry.writeJsonMessage(to: stringStream, globalMetadata: globalMetadata, metadataTypes: ["field2" : MetadataType.Int])
        XCTAssertEqual(expected, stringStream.buffer)
    }
}
