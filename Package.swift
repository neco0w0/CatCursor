// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacCursor",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "MacCursor", path: "Sources/MacCursor"),
        // Bundled into the app and launched only during calibration: the text
        // I-beam cannot be captured from inside the app's own process.
        .executableTarget(name: "CursorFixture", path: "Sources/CursorFixture"),
    ]
)
