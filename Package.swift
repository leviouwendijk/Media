// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Media",
    platforms: [
        .macOS(.v14),
    ],
    products: [
        .library(
            name: "Media",
            targets: [
                "Media",
            ]
        ),
        .library(
            name: "MediaCore",
            targets: [
                "MediaCore",
            ]
        ),
        .library(
            name: "MediaAV",
            targets: [
                "MediaAV",
            ]
        ),
        .library(
            name: "MediaLTC",
            targets: [
                "MediaLTC",
            ]
        ),
        .executable(
            name: "media",
            targets: [
                "MediaCLI",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Arguments.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "MediaCore"
        ),
        .target(
            name: "MediaAV",
            dependencies: [
                "MediaCore",
            ]
        ),
        .target(
            name: "MediaLTC",
            dependencies: [
                "MediaCore",
                "MediaAV",
            ]
        ),
        .target(
            name: "Media",
            dependencies: [
                "MediaCore",
                "MediaAV",
                "MediaLTC",
            ]
        ),
        .executableTarget(
            name: "MediaCLI",
            dependencies: [
                "Media",
                .product(
                    name: "Arguments",
                    package: "Arguments"
                ),
            ]
        ),
    ],
    swiftLanguageModes: [
        .v6,
    ]
)
