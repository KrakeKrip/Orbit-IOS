// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Orbit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "OrbitCore", targets: ["OrbitCore"]),
    ],
    targets: [
        .target(name: "OrbitCore"),
        .testTarget(
            name: "OrbitCoreTests",
            dependencies: ["OrbitCore"]
        ),
    ]
)
