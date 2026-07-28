// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacCursor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MacCursor", path: "Sources/MacCursor")
    ]
)
