// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SymbolReel",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .executable(name: "symbolreel", targets: ["symbolreel"]),
        .library(name: "SymbolReelKit", targets: ["SymbolReelKit"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "SymbolReelKit"
        ),
        .executableTarget(
            name: "symbolreel",
            dependencies: [
                "SymbolReelKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        .testTarget(
            name: "SymbolReelKitTests",
            dependencies: ["SymbolReelKit"]
        ),
    ]
)
