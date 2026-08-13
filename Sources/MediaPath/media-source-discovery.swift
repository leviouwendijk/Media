import FileTypes
import Foundation
import Path

public struct MediaSourceDiscovery: Sendable {
    public let videoTypes: Set<VideoFile>

    public init(
        videoTypes: Set<VideoFile> = Set(
            VideoFile.allCases
        )
    ) {
        self.videoTypes = videoTypes
    }

    public func discover(
        _ source: URL
    ) throws -> [MediaSource] {
        let source = source.standardizedFileURL

        var isDirectory: ObjCBool = false

        guard FileManager.default.fileExists(
            atPath: source.path,
            isDirectory: &isDirectory
        ) else {
            throw MediaPathError.source_not_found(
                source
            )
        }

        if !isDirectory.boolValue {
            guard accepts(
                source
            ) else {
                return []
            }

            return [
                MediaSource(
                    url: source,
                    relative: source.lastPathComponent
                ),
            ]
        }

        return try PathWalker(
            root: source
        )
        .walk()
        .filter {
            $0.type == .file
                && accepts(
                    $0.url
                )
        }
        .map {
            MediaSource(
                url: $0.url,
                relative: $0.url.pathComponents
                    .dropFirst(
                        source.pathComponents.count
                    )
                    .joined(
                        separator: "/"
                    )
            )
        }
        .sorted {
            $0.relative < $1.relative
        }
    }
}

private extension MediaSourceDiscovery {
    func accepts(
        _ url: URL
    ) -> Bool {
        guard let type = VideoFile(
            fileExtension: url.pathExtension
        ) else {
            return false
        }

        return videoTypes.contains(
            type
        )
    }
}
