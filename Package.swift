// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipboardManagerApp",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipboardManagerApp", targets: ["ClipboardManagerApp"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardManagerApp",
            path: "Sources/ClipboardManagerApp"
        )
    ]
)
