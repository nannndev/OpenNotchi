// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OpenNotchi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OpenNotchi",
            path: "Sources/OpenNotchi"
        )
    ]
)
