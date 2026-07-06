// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClipCmd",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "ClipCmdCore", targets: ["ClipCmdCore"]),
        .executable(name: "clipcmd", targets: ["clipcmd"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        .target(
            name: "ClipCmdCore",
            path: "Sources/ClipCmdCore"
        ),
        .executableTarget(
            name: "clipcmd",
            dependencies: [
                "ClipCmdCore",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ],
            path: "Sources/clipcmd"
        ),
        .testTarget(
            name: "ClipCmdCoreTests",
            dependencies: ["ClipCmdCore"],
            path: "Tests/ClipCmdCoreTests"
        ),
    ]
)
