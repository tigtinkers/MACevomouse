// swift-tools-version: 5.9
import PackageDescription

var products: [Product] = [
    .library(name: "MACEvoCore", targets: ["MACEvoCore"]),
    .executable(name: "macevo-cli", targets: ["macevo-cli"])
]
var targets: [Target] = [
    .target(name: "MACEvoCore"),
    .executableTarget(name: "macevo-cli", dependencies: ["MACEvoCore"]),
    .testTarget(name: "MACEvoCoreTests", dependencies: ["MACEvoCore"])
]
#if os(macOS)
products.append(.executable(name: "macevo-inspector", targets: ["MACEvoInspector"]))
targets.append(.target(name: "MACEvoHIDBridge", linkerSettings: [.linkedFramework("CoreGraphics"), .linkedFramework("IOKit")]))
targets.append(.executableTarget(name: "MACEvoInspector", dependencies: ["MACEvoCore", "MACEvoHIDBridge"]))
targets.append(.testTarget(name: "MACEvoMacTests", dependencies: ["MACEvoInspector", "MACEvoCore"]))
#endif

let package = Package(
    name: "MACevomouse",
    platforms: [.macOS(.v13)],
    products: products,
    targets: targets
)
