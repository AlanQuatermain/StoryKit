// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "HauntedFinal",
    platforms: [ .macOS("26.0") ],
    products: [ .executable(name: "HauntedFinal", targets: ["HauntedFinal"]) ],
    dependencies: [ .package(path: "../../") ],
    targets: [ .executableTarget(name: "HauntedFinal", dependencies: [ .product(name: "StoryKit", package: "StoryKit") ]) ]
)
