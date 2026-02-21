// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "iphonebase",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
        .package(url: "https://github.com/apple/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        .target(
            name: "IPhoneBaseCore",
            dependencies: [],
            swiftSettings: [.swiftLanguageMode(.v5)],
            linkerSettings: [
                .linkedFramework("Vision"),
                .linkedFramework("CoreGraphics"),
                .linkedFramework("AppKit"),
            ]
        ),
        .executableTarget(
            name: "iphonebase",
            dependencies: [
                "IPhoneBaseCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "IPhoneBaseCoreTests",
            dependencies: [
                "IPhoneBaseCore",
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
    ]
)
