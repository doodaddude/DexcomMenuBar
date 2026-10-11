// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DexcomMenuBar",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "DexcomMenuBar",
            targets: ["DexcomMenuBar"]
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DexcomMenuBar",
            dependencies: [],
            path: "Sources/DexcomMenuBar"
        )
    ]
)
