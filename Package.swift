// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Util",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "UtilCore"),
        .testTarget(name: "UtilCoreTests", dependencies: ["UtilCore"]),
    ]
)
