// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ClipboardHistoryApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipboardHistoryApp", targets: ["ClipboardHistoryApp"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardHistoryApp",
            path: "Sources"
        )
    ]
)
