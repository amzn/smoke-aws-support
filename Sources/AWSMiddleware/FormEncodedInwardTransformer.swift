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
//  FormEncodedInwardTransform.swift
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
import XMLCoding

public struct FormEncodedInwardTransform<Input: HTTPRequestInputProtocol, Context>: TransformProtocol {
    public typealias Output = SmokeSdkHttpRequestBuilder
    
    public let httpPath: String
    public let inputBodyRootKey: String?
    public let inputQueryMapEncodingStrategy: QueryEncoder.MapEncodingStrategy
    public let inputQueryListEncodingStrategy: QueryEncoder.ListEncodingStrategy
    public let inputQueryKeyEncodingStrategy: QueryEncoder.KeyEncodingStrategy
    public let inputQueryKeyEncodeTransformStrategy: QueryEncoder.KeyEncodeTransformStrategy
    
    public init(httpPath: String, inputBodyRootKey: String?, inputQueryMapEncodingStrategy: QueryEncoder.MapEncodingStrategy,
                inputQueryListEncodingStrategy: QueryEncoder.ListEncodingStrategy, inputQueryKeyEncodingStrategy: QueryEncoder.KeyEncodingStrategy,
                inputQueryKeyEncodeTransformStrategy: QueryEncoder.KeyEncodeTransformStrategy) {
        self.httpPath = httpPath
        self.inputBodyRootKey = inputBodyRootKey
        self.inputQueryMapEncodingStrategy = inputQueryMapEncodingStrategy
        self.inputQueryListEncodingStrategy = inputQueryListEncodingStrategy
        self.inputQueryKeyEncodingStrategy = inputQueryKeyEncodingStrategy
        self.inputQueryKeyEncodeTransformStrategy = inputQueryKeyEncodeTransformStrategy
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

        guard let queryEncodable = input.queryEncodable else {
            throw SmokeAWSError.invalidRequest("Input must be query encodable.")
        }

        let queryEncoder = QueryEncoder(
            keyEncodingStrategy: self.inputQueryKeyEncodingStrategy,
            mapEncodingStrategy: self.inputQueryMapEncodingStrategy,
            listEncodingStrategy: self.inputQueryListEncodingStrategy,
            keyEncodeTransformStrategy: self.inputQueryKeyEncodeTransformStrategy)

        let encodedQuery = try queryEncoder.encode(queryEncodable,
                                                   allowedCharacterSet: .uriAWSQueryValueAllowed)
        
        let builder = SmokeSdkHttpRequestBuilder()
        builder.withBody(.data(Data(encodedQuery.utf8)))
        builder.withHeaders(additionalHeaders)
        builder.withPath(path)
        
        return builder
    }
}
