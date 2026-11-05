// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Util",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Util", dependencies: ["UtilCore", "ClipboardFeature", "SwitcherFeature"]),
        .target(name: "UtilCore"),
        .target(name: "ClipboardFeature", dependencies: ["UtilCore"]),
        .target(name: "SwitcherFeature", dependencies: ["UtilCore"]),
        .testTarget(name: "UtilCoreTests", dependencies: ["UtilCore"]),
        .testTarget(name: "ClipboardFeatureTests", dependencies: ["ClipboardFeature"]),
        .testTarget(name: "SwitcherFeatureTests", dependencies: ["SwitcherFeature"]),
    ]
)
