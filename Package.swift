// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MacMemoApp",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "MacMemoApp",
            targets: ["MacMemoApp"]
        )
    ],
    targets: [
        .executableTarget(
            name: "MacMemoApp"
        )
    ]
)
