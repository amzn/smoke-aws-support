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
//  DataOutwardTransformer.swift
//  AWSMiddleware
//

import AWSCore
import SwiftMiddleware
import SmokeHTTPMiddleware
import ClientRuntime
import SmokeHTTPClient
import QueryCoding
import HTTPHeadersCoding
import HTTPPathCoding

enum DataOutwardTransformerError: Error {
    case invalidPayloadNotData
}

public struct DataOutwardTransformer<Output: HTTPResponseOutputProtocol, Context: AWSMiddlewareContext>: TransformProtocol {
    public typealias Input = HttpResponse
    
    public init() {
    }
    
    public func transform(_ output: HttpResponse, context: Context) async throws -> Output {
        func bodyDecodableProvider() throws -> Output.BodyType {
            let responseBodyOptional: Data?
            switch output.body {
            case .data(let data):
                responseBodyOptional = data
            case .stream(let reader):
                responseBodyOptional = reader.toBytes().getData()
            case .none:
                responseBodyOptional = nil
            }
            // we are expecting a response body
            guard let responseBody = responseBodyOptional else {
                throw HTTPError.badResponse("Unexpected empty response.")
            }
            
            // Convert output to a debug string only if debug logging is enabled
            context.logger.trace("Attempting to decode result data from JSON to \(Output.self)",
                                             metadata: ["body": "\(responseBody.debugString)"])
            
            guard let bodyEncodable = responseBody as? Output.BodyType else {
                throw DataOutwardTransformerError.invalidPayloadNotData
            }
            
            return bodyEncodable
        }
        
        let mappedHeaders: [(String, String?)] = output.headers.headers.flatMap { header in
            return header.value.map { value in
                return (header.name, value)
            }
        }
        func headersDecodableProvider() throws -> Output.HeadersType {
            let headersDecoder = HTTPHeadersDecoder(keyDecodingStrategy: .useShapePrefix)
            return try headersDecoder.decode(Output.HeadersType.self,
                                             from: mappedHeaders)
        }
        
        return try Output.compose(bodyDecodableProvider: bodyDecodableProvider,
                                  headersDecodableProvider: headersDecodableProvider)
    }
}
