// swift-tools-version: 5.9
import PackageDescription
let package = Package(
    name: "PocketPikachu", platforms: [.macOS(.v14)],
    products: [.executable(name: "PocketPikachu", targets: ["PocketPikachu"])],
    targets: [
        .target(name: "PocketCore"),
        .executableTarget(name: "PocketPikachu", dependencies: ["PocketCore"], resources: [.process("Resources")]),
        .testTarget(name: "PocketCoreTests", dependencies: ["PocketCore"])
    ]
)
