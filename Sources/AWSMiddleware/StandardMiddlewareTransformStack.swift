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
//  StandardMiddlewareTransformStack.swift
//  AWSMiddleware
//

import SwiftMiddleware
import SmokeHTTPMiddleware
import ClientRuntime
import QueryCoding
import SmokeHTTPClient
import AWSCore

public struct StandardMiddlewareInitializationContext {
    public let credentialsProvider: CredentialsProvider
    public let awsRegion: AWSRegion
    public let service: String
    public let operation: String?
    public let target: String?
    public let isV4SignRequest: Bool
    public let signAllHeaders: Bool
    public let retryer: SDKRetryer
    public let retryConfiguration: HTTPClientRetryConfiguration
    public let metrics: StandardHTTPClientInvocationMetrics
    public let outwardsRequestAggregatorV2: OutwardsRequestAggregatorV2?
    // legacy aggregator; only the boxed/existential will be available
    public let outwardsRequestAggregator: OutwardsRequestAggregator?

    /// The server hostname to contact for requests from this client.
    public let endpointHostName: String
    /// The server port to connect to.
    public let endpointPort: Int
    /// The content type of the payload being sent.
    public let contentType: String
    public let specifyContentHeadersForZeroLengthBody: Bool
    
    public init(credentialsProvider: CredentialsProvider, awsRegion: AWSRegion, service: String, operation: String? = nil,
                target: String? = nil, isV4SignRequest: Bool = true, specifyContentHeadersForZeroLengthBody: Bool = true,
                signAllHeaders: Bool = false, retryer: SDKRetryer, retryConfiguration: HTTPClientRetryConfiguration,
                metrics: StandardHTTPClientInvocationMetrics = .init(), outwardsRequestAggregatorV2: OutwardsRequestAggregatorV2? = nil,
                outwardsRequestAggregator: OutwardsRequestAggregator? = nil, endpointHostName: String, endpointPort: Int,
                contentType: String) {
        self.credentialsProvider = credentialsProvider
        self.awsRegion = awsRegion
        self.service = service
        self.operation = operation
        self.target = target
        self.isV4SignRequest = isV4SignRequest
        self.signAllHeaders = signAllHeaders
        self.retryer = retryer
        self.retryConfiguration = retryConfiguration
        self.metrics = metrics
        self.outwardsRequestAggregatorV2 = outwardsRequestAggregatorV2
        self.outwardsRequestAggregator = outwardsRequestAggregator
        self.endpointHostName = endpointHostName
        self.endpointPort = endpointPort
        self.contentType = contentType
        self.specifyContentHeadersForZeroLengthBody = specifyContentHeadersForZeroLengthBody
    }
}

public struct StandardMiddlewareTransformStack<ErrorType: Error & Decodable> {
    public let initContext: StandardMiddlewareInitializationContext
    
    public init(initContext: StandardMiddlewareInitializationContext) {
        self.initContext = initContext
    }
    
    public func execute<InnerMiddlewareType: MiddlewareProtocol, OuterMiddlewareType: MiddlewareProtocol,
                RequestTransformType: TransformProtocol, ResponseTransformType: TransformProtocol, Context: SmokeMiddlewareContext>(
        outerMiddleware: OuterMiddlewareType?, innerMiddleware: InnerMiddlewareType?,
        input: OuterMiddlewareType.Input, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine, requestTransform: RequestTransformType, responseTransform: ResponseTransformType) async throws -> OuterMiddlewareType.Output
    where InnerMiddlewareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlewareType.Output == HttpResponse,
    InnerMiddlewareType.Context == Context, OuterMiddlewareType.Context == Context,
    ResponseTransformType.Input == HttpResponse, ResponseTransformType.Output == OuterMiddlewareType.Output,
    RequestTransformType.Input == OuterMiddlewareType.Input, RequestTransformType.Output == SmokeSdkHttpRequestBuilder,
    ResponseTransformType.Context == Context, RequestTransformType.Context == Context {
        let endpointHostName = endpointOverride?.host ?? self.initContext.endpointHostName
        let endpointPort = endpointOverride?.port ?? self.initContext.endpointPort
        
        let stack = MiddlewareTransformStack(requestTransform: requestTransform, responseTransform: responseTransform) {
            if let outerMiddleware = outerMiddleware {
                outerMiddleware
            }
        } inner: {
            if let innerMiddleware = innerMiddleware {
                innerMiddleware
            }
            
            SDKHTTPHostNameMiddleware<Context>(hostName: endpointHostName)
            SDKHTTPPortMiddleware<Context>(port: Int16(endpointPort))
            
            SDKHTTPMethodMiddleware<Context>(methodType: httpMethod)
            V4SignerMiddleware<Context>(credentialsProvider: self.initContext.credentialsProvider, awsRegion: self.initContext.awsRegion,
                                        service: self.initContext.service, operation: self.initContext.operation, target: self.initContext.target,
                                        isV4SignRequest: self.initContext.isV4SignRequest, signAllHeaders: self.initContext.signAllHeaders)
            SDKContentHeadersMiddleware<Context>(specifyContentHeadersForZeroLengthBody: self.initContext.specifyContentHeadersForZeroLengthBody,
                                                 contentType: self.initContext.contentType)
            SDKHeaderMiddleware<Context>.userAgent
            SDKHeaderMiddleware<Context>.accept
            SDKRetryerMiddleware<Context, ErrorType>(retryer: self.initContext.retryer, retryConfiguration: self.initContext.retryConfiguration,
                                                     metrics: self.initContext.metrics,
                                                     outwardsRequestAggregatorV2: self.initContext.outwardsRequestAggregatorV2,
                                                     outwardsRequestAggregator: self.initContext.outwardsRequestAggregator)
            SDKErrorMiddleware<Context, ErrorType>()
        }
        
        let next: ((SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) = engine.getExecuteFunction()
        return try await stack.handle(input, context: context, next: next)
    }
}
