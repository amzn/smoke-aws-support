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
//  JSONInwardTransformer.swift
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

public struct JSONInwardTransformer<Input: HTTPRequestInputProtocol, Context>: TransformProtocol {
    public typealias Output = SmokeSdkHttpRequestBuilder
    
    public let httpPath: String
    public let inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?
    
    public init(httpPath: String, inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?) {
        self.httpPath = httpPath
        self.inputQueryMapDecodingStrategy = inputQueryMapDecodingStrategy
    }
    
    public func transform(_ input: Input, context: Context) async throws -> SmokeSdkHttpRequestBuilder {
        let pathPostfix = input.pathPostfix ?? ""
        
        let pathTemplate = "\(httpPath)\(pathPostfix)"
        let path: String
        if let pathEncodable = input.pathEncodable {
            path = try HTTPPathEncoder().encode(pathEncodable,
                                                withTemplate: pathTemplate)
        } else {
            path = pathTemplate
        }
        
        var additionalHeaders = Headers()
        if let additionalHeadersEncodable = input.additionalHeadersEncodable {
            let headersEncoder = HTTPHeadersEncoder(keyEncodingStrategy: .noSeparator)
            let headers = try headersEncoder.encode(additionalHeadersEncodable)
            
            headers.forEach { entry in
                guard let value = entry.1 else {
                    return
                }
                
                additionalHeaders.add(name: entry.0, value: value)
            }
        }
        
        let bodyData: Data
        if let bodyEncodable = input.bodyEncodable {
            bodyData = try JSONEncoder.awsCompatibleEncoder().encode(bodyEncodable)
        } else {
            bodyData = Data()
        }
        
        let queryItems: [URLQueryItem]
        if let queryEncodable = input.queryEncodable {
            let queryEncoder: QueryEncoder
            if let inputQueryMapDecodingStrategy = inputQueryMapDecodingStrategy {
                queryEncoder = QueryEncoder(mapEncodingStrategy: inputQueryMapDecodingStrategy)
            } else {
                queryEncoder = QueryEncoder()
            }
            queryItems = try queryEncoder.encodeToArray(queryEncodable,
                                                              allowedCharacterSet: .uriAWSQueryValueAllowed)
        } else {
            queryItems = []
        }
        
        let builder = SmokeSdkHttpRequestBuilder()
        builder.withBody(.data(bodyData))
        builder.withHeaders(additionalHeaders)
        builder.withPath(path)
        builder.withQueryItems(queryItems)
        
        return builder
    }
}
