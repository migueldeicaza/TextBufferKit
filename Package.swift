// swift-tools-version:5.0
import PackageDescription

let package = Package(
    name: "TextBufferKit",
    products: [
        .library(
            name: "TextBufferKit",
            targets: ["TextBufferKit"]),
    ],
    targets: [
        .target(
            name: "TextBufferKit",
            dependencies: []),
        .testTarget(
            name: "TextBufferKitTests",
            dependencies: ["TextBufferKit"]),
    ]
)
