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
//  XMLErrorResponseTransform.swift
//  AWSMiddleware
//

import SwiftMiddleware
import ClientRuntime
import SmokeHTTPMiddleware
import AWSHttp

public struct XMLErrorResponseTransform<ErrorType: Error & Decodable, Context: SmokeMiddlewareContext>: TransformProtocol {
    public typealias Input = HttpResponse
    public typealias Output = ErrorType
    
    private let errorTypeHTTPHeader: String?
    
    public init(errorTypeHTTPHeader: String?) {
        self.errorTypeHTTPHeader = errorTypeHTTPHeader
    }
    
    public func transform(_ response: HttpResponse, context: Context) async throws -> ErrorType {
        let responseBodyOptional: Data?
        switch response.body {
        case .data(let data):
            responseBodyOptional = data
        case .stream(let reader):
            responseBodyOptional = reader.toBytes().getData()
        case .none:
            responseBodyOptional = nil
        }
        
        guard let bodyData = responseBodyOptional else {
            throw SdkError<ErrorType>.client(.deserializationFailed(DeserializationError.noBody), response)
        }
        
        var cause: ErrorType
        if let errorTypeHTTPHeader = self.errorTypeHTTPHeader,
           let errorType = response.headers.value(for: errorTypeHTTPHeader) {
            cause = try getErrorFromResponseAndBody(errorTypeHTTPHeaderValue: errorType,
                                                    bodyData: bodyData, response: response,
                                                    logger: context.logger)
        } else {
            // Convert bodyData to a debug string only if debug logging is enabled
            context.logger.trace("Attempting to decode error data from XML to \(ErrorType.self)",
                                 metadata: ["body": "\(bodyData.debugString)"])
            
            // attempt to get an error of Error type by decoding the body data
            guard let theCause = try ErrorWrapper<ErrorType>.firstErrorFromBodyData(errorType: ErrorType.self, bodyData: bodyData) else {
                throw SdkError<ErrorType>.client(.deserializationFailed(DeserializationError.noErrors), response)
            }
            cause = theCause
        }
        
        return cause
    }
}
