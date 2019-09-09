// swift-tools-version:5.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "TextBufferKit",
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "TextBufferKit",
            targets: ["TextBufferKit"]),
    ],
    targets: [
        .target(
            name: "TextBufferKit",
            path: "TextBufferKit"),
        .testTarget(
            name: "TextBufferKitTests",
            dependencies: ["TextBufferKit"],
            path: "TextBufferKitTests"),
    ]
)