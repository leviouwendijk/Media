import Foundation
import Media
import TestFlows

extension MediaFlowSuite {
    static var pathFlow: TestFlow {
        TestFlow(
            "media-path",
            tags: [
                "path",
                "discovery",
                "render",
            ]
        ) {
            Step("directory discovery is recursive and filters non-media") {
                let workspace = try MediaTestWorkspace(
                    "path-discovery"
                )

                defer {
                    workspace.remove()
                }

                let source = workspace.directory(
                    "shoot"
                )

                let canon = source.appendingPathComponent(
                    "Canon",
                    isDirectory: true
                )

                try FileManager.default.createDirectory(
                    at: canon,
                    withIntermediateDirectories: true
                )

                try Data().write(
                    to: canon.appendingPathComponent(
                        "A001.MP4"
                    )
                )

                try Data().write(
                    to: canon.appendingPathComponent(
                        "A002.mov"
                    )
                )

                try Data().write(
                    to: canon.appendingPathComponent(
                        "A003.mkv"
                    )
                )

                try Data().write(
                    to: canon.appendingPathComponent(
                        "A004.WEBM"
                    )
                )

                try Data().write(
                    to: canon.appendingPathComponent(
                        "A005.avi"
                    )
                )

                try Data().write(
                    to: canon.appendingPathComponent(
                        "notes.txt"
                    )
                )

                let sources = try MediaSourceDiscovery().discover(
                    source
                )

                try Expect.equal(
                    sources.map(\.relative),
                    [
                        "Canon/A001.MP4",
                        "Canon/A002.mov",
                        "Canon/A003.mkv",
                        "Canon/A004.WEBM",
                        "Canon/A005.avi",
                    ],
                    "media-path.discovery.relative"
                )
            }

            Step("directory render preserves relative topology") {
                let workspace = try MediaTestWorkspace(
                    "directory-layout"
                )

                defer {
                    workspace.remove()
                }

                let sourceRoot = workspace.directory(
                    "shoot"
                )

                try FileManager.default.createDirectory(
                    at: sourceRoot,
                    withIntermediateDirectories: true
                )

                let source = MediaSource(
                    url: sourceRoot
                        .appendingPathComponent(
                            "Canon",
                            isDirectory: true
                        )
                        .appendingPathComponent(
                            "A001.MP4"
                        ),
                    relative: "Canon/A001.MP4"
                )

                let plan = MediaRenderLayout.ltc.plan(
                    source: sourceRoot,
                    sources: [
                        source,
                    ]
                )

                try Expect.equal(
                    plan.outputRoot.lastPathComponent,
                    "ltc-shoot",
                    "media-path.directory.output-root"
                )

                let output = try plan.output(
                    for: source
                )

                try Expect.equal(
                    output.path,
                    plan.outputRoot
                        .appendingPathComponent(
                            "Canon"
                        )
                        .appendingPathComponent(
                            "A001.MP4"
                        )
                        .path,
                    "media-path.directory.output"
                )
            }

            Step("single file render receives ltc prefix") {
                let workspace = try MediaTestWorkspace(
                    "single-file-layout"
                )

                defer {
                    workspace.remove()
                }

                let source = workspace.file(
                    "A001.MP4"
                )

                try Data().write(
                    to: source
                )

                let discovered = try MediaSourceDiscovery().discover(
                    source
                )

                let plan = MediaRenderLayout.ltc.plan(
                    source: source,
                    sources: discovered
                )

                let plannedSource = try Expect.notNil(
                    plan.sources.first,
                    "media-path.single.planned-source"
                )

                let output = try plan.output(
                    for: plannedSource
                )

                try Expect.equal(
                    output.lastPathComponent,
                    "ltc-A001.MP4",
                    "media-path.single.output"
                )
            }
        }
    }
}
