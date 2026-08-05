// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sniptool",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "sniptool",
            path: "Sources/SnipTool",
            linkerSettings: [
                .linkedFramework("Carbon"),
            ]
        )
    ]
)
