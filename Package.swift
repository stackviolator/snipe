// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "snipe",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "snipe",
            path: "Sources/Snipe",
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
