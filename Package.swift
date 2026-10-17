// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MACevomouse",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "MACEvoCore", targets: ["MACEvoCore"]),
        .executable(name: "macevo-cli", targets: ["macevo-cli"])
    ],
    targets: [
        .target(name: "MACEvoCore"),
        .executableTarget(name: "macevo-cli", dependencies: ["MACEvoCore"]),
        .testTarget(name: "MACEvoCoreTests", dependencies: ["MACEvoCore"])
    ]
)
