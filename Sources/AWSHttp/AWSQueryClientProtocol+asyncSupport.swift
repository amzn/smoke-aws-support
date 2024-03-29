// Copyright 2018-2022 Amazon.com, Inc. or its affiliates. All Rights Reserved.
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
//  AWSQueryClientProtocol+asyncSupport.swift
//  AWSHttp
//

#if (os(Linux) && compiler(>=5.5)) || (!os(Linux) && compiler(>=5.5.2)) && canImport(_Concurrency)

import SmokeHTTPClient
import AWSCore
import NIO

// Copy of extension from SwiftNIO; can be removed when the version in SwiftNIO removes its @available attribute
internal extension EventLoopFuture {
    /// Get the value/error from an `EventLoopFuture` in an `async` context.
    ///
    /// This function can be used to bridge an `EventLoopFuture` into the `async` world. Ie. if you're in an `async`
    /// function and want to get the result of this future.
    @inlinable
    func get() async throws -> Value {
        return try await withCheckedThrowingContinuation { cont in
            self.whenComplete { result in
                switch result {
                case .success(let value):
                    cont.resume(returning: value)
                case .failure(let error):
                    cont.resume(throwing: error)
                }
            }
        }
    }
}

public extension AWSQueryClientProtocol {
    func executeWithoutOutput<InvocationReportingType: HTTPClientInvocationReporting,
                              WrappedInputType: HTTPRequestInputProtocol, ErrorType: ConvertableError>(
            httpClient: HTTPOperationsClient,
            wrappedInput: WrappedInputType,
            action: String,
            reporting: InvocationReportingType,
            errorType: ErrorType.Type) async throws {
        let handlerDelegate = try await AWSClientInvocationDelegate.get(
            credentialsProvider: credentialsProvider,
            awsRegion: awsRegion,
            service: service,
            target: target)
        
        let invocationContext = HTTPClientInvocationContext(reporting: reporting,
                                                            handlerDelegate: handlerDelegate)
        
        let requestInput = QueryWrapperHTTPRequestInput(
            wrappedInput: wrappedInput,
            action: action,
            version: apiVersion)

        do {
            return try await httpClient.executeRetriableWithoutOutput(
                endpointPath: "/",
                httpMethod: .POST,
                clientName: self.clientName,
                operation: action,
                input: requestInput,
                invocationContext: invocationContext,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnErrorProvider)
        } catch {
            try error.unwrapHTTPClientError(type: errorType)
        }
    }
      
    func executeWithOutput<OutputType: HTTPResponseOutputProtocol, InvocationReportingType: HTTPClientInvocationReporting,
                                WrappedInputType: HTTPRequestInputProtocol, ErrorType: ConvertableError>(
            httpClient: HTTPOperationsClient,
            wrappedInput: WrappedInputType,
            action: String,
            reporting: InvocationReportingType,
            errorType: ErrorType.Type) async throws -> OutputType {
        let handlerDelegate = try await AWSClientInvocationDelegate.get(
            credentialsProvider: credentialsProvider,
            awsRegion: awsRegion,
            service: service,
            target: target)
        
        let invocationContext = HTTPClientInvocationContext(reporting: reporting,
                                                            handlerDelegate: handlerDelegate)
        
        let requestInput = QueryWrapperHTTPRequestInput(
            wrappedInput: wrappedInput,
            action: action,
            version: apiVersion)

        do {
            return try await httpClient.executeRetriableWithOutput(
                endpointPath: "/",
                httpMethod: .POST,
                clientName: self.clientName,
                operation: action,
                input: requestInput,
                invocationContext: invocationContext,
                retryConfiguration: retryConfiguration,
                retryOnError: retryOnErrorProvider)
        } catch {
            try error.unwrapHTTPClientError(type: errorType)
        }
    }
}

#endif
