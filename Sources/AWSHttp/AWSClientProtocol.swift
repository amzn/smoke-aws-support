//
//  AWSClientProtocol.swift
//

import SmokeHTTPClient
import AWSCore

public protocol AWSClientProtocol {
    var awsRegion: AWSRegion { get }
    var service: String { get }
    var target: String? { get }
    var retryConfiguration: HTTPClientRetryConfiguration { get }
    var retryOnErrorProvider: (SmokeHTTPClient.HTTPClientError) -> Bool { get }
    var credentialsProvider: CredentialsProvider { get }
}
