// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "HauntedCLIRunner",
    platforms: [ .macOS("26.0") ],
    products: [ .executable(name: "haunted", targets: ["HauntedCLIRunner"]) ],
    dependencies: [
        // Use a local path to the StoryKit package under development
        .package(path: "../StoryKit"),
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0")
    ],
    targets: [
        .executableTarget(
            name: "HauntedCLIRunner",
            dependencies: [
                .product(name: "StoryKit", package: "StoryKit"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)

