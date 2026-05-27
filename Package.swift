// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "leash",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "leash",
            path: "Sources/leash"
        )
    ]
)
