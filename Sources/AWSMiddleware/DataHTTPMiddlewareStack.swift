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
//  DataHTTPMiddlewareStack.swift
//  AWSMiddleware
//

import SwiftMiddleware
import SmokeHTTPMiddleware
import ClientRuntime
import QueryCoding
import SmokeHTTPClient
import AWSCore

public struct DataHTTPMiddlewareStack<InnerStackType: AWSHTTPMiddlewareStackProtocol> {
    public let inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?
    public let innerStack: InnerStackType
    
    public init(inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?, innerStack: InnerStackType) {
        self.inputQueryMapDecodingStrategy = inputQueryMapDecodingStrategy
        self.innerStack = innerStack
    }
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlwareType: MiddlewareProtocol,
                        OuterMiddlwareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlwareType?, innerMiddleware: InnerMiddlwareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where OuterMiddlwareType.Input == OriginalInput, OuterMiddlwareType.Output == TransformedOutput,
    InnerMiddlwareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlwareType.Output == HttpResponse,
    InnerMiddlwareType.Context == Context, OuterMiddlwareType.Context == Context {
        let inwardTransform = DataInwardTransformer<OriginalInput, Context>(httpPath: endpointPath,
                                                                            inputQueryMapDecodingStrategy: self.inputQueryMapDecodingStrategy)
        let outwardTransform = DataOutwardTransformer<TransformedOutput, Context>()
        
        return try await self.innerStack.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input,
                                                 endpointOverride: endpointOverride, endpointPath: endpointPath, httpMethod: httpMethod,
                                                 context: context, engine: engine, inwardTransform: inwardTransform, outwardTransform: outwardTransform)
    }
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlwareType: MiddlewareProtocol,
                        Context: AWSMiddlewareContext>(
        innerMiddleware: InnerMiddlwareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where InnerMiddlwareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlwareType.Output == HttpResponse,
    InnerMiddlwareType.Context == Context {
        let outerMiddleware: NoOpMiddleware<OriginalInput, TransformedOutput, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol,
                        OuterMiddlwareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlwareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where OuterMiddlwareType.Input == OriginalInput, OuterMiddlwareType.Output == TransformedOutput,
    OuterMiddlwareType.Context == Context {
        let innerMiddleware: NoOpMiddleware<SmokeSdkHttpRequestBuilder, HttpResponse, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, Context: AWSMiddlewareContext>(
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput {
        let outerMiddleware: NoOpMiddleware<OriginalInput, TransformedOutput, Context>? = nil
        let innerMiddleware: NoOpMiddleware<SmokeSdkHttpRequestBuilder, HttpResponse, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
}
