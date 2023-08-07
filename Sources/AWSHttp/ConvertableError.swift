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
//  ConvertableError.swift
//  AWSHttp
//

import SmokeHTTPClient

public protocol ConvertableError: Error {
    static func asUnrecognizedError(error: Swift.Error) -> Self
}

public extension SmokeHTTPClient.HTTPClientError {
    func asTypedError<ErrorType: ConvertableError>() -> ErrorType {
        if let typedError = cause as? ErrorType {
            return typedError
        } else {
            return ErrorType.asUnrecognizedError(error: cause)
        }
    }
    
    func asTypedErrorThrowingHTTPErrors<ErrorType: ConvertableError>() throws -> ErrorType {
        if let typedError = cause as? ErrorType {
            return typedError
        } else if let httpError = cause as? HTTPError {
            // throw the http error unwrapped
            throw httpError
        } else {
            return ErrorType.asUnrecognizedError(error: cause)
        }
    }
}

public extension Swift.Error {
    func asTypedError<ErrorType: ConvertableError>() -> ErrorType {
        if let typedError = self as? SmokeHTTPClient.HTTPClientError {
            return typedError.asTypedError()
        } else {
            return ErrorType.asUnrecognizedError(error: self)
        }
    }
    
    func asTypedErrorThrowingHTTPErrors<ErrorType: ConvertableError>() throws -> ErrorType {
        if let typedError = self as? SmokeHTTPClient.HTTPClientError {
            return try typedError.asTypedErrorThrowingHTTPErrors()
        } else {
            return ErrorType.asUnrecognizedError(error: self)
        }
    }
}
