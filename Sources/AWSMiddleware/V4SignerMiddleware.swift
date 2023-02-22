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
//  V4SignerMiddleware.swift
//  AWSMiddleware
//

import SwiftMiddleware
import ClientRuntime
import SmokeHTTPMiddleware
import AWSHttp
import AWSCore
import Logging

enum V4SignerMiddlewareError: Swift.Error {
    case invalidUrl
    case invalidBody
}

public struct V4SignerMiddleware<Context: SmokeMiddlewareContext>: MiddlewareProtocol {
    public typealias Input = SmokeSdkHttpRequestBuilder
    public typealias Output = HttpResponse
    
    let credentialsProvider: CredentialsProvider
    let awsRegion: AWSRegion
    let service: String
    let operation: String?
    let target: String?
    let isV4SignRequest: Bool
    let signAllHeaders: Bool
    
    public init(credentialsProvider: CredentialsProvider, awsRegion: AWSRegion, service: String, operation: String?,
                target: String?, isV4SignRequest: Bool, signAllHeaders: Bool) {
        self.credentialsProvider = credentialsProvider
        self.awsRegion = awsRegion
        self.service = service
        self.operation = operation
        self.target = target
        self.isV4SignRequest = isV4SignRequest
        self.signAllHeaders = signAllHeaders
    }
    
    public func handle(_ input: SmokeSdkHttpRequestBuilder, context: Context,
                       next: (SmokeSdkHttpRequestBuilder, Context) async throws -> HttpResponse) async throws
    -> HttpResponse {
        let headers = try getClientSpecificHeaders(input: input, context: context)
        
        headers.forEach { key, value in
            input.withHeader(name: key, value: value)
        }
        
        return try await next(input, context)
    }
    
    private func getClientSpecificHeaders(input: SmokeSdkHttpRequestBuilder, context: Context) throws -> [(String, String)] {
        let v4Signer = V4Signer(credentials: credentialsProvider.credentials, region: awsRegion,
                                service: service,
                                signAllHeaders: signAllHeaders)
        var headers: [(String, String)]
        let logger = context.logger
        
        let allHeadersToBeSigned: [String: String]
        if signAllHeaders {
            var headers = getHeadersToBeSigned(logger: logger)
            input.headers.headers.forEach { header in
                headers[header.name] = header.value.joined(separator: ",")
            }
            
            allHeadersToBeSigned = headers
        } else {
            allHeadersToBeSigned = getHeadersToBeSigned(logger: logger)
        }
        
        if (isV4SignRequest) {
            guard let url = input.url else {
                throw V4SignerMiddlewareError.invalidUrl
            }
            
            guard case .data(let bodyDataOptional) = input.body, let bodyData = bodyDataOptional else {
                throw V4SignerMiddlewareError.invalidBody
            }
            
            headers = v4Signer.getSignedHeaders(
                url: url,
                headers: allHeadersToBeSigned,
                method: input.methodType.rawValue,
                bodyData: bodyData)
        } else {
            headers = [("Host", input.host)]
        }
        return headers
    }
    
    /// The headers that need to be signed for this request
    private func getHeadersToBeSigned(logger: Logging.Logger) -> [String: String] {
        var headersToBeSigned: [String: String] = [:]
        
        guard let operation = operation else {
            logger.trace("Operation not found for HTTP header for \(service) request, no headers needed for signing.")
            return headersToBeSigned
        }
        
        guard let target = target else {
            logger.trace("Target not found for HTTP header, assigning \(operation) to x-amzn-target header.")
            headersToBeSigned["x-amz-target"] = operation
            return headersToBeSigned
        }

        headersToBeSigned["x-amz-target"] = "\(target).\(operation)"
        
        return headersToBeSigned
    }
}
