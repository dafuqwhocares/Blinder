// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "BlinderApp",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .executable(name: "BlinderApp", targets: ["BlinderApp"]),
    ],
    targets: [
        .executableTarget(
            name: "BlinderApp",
            path: ".",
            exclude: [
                ".build",
                ".build-arm64-release",
                "dist",
                "Assets.xcassets",
                "Preview Content",
                "BlinderApp.entitlements",
                "README.md",
                "build-arm64-signed.sh",
                "package-app-arm64.sh",
            ]
        ),
    ]
)
