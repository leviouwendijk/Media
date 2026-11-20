// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "MediaTests",
    platforms: [
        .macOS(.v26),
    ],
    products: [

        // test binary
        .executable(
            name: "mediatest",
            targets: [
                "MediaTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
        .package(path: ".."),
    ],
    targets: [
        .executableTarget(
            name: "MediaTestFlows",
            dependencies: [
                .product(name: "Media", package: "Media"),
                .product(
                    name: "TestFlows",
                    package: "TestFlows"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
