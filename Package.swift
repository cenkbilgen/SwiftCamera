// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftCamera",
    platforms: [.iOS(.v17), .macOS(.v15)],
    products: [
        .library(
            name: "SwiftCamera",
            targets: ["SwiftCamera"]),
    ],
    targets: [
        .target(
            name: "SwiftCamera"),

    ]
)
