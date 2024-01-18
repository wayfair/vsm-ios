// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VSM",
    platforms: [
        .iOS(.v13),
        .macOS(.v11),
        .macCatalyst(.v13),
        .watchOS(.v6),
        .tvOS(.v13),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "VSM",
            targets: ["VSM"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/albertbori/TestableCombinePublishers.git", from: "1.2.1")
    ],
    targets: [
        .target(
            name: "VSM",
            dependencies: []),
        .testTarget(
            name: "VSMTests",
            dependencies: [
                "VSM",
                "TestableCombinePublishers"
            ]),
    ]
)
