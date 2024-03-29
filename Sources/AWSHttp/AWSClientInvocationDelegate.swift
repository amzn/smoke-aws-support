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
//  AWSClientInvocationDelegate.swift
//  AWSHttp
//

import Foundation
import Logging
import NIOHTTP1
import AsyncHTTPClient
import AWSCore
import SmokeHTTPClient

public struct AWSClientInvocationDelegate : HTTPClientInvocationDelegate {
    public var specifyContentHeadersForZeroLengthBody: Bool
    
    private enum CredentialsType {
        case `static`(Credentials)
        case provider(CredentialsProvider)
        
        func getCredentials() -> Credentials {
            switch self {
            case .static(let credentials):
                return credentials
            case .provider(let provider):
                return provider.credentials
            }
        }
    }
    
    private let credentialsType: CredentialsType
    let awsRegion: AWSRegion
    let service: String
    let operation: String?
    let target: String?
    let isV4SignRequest: Bool
    let signAllHeaders: Bool
    
    /**
     Convenience factory function that constructs an `AWSClientInvocationDelegate` instance according to the
     `credentialsProvider` provided. If the `credentialsProvider` conforms to the `CredentialsProviderV2`
     protocol credentials will be retrieved using that protocol - potentially suspending while refreshed credentials are retrieved.
     Otherwise credentials will be retrieved using the `CredentialsProvider` protocol which has the potential to use
     expired credentials in some circumstances.
     */
    public static func get(credentialsProvider: CredentialsProvider,
                           awsRegion: AWSRegion,
                           service: String,
                           operation: String? = nil,
                           target: String? = nil,
                           isV4SignRequest: Bool = true,
                           specifyContentHeadersForZeroLengthBody: Bool = true,
                           signAllHeaders: Bool = false) async throws -> AWSClientInvocationDelegate {
        let handlerDelegate: AWSClientInvocationDelegate
        if let credentialsProviderV2 = credentialsProvider as? CredentialsProviderV2 {
            let credentials = try await credentialsProviderV2.getCredentials()
            
            handlerDelegate = AWSClientInvocationDelegate(
                credentials: credentials,
                awsRegion: awsRegion,
                service: service,
                operation: operation,
                target: target,
                isV4SignRequest: isV4SignRequest,
                specifyContentHeadersForZeroLengthBody: specifyContentHeadersForZeroLengthBody,
                signAllHeaders: signAllHeaders)
        } else {
            handlerDelegate = AWSClientInvocationDelegate(
                credentialsProvider: credentialsProvider,
                awsRegion: awsRegion,
                service: service,
                operation: operation,
                target: target,
                isV4SignRequest: isV4SignRequest,
                specifyContentHeadersForZeroLengthBody: specifyContentHeadersForZeroLengthBody,
                signAllHeaders: signAllHeaders)
        }
        
        return handlerDelegate
    }
    
    public init (credentials: Credentials,
                 awsRegion: AWSRegion,
                 service: String,
                 operation: String? = nil,
                 target: String? = nil,
                 isV4SignRequest: Bool = true,
                 specifyContentHeadersForZeroLengthBody: Bool = true,
                 signAllHeaders: Bool = false) {
        self.credentialsType = .static(credentials)
        self.awsRegion = awsRegion
        self.service = service
        self.operation = operation
        self.target = target
        self.isV4SignRequest = isV4SignRequest
        self.specifyContentHeadersForZeroLengthBody = specifyContentHeadersForZeroLengthBody
        self.signAllHeaders = signAllHeaders
    }
    
    public init (credentialsProvider: CredentialsProvider,
                 awsRegion: AWSRegion,
                 service: String,
                 operation: String? = nil,
                 target: String? = nil,
                 isV4SignRequest: Bool = true,
                 specifyContentHeadersForZeroLengthBody: Bool = true,
                 signAllHeaders: Bool = false) {
        self.credentialsType = .provider(credentialsProvider)
        self.awsRegion = awsRegion
        self.service = service
        self.operation = operation
        self.target = target
        self.isV4SignRequest = isV4SignRequest
        self.specifyContentHeadersForZeroLengthBody = specifyContentHeadersForZeroLengthBody
        self.signAllHeaders = signAllHeaders
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
    
    public func addClientSpecificHeaders<InvocationReportingType>(
            parameters: HTTPRequestParameters,
            invocationReporting: InvocationReportingType) -> [(String, String)] where InvocationReportingType : HTTPClientInvocationReporting {
        let v4Signer = V4Signer(credentials: self.credentialsType.getCredentials(), region: awsRegion,
                                service: service,
                                signAllHeaders: signAllHeaders)
        var headers: [(String, String)]
        let logger = invocationReporting.logger
        
        let allHeadersToBeSigned: [String: String]
        if signAllHeaders {
            var headers = getHeadersToBeSigned(logger: logger)
            parameters.additionalHeaders.forEach { header in
                headers[header.0] = header.1
            }
            
            allHeadersToBeSigned = headers
        } else {
            allHeadersToBeSigned = getHeadersToBeSigned(logger: logger)
        }
        
        if (isV4SignRequest) {
            headers = v4Signer.getSignedHeaders(
                url: parameters.endpointUrl,
                headers: allHeadersToBeSigned,
                method: parameters.httpMethod.rawValue,
                bodyData: parameters.bodyData)
        } else {
            headers = [("Host", parameters.endpointUrl.host!)]
        }
        return headers
    }
    
    public func handleErrorResponses<InvocationReportingType>(response: HTTPClient.Response, responseBodyData: Data?,
                                                              invocationReporting: InvocationReportingType) -> SmokeHTTPClient.HTTPClientError?
        where InvocationReportingType : HTTPClientInvocationReporting {
        // Place the permanently moved location into the HTTPError
        if case .movedPermanently = response.status {
            let locationHeader = response.headers["Location"]
            let location = locationHeader.count > 0 ? locationHeader[0] : "<unknown>"
            let cause = HTTPError.movedPermanently(location: location)
            return HTTPClientError(responseCode: 301, cause: cause)
        }
        
        // All other errors handled by default behavior
        return nil
    }
}
