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
//  DataContentTypeMiddlewareTransformStack.swift
//  AWSMiddleware
//

import SwiftMiddleware
import SmokeHTTPMiddleware
import ClientRuntime
import QueryCoding
import SmokeHTTPClient
import AWSCore

public protocol DataContentTypeMiddlewareTransformStackProtocol: ContentTypeMiddlewareTransformStackProtocol {
    init(inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?,
         credentialsProvider: CredentialsProvider, awsRegion: AWSRegion, service: String, operation: String?,
         target: String?, isV4SignRequest: Bool, signAllHeaders: Bool, endpointHostName: String, endpointPort: Int,
         contentType: String, specifyContentHeadersForZeroLengthBody: Bool)
}

public struct DataContentTypeMiddlewareTransformStack<ErrorType: Error & Decodable>: DataContentTypeMiddlewareTransformStackProtocol {
    public let inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?
    public let middlewareStack: StandardMiddlewareTransformStack<ErrorType>
    
    public init(inputQueryMapDecodingStrategy: QueryEncoder.MapEncodingStrategy?,
                credentialsProvider: CredentialsProvider, awsRegion: AWSRegion, service: String, operation: String?,
                target: String?, isV4SignRequest: Bool, signAllHeaders: Bool, endpointHostName: String, endpointPort: Int,
                contentType: String, specifyContentHeadersForZeroLengthBody: Bool) {
        self.inputQueryMapDecodingStrategy = inputQueryMapDecodingStrategy
        self.middlewareStack = StandardMiddlewareTransformStack(
            credentialsProvider: credentialsProvider, awsRegion: awsRegion, service: service,
            operation: operation, target: target, isV4SignRequest: isV4SignRequest, signAllHeaders: signAllHeaders,
            endpointHostName: endpointHostName, endpointPort: endpointPort, contentType: contentType,
            specifyContentHeadersForZeroLengthBody: specifyContentHeadersForZeroLengthBody)
    }
    
    //-- Input and Output
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == TransformedOutput,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context {
        let inwardTransform = DataInwardTransform<OriginalInput, Context>(httpPath: endpointPath,
                                                                          inputQueryMapDecodingStrategy: self.inputQueryMapDecodingStrategy)
        let outwardTransform = DataOutwardTransform<TransformedOutput, Context>()
        
        return try await self.middlewareStack.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input,
                                                 endpointOverride: endpointOverride, endpointPath: endpointPath, httpMethod: httpMethod,
                                                 context: context, engine: engine, inwardTransform: inwardTransform, outwardTransform: outwardTransform)
    }
    
    //-- Input Only
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL? = nil, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context {
        let inwardTransform = DataInwardTransform<OriginalInput, Context>(httpPath: endpointPath,
                                                                          inputQueryMapDecodingStrategy: self.inputQueryMapDecodingStrategy)
        let outwardTransform = VoidOutwardTransform<Context>()
        
        return try await self.middlewareStack.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input,
                                                 endpointOverride: endpointOverride, endpointPath: endpointPath, httpMethod: httpMethod,
                                                 context: context, engine: engine, inwardTransform: inwardTransform, outwardTransform: outwardTransform)
    }
}
