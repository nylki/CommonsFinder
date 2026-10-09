// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonsAPI",
    platforms: [.macOS(.v26), .iOS(.v26), .visionOS(.v26)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CommonsAPI",
            targets: ["CommonsAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Pulse", from: .init(5, 1, 4)),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: .init(1, 2, 1))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CommonsAPI",
            dependencies: [
                .byName(name: "Pulse"),
//                .product(name: "PulseProxy", package: "Pulse"),
                .product(name: "Algorithms", package: "swift-algorithms")
            ]
        ),
        .testTarget(
            name: "CommonsAPITests",
            dependencies: ["CommonsAPI"]
        )
    ]
)
