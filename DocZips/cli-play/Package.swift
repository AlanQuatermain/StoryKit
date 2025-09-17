// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "HauntedCLI",
    platforms: [ .macOS("26.0") ],
    products: [ .executable(name: "HauntedCLI", targets: ["HauntedCLI"]) ],
    dependencies: [ .package(path: "../../") ],
    targets: [ .executableTarget(name: "HauntedCLI", dependencies: [ .product(name: "StoryKit", package: "StoryKit") ]) ]
)
