// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Kiito",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "Kiito",
            path: "Sources/Kiito"
        )
    ]
)
