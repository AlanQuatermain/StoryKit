// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StoryKit",
    platforms: [
        .macOS("26.0"),
        .iOS("26.0")
    ],
    products: [
        .library(
            name: "StoryKit",
            targets: ["StoryKit"]
        ),
        .executable(
            name: "storykit",
            targets: ["StoryKitCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
        // DocC plugin for generating documentation via `swift package generate-documentation`
        .package(url: "https://github.com/apple/swift-docc-plugin", from: "1.3.0")
    ],
    targets: [
        // Unified library target
        .target(
            name: "StoryKit"
        ),
        // CLI tool
        .executableTarget(
            name: "StoryKitCLI",
            dependencies: [
                "StoryKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        // Tests (swift-testing)
        .testTarget(
            name: "StoryKitTests",
            dependencies: ["StoryKit"],
            path: "Tests/StoryKitTests"
        )
    ]
)
