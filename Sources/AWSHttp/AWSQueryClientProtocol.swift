//
//  AWSClientProtocol.swift
//

import SmokeHTTPClient
import AWSCore

public protocol AWSQueryClientProtocol {
    var awsRegion: AWSRegion { get }
    var service: String { get }
    var apiVersion: String { get }
    var target: String? { get }
    var retryConfiguration: HTTPClientRetryConfiguration { get }
    var retryOnErrorProvider: (SmokeHTTPClient.HTTPClientError) -> Bool { get }
    var credentialsProvider: CredentialsProvider { get }
}
