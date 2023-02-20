// swift-tools-version: 5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "smoke-aws-support",
    platforms: [
        .macOS(.v10_15), .iOS(.v13), .tvOS(.v13)
    ],
    products: [
        .library(
            name: "AWSCore",
            targets: ["AWSCore"]),
        .library(
            name: "AWSHttp",
            targets: ["AWSHttp"]),
        .library(
            name: "AWSLogging",
            targets: ["AWSLogging"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-metrics.git", "1.0.0"..<"3.0.0"),
        .package(url: "https://github.com/LiveUI/XMLCoding.git", from: "0.4.1"),
        .package(path: "/Users/simonpi/Packages/smoke-http"),
    ],
    targets: [
        .target(
            name: "AWSCore", dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .product(name: "Metrics", package: "swift-metrics"),
                .product(name: "XMLCoding", package: "XMLCoding"),
                .product(name: "SmokeHTTPClient", package: "smoke-http"),
            ]
        ),
        .target(
            name: "AWSHttp", dependencies: [
                .product(name: "Logging", package: "swift-log"),
                .target(name: "AWSCore"),
                .product(name: "SmokeHTTPClient", package: "smoke-http"),
                .product(name: "QueryCoding", package: "smoke-http"),
                .product(name: "HTTPPathCoding", package: "smoke-http"),
                .product(name: "HTTPHeadersCoding", package: "smoke-http"),
                .product(name: "Crypto", package: "swift-crypto"),
            ]
        ),
        .target(
            name: "AWSLogging", dependencies: [
                .product(name: "Logging", package: "swift-log"),
            ]
        ),
        .testTarget(
            name: "AWSLoggingTests", dependencies: [
                .target(name: "AWSLogging"),
            ]),
    ],
    swiftLanguageVersions: [.v5]
)
