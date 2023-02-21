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
//  AWSHTTPMiddlewareStackProtocol.swift
//  AWSMiddleware
//

import SwiftMiddleware
import SmokeHTTPMiddleware
import ClientRuntime
import QueryCoding
import SmokeHTTPClient
import AWSCore

public protocol AWSHTTPMiddlewareStackProtocol {
    associatedtype ErrorType: Error & Decodable
    
    init(credentialsProvider: CredentialsProvider, awsRegion: AWSRegion, service: String, operation: String?,
                target: String?, isV4SignRequest: Bool, signAllHeaders: Bool, endpointHostName: String, endpointPort: Int,
                contentType: String, specifyContentHeadersForZeroLengthBody: Bool)
    
    func execute<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OuterMiddlewareType.Input, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws -> OuterMiddlewareType.Output
    where InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == OuterMiddlewareType.Output,
    InwardTransformerType.Input == OuterMiddlewareType.Input, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context
}
