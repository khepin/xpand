// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "xpand",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "xpand",
            path: "Sources"
        )
    ]
)
