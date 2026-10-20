// swift-tools-version: 6.3

import PackageDescription

let package = Package(
    name: "Media",
    platforms: [
        .macOS(.v26),
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
            name: "MediaAudio",
            targets: [
                "MediaAudio",
            ]
        ),
        .library(
            name: "MediaAV",
            targets: [
                "MediaAV",
            ]
        ),
        .library(
            name: "MediaPath",
            targets: [
                "MediaPath",
            ]
        ),

        .executable(
            name: "media",
            targets: [
                "MediaCLI",
            ]
        ),

        .executable(
            name: "mediatest",
            targets: [
                "MediaTestFlows",
            ]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/leviouwendijk/Arguments.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Terminal.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/Path.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/FileTypes.git",
            branch: "master"
        ),
        .package(
            url: "https://github.com/leviouwendijk/TestFlows.git",
            branch: "master"
        ),
    ],
    targets: [
        .target(
            name: "MediaCore"
        ),
        .target(
            name: "MediaAudio",
            dependencies: [
                "MediaCore",
            ]
        ),
        .target(
            name: "MediaAV",
            dependencies: [
                "MediaCore",
            ]
        ),
        .target(
            name: "MediaPath",
            dependencies: [
                "MediaCore",
                .product(
                    name: "Path",
                    package: "Path"
                ),
                .product(
                    name: "FileTypes",
                    package: "FileTypes"
                ),
            ]
        ),
        .target(
            name: "Media",
            dependencies: [
                "MediaCore",
                "MediaAudio",
                "MediaAV",
                "MediaPath",
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
                .product(
                    name: "Terminal",
                    package: "Terminal"
                ),
            ]
        ),
        .executableTarget(
            name: "MediaTestFlows",
            dependencies: [
                "Media",
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
