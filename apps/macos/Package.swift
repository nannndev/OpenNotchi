// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "OpenNotchi",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "OpenNotchi",
            dependencies: ["Sparkle"],
            path: "Sources/OpenNotchi",
            linkerSettings: [
                // Sparkle.framework is embedded in Contents/Frameworks by scripts/build-app.sh.
                .unsafeFlags(["-Xlinker", "-rpath", "-Xlinker", "@executable_path/../Frameworks"]),
            ]
        ),
        // Fetched by scripts/fetch-sparkle.sh (SwiftPM's own artifact download is unreliable).
        .binaryTarget(name: "Sparkle", path: "Vendor/Sparkle/Sparkle.xcframework"),
    ]
)
