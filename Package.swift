// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Snipe",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Snipe",
            path: "Sources/Snipe"
        )
    ]
)
