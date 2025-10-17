// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "VSM",
    platforms: [
        .iOS(.v17),
        .macOS(.v14),
        .macCatalyst(.v17),
        .watchOS(.v10),
        .tvOS(.v17),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "AsyncVSM",
            targets: ["AsyncVSM"]
        ),
        
        .library(
            name: "VSM",
            targets: ["VSM"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.0.0"),
        .package(url: "https://github.com/albertbori/TestableCombinePublishers.git", from: "2.0.1")
    ],
    targets: [
        .target(
            name: "AsyncVSM",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "AsyncVSMTests",
            dependencies: ["AsyncVSM"],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        
        // Legacy VSM
        .target(
            name: "VSM",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "VSMTests",
            dependencies: [
                "VSM",
                "TestableCombinePublishers"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
    ]
)
