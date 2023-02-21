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
//  FormEncodedHTTPMiddlewareStack.swift
//  AWSMiddleware
//

import SwiftMiddleware
import SmokeHTTPMiddleware
import ClientRuntime
import QueryCoding
import SmokeHTTPClient
import AWSCore
import XMLCoding

public struct FormEncodedHTTPMiddlewareStack<InnerStackType: AWSHTTPMiddlewareStackProtocol> {
    public let inputBodyRootKey: String?
    public let outputListDecodingStrategy: XMLCoding.XMLDecoder.ListDecodingStrategy?
    public let outputMapDecodingStrategy: XMLCoding.XMLDecoder.MapDecodingStrategy?
    public let inputQueryMapEncodingStrategy: QueryEncoder.MapEncodingStrategy
    public let inputQueryListEncodingStrategy: QueryEncoder.ListEncodingStrategy
    public let inputQueryKeyEncodingStrategy: QueryEncoder.KeyEncodingStrategy
    public let inputQueryKeyEncodeTransformStrategy: QueryEncoder.KeyEncodeTransformStrategy
    public let specifyContentHeadersForZeroLengthBody: Bool
    public let innerStack: InnerStackType
    
    public init(inputBodyRootKey: String?, outputListDecodingStrategy: XMLCoding.XMLDecoder.ListDecodingStrategy?,
                outputMapDecodingStrategy: XMLCoding.XMLDecoder.MapDecodingStrategy?,
                inputQueryMapEncodingStrategy: QueryEncoder.MapEncodingStrategy,
                inputQueryListEncodingStrategy: QueryEncoder.ListEncodingStrategy,
                inputQueryKeyEncodingStrategy: QueryEncoder.KeyEncodingStrategy,
                inputQueryKeyEncodeTransformStrategy: QueryEncoder.KeyEncodeTransformStrategy,
                specifyContentHeadersForZeroLengthBody: Bool, innerStack: InnerStackType) {
        self.inputBodyRootKey = inputBodyRootKey
        self.outputListDecodingStrategy = outputListDecodingStrategy
        self.outputMapDecodingStrategy = outputMapDecodingStrategy
        self.inputQueryMapEncodingStrategy = inputQueryMapEncodingStrategy
        self.inputQueryListEncodingStrategy = inputQueryListEncodingStrategy
        self.inputQueryKeyEncodingStrategy = inputQueryKeyEncodingStrategy
        self.inputQueryKeyEncodeTransformStrategy = inputQueryKeyEncodeTransformStrategy
        self.specifyContentHeadersForZeroLengthBody = specifyContentHeadersForZeroLengthBody
        self.innerStack = innerStack
    }
    
    public func execute<OriginalInput: HTTPRequestInputProtocol, TransformedOutput: HTTPResponseOutputProtocol, InnerMiddlwareType: MiddlewareProtocol,
                        OuterMiddlwareType: MiddlewareProtocol, Context: AWSMiddlewareContext>(
        outerMiddleware: OuterMiddlwareType?, innerMiddleware: InnerMiddlwareType?,
        input: OriginalInput, endpointOverride: URL?, endpointPath: String, httpMethod: HttpMethodType, context: Context,
        engine: SmokeHTTPClientEngine) async throws -> TransformedOutput
    where OuterMiddlwareType.Input == OriginalInput, OuterMiddlwareType.Output == TransformedOutput,
          InnerMiddlwareType.Input == SmokeSdkHttpRequestBuilder, InnerMiddlwareType.Output == HttpResponse,
    InnerMiddlwareType.Context == Context, OuterMiddlwareType.Context == Context {
        let inwardTransform = FormEncodedInwardTransformer<OriginalInput, Context>(httpPath: endpointPath, inputBodyRootKey: self.inputBodyRootKey,
                                                                                   inputQueryMapEncodingStrategy: self.inputQueryMapEncodingStrategy,
                                                                                   inputQueryListEncodingStrategy: self.inputQueryListEncodingStrategy,
                                                                                   inputQueryKeyEncodingStrategy: self.inputQueryKeyEncodingStrategy,
                                                                                   inputQueryKeyEncodeTransformStrategy: self.inputQueryKeyEncodeTransformStrategy)
        let outwardTransform = XMLOutwardTransformer<TransformedOutput, Context>(outputListDecodingStrategy: self.outputListDecodingStrategy,
                                                                                 outputMapDecodingStrategy: self.outputMapDecodingStrategy)
        
        return try await self.innerStack.execute(outerMiddleware: outerMiddleware, innerMiddleware: innerMiddleware, input: input,
                                                 endpointOverride: endpointOverride, endpointPath: endpointPath, httpMethod: httpMethod,
                                                 context: context, engine: engine, inwardTransform: inwardTransform, outwardTransform: outwardTransform)
    }
}
