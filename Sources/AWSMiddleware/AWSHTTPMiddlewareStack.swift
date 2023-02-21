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
//  AWSHTTPMiddlewareStack.swift
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
    
    /// Input and Output
    func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                 OuterMiddlewareType: MiddlewareProtocol, InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol,
                 Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == TransformedOutput,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == TransformedOutput,
    InwardTransformerType.Input == OriginalInput, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context
    
    /// Input only
    func execute<OriginalInput: HTTPRequestInputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                 OuterMiddlewareType: MiddlewareProtocol, InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol,
                 Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == Void,
    InwardTransformerType.Input == OriginalInput, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context
    
    /// Output only
    func execute<TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                 OuterMiddlewareType: MiddlewareProtocol, InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol,
                 Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == Void, OuterMiddlewareType.Output == TransformedOutput,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == TransformedOutput,
    InwardTransformerType.Input == Void, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context
    
    /// No input or ouput
    func execute<InnerMiddlewareType: MiddlewareProtocol,
                 OuterMiddlewareType: MiddlewareProtocol, InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol,
                 Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws
    where OuterMiddlewareType.Input == Void, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == Void,
    InwardTransformerType.Input == Void, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context
}

public struct AWSHTTPMiddlewareStack<ErrorType: Error & Decodable>: AWSHTTPMiddlewareStackProtocol {
    public let credentialsProvider: CredentialsProvider
    public let awsRegion: AWSRegion
    public let service: String
    public let operation: String?
    public let target: String?
    public let isV4SignRequest: Bool
    public let signAllHeaders: Bool

    /// The server hostname to contact for requests from this client.
    public let endpointHostName: String
    /// The server port to connect to.
    public let endpointPort: Int
    /// The content type of the payload being sent.
    public let contentType: String
    public let specifyContentHeadersForZeroLengthBody: Bool
    
    public init(credentialsProvider: CredentialsProvider, awsRegion: AWSRegion, service: String, operation: String?,
                target: String?, isV4SignRequest: Bool, signAllHeaders: Bool, endpointHostName: String, endpointPort: Int,
                contentType: String, specifyContentHeadersForZeroLengthBody: Bool) {
        self.credentialsProvider = credentialsProvider
        self.awsRegion = awsRegion
        self.service = service
        self.operation = operation
        self.target = target
        self.isV4SignRequest = isV4SignRequest
        self.signAllHeaders = signAllHeaders
        self.endpointHostName = endpointHostName
        self.endpointPort = endpointPort
        self.contentType = contentType
        self.specifyContentHeadersForZeroLengthBody = specifyContentHeadersForZeroLengthBody
    }
    
    /// Input and Output
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol,
                        Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == TransformedOutput,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == TransformedOutput,
    InwardTransformerType.Input == OriginalInput, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context {
        let endpointHostName = endpointOverride?.host ?? self.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.endpointPort
        
        let innerMiddleware = getInnerMiddleware(innerMiddleware: innerMiddleware, endpointOverride: endpointOverride,
                                                 endpointHostName: endpointHostName, endpointPort: endpointPort, endpointPath: endpointPath,
                                                 httpMethod: httpMethod, context: context)
        
        let stack = MiddlewareTransformStack(inwardTransform: inwardTransform, outwardTransform: outwardTransform) {
            if let outerMiddleware = outerMiddleware {
                outerMiddleware
            }
        } inner: { innerMiddleware }
        
        let next: ((SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) = engine.getExecuteFunction()
        return try await stack.handle(input, context: context, next: next)
    }
    
    /// Input only
    public func execute<OriginalInput: HTTPRequestInputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol,
                        Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OriginalInput, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws
    where OuterMiddlewareType.Input == OriginalInput, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == Void,
    InwardTransformerType.Input == OriginalInput, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context {
        let endpointHostName = endpointOverride?.host ?? self.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.endpointPort
        
        let innerMiddleware = getInnerMiddleware(innerMiddleware: innerMiddleware, endpointOverride: endpointOverride,
                                                 endpointHostName: endpointHostName, endpointPort: endpointPort, endpointPath: endpointPath,
                                                 httpMethod: httpMethod, context: context)
        
        let stack = MiddlewareTransformStack(inwardTransform: inwardTransform, outwardTransform: outwardTransform) {
            if let outerMiddleware = outerMiddleware {
                outerMiddleware
            }
        } inner: { innerMiddleware }
        
        let next: ((SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) = engine.getExecuteFunction()
        return try await stack.handle(input, context: context, next: next)
    }
    
    /// Output only
    public func execute<TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol,
                        Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws -> TransformedOutput
    where OuterMiddlewareType.Input == Void, OuterMiddlewareType.Output == TransformedOutput,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == TransformedOutput,
    InwardTransformerType.Input == Void, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context {
        let endpointHostName = endpointOverride?.host ?? self.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.endpointPort
        
        let innerMiddleware = getInnerMiddleware(innerMiddleware: innerMiddleware, endpointOverride: endpointOverride,
                                                 endpointHostName: endpointHostName, endpointPort: endpointPort, endpointPath: endpointPath,
                                                 httpMethod: httpMethod, context: context)
        
        let stack = MiddlewareTransformStack(inwardTransform: inwardTransform, outwardTransform: outwardTransform) {
            if let outerMiddleware = outerMiddleware {
                outerMiddleware
            }
        } inner: { innerMiddleware }
        
        let next: ((SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) = engine.getExecuteFunction()
        return try await stack.handle((), context: context, next: next)
    }
    
    /// No input or ouput
    public func execute<InnerMiddlewareType: MiddlewareProtocol,
                        OuterMiddlewareType: MiddlewareProtocol, InwardTransformerType: TransformProtocol, OutwardTransformerType: TransformProtocol,
                        Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, inwardTransform: InwardTransformerType, outwardTransform: OutwardTransformerType) async throws
    where OuterMiddlewareType.Input == Void, OuterMiddlewareType.Output == Void,
    InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    OutwardTransformerType.Input == HttpResponse, OutwardTransformerType.Output == Void,
    InwardTransformerType.Input == Void, InwardTransformerType.Output == SmokeSdkHttpRequestBuilder,
    OutwardTransformerType.Context == Context, InwardTransformerType.Context == Context {
        let endpointHostName = endpointOverride?.host ?? self.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.endpointPort
        
        let innerMiddleware = getInnerMiddleware(innerMiddleware: innerMiddleware, endpointOverride: endpointOverride,
                                                 endpointHostName: endpointHostName, endpointPort: endpointPort, endpointPath: endpointPath,
                                                 httpMethod: httpMethod, context: context)
        
        let stack = MiddlewareTransformStack(inwardTransform: inwardTransform, outwardTransform: outwardTransform) {
            if let outerMiddleware = outerMiddleware {
                outerMiddleware
            }
        } inner: { innerMiddleware }
        
        let next: ((SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) = engine.getExecuteFunction()
        return try await stack.handle((), context: context, next: next)
    }
    
    @MiddlewareBuilder
    private func getInnerMiddleware<InnerMiddlewareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        innerMiddleware: InnerMiddlewareType?, endpointOverride: URL?, endpointHostName: String,
        endpointPort: Int, endpointPath: String, httpMethod: HttpMethodType, context: Context)
    -> some MiddlewareProtocol<SmokeSdkHttpRequestBuilder, HttpResponse, Context>
    where InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context {
        if let innerMiddleware = innerMiddleware {
            innerMiddleware
        }
        
        SDKHTTPHostNameMiddleware<Context>(hostName: endpointHostName)
        SDKHTTPPortMiddleware<Context>(port: Int16(endpointPort))
        
        V4SignerMiddleware<Context>(credentialsProvider: self.credentialsProvider, awsRegion: self.awsRegion,
                                    service: self.service, operation: self.operation, target: self.target,
                                    isV4SignRequest: self.isV4SignRequest, signAllHeaders: self.signAllHeaders)
        SDKContentHeadersMiddleware<Context>(specifyContentHeadersForZeroLengthBody: self.specifyContentHeadersForZeroLengthBody, contentType: self.contentType)
        SDKHeaderMiddleware<Context>.userAgent
        SDKHeaderMiddleware<Context>.accept
    }
}
