// swift-tools-version: 6.2
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
            name: "LegacyVSM",
            targets: ["LegacyVSM"]
        ),
        .library(
            name: "VSM",
            targets: ["VSM"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.4.6"),
        .package(url: "https://github.com/albertbori/TestableCombinePublishers.git", from: "2.0.1")
    ],
    targets: [
        .target(
            name: "LegacyVSM",
            dependencies: [],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .testTarget(
            name: "LegacyVSMTests",
            dependencies: [
                "LegacyVSM",
                "TestableCombinePublishers"
            ],
            swiftSettings: [
                .swiftLanguageMode(.v5)
            ]
        ),
        .target(
            name: "VSM",
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        ),
        .testTarget(
            name: "VSMTests",
            dependencies: [
                "VSM",
            ],
            swiftSettings: [
                .swiftLanguageMode(.v6)
            ]
        )
    ]
)
