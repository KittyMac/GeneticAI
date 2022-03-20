// swift-tools-version:5.3.0

import PackageDescription

let package = Package(
    name: "GeneticAI",
    platforms: [
        .macOS(.v10_13), .iOS(.v11)
    ],
    products: [
        .library(name: "GeneticAI", targets: ["GeneticAI"])
    ],
    dependencies: [
        .package(url: "https://github.com/KittyMac/Hitch.git", .upToNextMinor(from: "0.4.0")),
    ],
    targets: [
        .target(
            name: "GeneticAI",
            dependencies: [
                "Hitch"
            ]),
        .testTarget(
            name: "GeneticAITests",
            dependencies: ["GeneticAI"]),
    ]
)
