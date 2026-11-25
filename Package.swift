// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TongchuanCore",
    platforms: [.macOS(.v13), .iOS(.v15)],
    products: [.library(name: "TongchuanCore", targets: ["TongchuanCore"])],
    targets: [
        .target(name: "TongchuanCore", path: "Sources/Core"),
        .testTarget(name: "TongchuanCoreTests", dependencies: ["TongchuanCore"],
                    path: "Tests/CoreTests", resources: [.copy("Fixtures")])
    ]
)
