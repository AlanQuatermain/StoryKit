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
            targets: ["Core", "Engine", "Persistence", "ContentIO", "StoryKit"]
        ),
        .executable(
            name: "storykit",
            targets: ["StoryKitCLI"]
        ),
        .executable(
            name: "HauntedCLI",
            targets: ["HauntedCLI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        // Submodules
        .target(
            name: "Core"
        ),
        .target(
            name: "Engine",
            dependencies: ["Core"]
        ),
        .target(
            name: "Persistence",
            dependencies: ["Core"]
        ),
        .target(
            name: "ContentIO",
            dependencies: ["Core"]
        ),
        // Umbrella target that can provide convenience types/imports.
        .target(
            name: "StoryKit",
            dependencies: ["Core", "Engine", "Persistence", "ContentIO"]
        ),
        // CLI tool
        .executableTarget(
            name: "StoryKitCLI",
            dependencies: [
                "Core",
                "Engine",
                "ContentIO",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        ),
        .executableTarget(
            name: "HauntedCLI",
            dependencies: ["StoryKit"]
        ),
        .executableTarget(
            name: "SyncSnippets",
            dependencies: ["Core", "ContentIO"]
        ),
        // Tests (swift-testing)
        .testTarget(
            name: "StoryKitTests",
            dependencies: ["Core", "Engine", "ContentIO", "Persistence"],
            path: "Tests/StoryKitTests"
        )
    ]
)
