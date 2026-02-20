// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "iphonebase",
    platforms: [
        .macOS(.v14)
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "IPhoneBaseCore",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("ScreenCaptureKit"),
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
            ]
        ),
        .testTarget(
            name: "IPhoneBaseCoreTests",
            dependencies: ["IPhoneBaseCore"]
        ),
    ]
)
