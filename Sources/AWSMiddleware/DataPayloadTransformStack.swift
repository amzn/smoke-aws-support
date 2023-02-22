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
//  DataPayloadTransformStack.swift
//  AWSMiddleware
//

import SwiftMiddleware
import SmokeHTTPMiddleware
import ClientRuntime
import QueryCoding
import SmokeHTTPClient
import AWSCore

public protocol DataPayloadTransformStackProtocol: PayloadTransformStackProtocol {
    init(inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?,
         initContext: StandardMiddlewareInitializationContext)
}

public struct DataPayloadTransformStack<ErrorType: Error & Decodable>: DataPayloadTransformStackProtocol {
    public let inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?
    public let middlewareStack: StandardMiddlewareTransformStack<ErrorType>
    
    public init(inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?,
                initContext: StandardMiddlewareInitializationContext) {
        self.inputQueryMapDecodingStrategy = inputQueryMapDecodingStrategy
        self.middlewareStack = StandardMiddlewareTransformStack(initContext: initContext)
    }
    
    //-- Input and Output
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, Context: SmokeMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == TransformedOutput,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context {
        let requestTransform = DataRequestTransform<OriginalInput, Context>(httpPath: endpointPath,
                                                                            inputQueryMapDecodingStrategy: self.inputQueryMapDecodingStrategy)
        let responseTransform = DataResponseTransform<TransformedOutput, Context>()
        
        return try await self.middlewareStack.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input,
                                                      endpointOverride: endpointOverride, endpointPath: endpointPath, httpMethod: httpMethod,
                                                      context: context, engine: engine, requestTransform: requestTransform, responseTransform: responseTransform)
    }
    
    //-- Input Only
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, Context: SmokeMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context {
        let requestTransform = DataRequestTransform<OriginalInput, Context>(httpPath: endpointPath,
                                                                            inputQueryMapDecodingStrategy: self.inputQueryMapDecodingStrategy)
        let responseTransform = VoidResponseTransform<Context>()
        
        return try await self.middlewareStack.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input,
                                                      endpointOverride: endpointOverride, endpointPath: endpointPath, httpMethod: httpMethod,
                                                      context: context, engine: engine, requestTransform: requestTransform, responseTransform: responseTransform)
    }
}
