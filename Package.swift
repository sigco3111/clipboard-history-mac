// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipboardHistoryMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ClipboardHistoryMac", targets: ["ClipboardHistoryMac"])
    ],
    targets: [
        .executableTarget(
            name: "ClipboardHistoryMac",
            path: "Sources/ClipboardHistoryMac",
            exclude: [
                "Info.plist",
                "ClipboardHistory.entitlements"
            ]
        )
    ]
)