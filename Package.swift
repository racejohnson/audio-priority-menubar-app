// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "AudioPriority",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "AudioPriority", targets: ["AudioPriority"]),
        .library(name: "AudioPriorityCore", targets: ["AudioPriorityCore"]),
    ],
    targets: [
        .target(name: "AudioPriorityCore"),
        .executableTarget(name: "AudioPriority", dependencies: ["AudioPriorityCore"]),
        .testTarget(name: "AudioPriorityTests", dependencies: ["AudioPriorityCore"]),
    ],
    swiftLanguageModes: [.v6]
)
