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
//  Error+unwrapSdkError.swift
//  AWSMiddleware
//

import AWSHttp
import ClientRuntime

public extension Swift.Error {
    func unwrapSdkError<ErrorType: ConvertableError>() -> ErrorType {
        if let sdkError = self as? SdkError<ErrorType> {
            switch sdkError {
            case .service(let typedError, _):
                return typedError
            case .client, .unknown:
                break
            }
        }
        
        return ErrorType.asUnrecognizedError(error: self)
    }
}
