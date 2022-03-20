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
    ],
    targets: [
        .target(
            name: "GeneticAI",
            dependencies: [
            ]),
        .testTarget(
            name: "GeneticAITests",
            dependencies: ["GeneticAI"]),
    ]
)
