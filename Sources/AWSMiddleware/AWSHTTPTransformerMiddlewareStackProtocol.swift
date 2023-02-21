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
//  AWSHTTPTransformerMiddlewareStackProtocol.swift
//  AWSMiddleware
//

 import SwiftMiddleware
 import SmokeHTTPMiddleware
 import ClientRuntime
 import QueryCoding
 import SmokeHTTPClient
 import AWSCore
 
 public protocol AWSHTTPTransformerMiddlewareStackProtocol {
     //-- Input and Output
     func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                  OuterMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
         outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
         input: OriginalInput, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
         engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
     where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == TransformedOutput,
     InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
     InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context
     
     //-- Input Only
     func execute<OriginalInput: HTTPRequestInputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                  OuterMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
         outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
         input: OriginalInput, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
         engine: SmokeHTTPClientEngine) async throws
     where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == Void,
     InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
     InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context
 }

public struct NoOpMiddleware<Input, Output, Context>: MiddlewareProtocol {
    public func handle(_ input: Input, context: Context, next: (Input, Context) async throws -> Output) async throws -> Output {
        return try await next(input, context)
    }
}

public extension AWSHTTPTransformerMiddlewareStackProtocol {
    //-- Input and Output
    
    func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                 OuterMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == TransformedOutput,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context {
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: nil,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                 Context: AWSMiddlewareContext>(
        innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context {
        let outerMiddleware: NoOpMiddleware<OriginalInput, TransformedOutput, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol,
                 OuterMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == TransformedOutput,
    OuterMiddlewareType.Context == Context {
        let innerMiddleware: NoOpMiddleware<SmokeSdkHttpRequestBuilder, HttpResponse, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, Context: AWSMiddlewareContext>(
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput {
        let outerMiddleware: NoOpMiddleware<OriginalInput, TransformedOutput, Context>? = nil
        let innerMiddleware: NoOpMiddleware<SmokeSdkHttpRequestBuilder, HttpResponse, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    //-- Input Only
    
    func execute<OriginalInput: HTTPRequestInputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                 OuterMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context {
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: nil,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    func execute<OriginalInput: HTTPRequestInputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                 Context: AWSMiddlewareContext>(
        innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws
    where InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context {
        let outerMiddleware: NoOpMiddleware<OriginalInput, Void, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    func execute<OriginalInput: HTTPRequestInputProtocol,
                 OuterMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == Void,
    OuterMiddlewareType.Context == Context {
        let innerMiddleware: NoOpMiddleware<SmokeSdkHttpRequestBuilder, HttpResponse, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
    
    func execute<OriginalInput: HTTPRequestInputProtocol, Context: AWSMiddlewareContext>(
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws {
        let outerMiddleware: NoOpMiddleware<OriginalInput, Void, Context>? = nil
        let innerMiddleware: NoOpMiddleware<SmokeSdkHttpRequestBuilder, HttpResponse, Context>? = nil
        
        return try await self.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input, endpointOverride: endpointOverride,
                                      endpointPath: endpointPath, httpMethod: httpMethod, context: context, engine: engine)
    }
}
 
