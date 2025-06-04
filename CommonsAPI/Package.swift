// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "CommonsAPI",
    platforms: [.macOS(.v15), .iOS(.v18), .visionOS(.v1)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "CommonsAPI",
            targets: ["CommonsAPI"])
    ],
    dependencies: [
        .package(url: "https://github.com/kean/Pulse", from: .init(5, 1, 4)),
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: .init(5, 10, 2)),
        .package(url: "https://github.com/apple/swift-algorithms.git", from: .init(1, 2, 1))
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "CommonsAPI",
            dependencies: [
                .byName(name: "Pulse"),
                .byName(name: "Alamofire"),
                .product(name: "Algorithms", package: "swift-algorithms")
            ]
        ),
        .testTarget(
            name: "CommonsAPITests",
            dependencies: ["CommonsAPI"]
        )
    ]
)
