// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "WatchCore",
    platforms: [.macOS(.v14), .watchOS("26.0")],
    products: [.library(name: "WatchCore", targets: ["WatchCore"])],
    targets: [
        .target(name: "WatchCore"),
        .testTarget(name: "WatchCoreTests", dependencies: ["WatchCore"])
    ]
)
