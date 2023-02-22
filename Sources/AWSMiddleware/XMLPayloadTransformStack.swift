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
//  XMLPayloadTransformStack.swift
//  AWSMiddleware
//

import SwiftMiddleware
import SmokeHTTPMiddleware
import ClientRuntime
import QueryCoding
import SmokeHTTPClient
import AWSCore
import XMLCoding

public protocol XMLPayloadTransformStackProtocol: PayloadTransformStackProtocol {
    init(inputBodyRootKey: String?, outputListDecodingStrategy: XMLCoding.XMLDecoder.ListDecodingStrategy?,
         outputMapDecodingStrategy: XMLCoding.XMLDecoder.MapDecodingStrategy?,
         inputQueryMapEncodingStrategy: QueryEncoder.MapEncodingStrategy,
         inputQueryListEncodingStrategy: QueryEncoder.ListEncodingStrategy,
         inputQueryKeyEncodingStrategy: QueryEncoder.KeyEncodingStrategy,
         inputQueryKeyEncodeTransformStrategy: QueryEncoder.KeyEncodeTransformStrategy,
         initContext: StandardMiddlewareInitializationContext)
}

public struct XMLPayloadTransformStack<ErrorType: Error & Decodable>: XMLPayloadTransformStackProtocol {
    public let inputBodyRootKey: String?
    public let outputListDecodingStrategy: XMLCoding.XMLDecoder.ListDecodingStrategy?
    public let outputMapDecodingStrategy: XMLCoding.XMLDecoder.MapDecodingStrategy?
    public let inputQueryMapEncodingStrategy: QueryEncoder.MapEncodingStrategy
    public let inputQueryListEncodingStrategy: QueryEncoder.ListEncodingStrategy
    public let inputQueryKeyEncodingStrategy: QueryEncoder.KeyEncodingStrategy
    public let inputQueryKeyEncodeTransformStrategy: QueryEncoder.KeyEncodeTransformStrategy
    public let middlewareStack: StandardMiddlewareTransformStack<ErrorType>
    
    public init(inputBodyRootKey: String?, outputListDecodingStrategy: XMLCoding.XMLDecoder.ListDecodingStrategy?,
                outputMapDecodingStrategy: XMLCoding.XMLDecoder.MapDecodingStrategy?,
                inputQueryMapEncodingStrategy: QueryEncoder.MapEncodingStrategy,
                inputQueryListEncodingStrategy: QueryEncoder.ListEncodingStrategy,
                inputQueryKeyEncodingStrategy: QueryEncoder.KeyEncodingStrategy,
                inputQueryKeyEncodeTransformStrategy: QueryEncoder.KeyEncodeTransformStrategy,
                initContext: StandardMiddlewareInitializationContext) {
        self.inputBodyRootKey = inputBodyRootKey
        self.outputListDecodingStrategy = outputListDecodingStrategy
        self.outputMapDecodingStrategy = outputMapDecodingStrategy
        self.inputQueryMapEncodingStrategy = inputQueryMapEncodingStrategy
        self.inputQueryListEncodingStrategy = inputQueryListEncodingStrategy
        self.inputQueryKeyEncodingStrategy = inputQueryKeyEncodingStrategy
        self.inputQueryKeyEncodeTransformStrategy = inputQueryKeyEncodeTransformStrategy
        self.middlewareStack = StandardMiddlewareTransformStack(initContext: initContext)
    }
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, Context: SmokeMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == TransformedOutput,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context {
        let requestTransform = XMLRequestTransform<OriginalInput, Context>(httpPath: endpointPath, inputBodyRootKey: self.inputBodyRootKey,
                                                                           inputQueryMapEncodingStrategy: self.inputQueryMapEncodingStrategy,
                                                                           inputQueryListEncodingStrategy: self.inputQueryListEncodingStrategy,
                                                                           inputQueryKeyEncodingStrategy: self.inputQueryKeyEncodingStrategy,
                                                                           inputQueryKeyEncodeTransformStrategy: self.inputQueryKeyEncodeTransformStrategy)
        let responseTransform = XMLResponseTransform<TransformedOutput, Context>(outputListDecodingStrategy: self.outputListDecodingStrategy,
                                                                                 outputMapDecodingStrategy: self.outputMapDecodingStrategy)
        
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
        let requestTransform = XMLRequestTransform<OriginalInput, Context>(httpPath: endpointPath, inputBodyRootKey: self.inputBodyRootKey,
                                                                           inputQueryMapEncodingStrategy: self.inputQueryMapEncodingStrategy,
                                                                           inputQueryListEncodingStrategy: self.inputQueryListEncodingStrategy,
                                                                           inputQueryKeyEncodingStrategy: self.inputQueryKeyEncodingStrategy,
                                                                           inputQueryKeyEncodeTransformStrategy: self.inputQueryKeyEncodeTransformStrategy)
        let responseTransform = VoidResponseTransform<Context>()
        
        return try await self.middlewareStack.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input,
                                                      endpointOverride: endpointOverride, endpointPath: endpointPath, httpMethod: httpMethod,
                                                      context: context, engine: engine, requestTransform: requestTransform, responseTransform: responseTransform)
    }
}
