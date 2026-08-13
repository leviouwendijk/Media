import Foundation

public struct MediaRenderLayout: Sendable, Hashable {
    public let prefix: String

    public init(
        prefix: String
    ) {
        self.prefix = prefix
    }

    public func plan(
        source: URL,
        sources: [MediaSource]
    ) -> MediaOutputPlan {
        let source = source.standardizedFileURL

        var isDirectory: ObjCBool = false

        FileManager.default.fileExists(
            atPath: source.path,
            isDirectory: &isDirectory
        )

        if isDirectory.boolValue {
            let outputRoot = source
                .deletingLastPathComponent()
                .appendingPathComponent(
                    prefix + source.lastPathComponent,
                    isDirectory: true
                )

            return MediaOutputPlan(
                sourceRoot: source,
                outputRoot: outputRoot,
                sources: sources
            )
        }

        let parent = source.deletingLastPathComponent()

        let transformed = source
            .deletingPathExtension()
            .lastPathComponent

        let ext = source.pathExtension

        let filename = ext.isEmpty
            ? prefix + transformed
            : prefix + transformed + "." + ext

        let transformedSource = MediaSource(
            url: source,
            relative: filename
        )

        return MediaOutputPlan(
            sourceRoot: source,
            outputRoot: parent,
            sources: [
                transformedSource,
            ]
        )
    }
}

public extension MediaRenderLayout {
    static let ltc = MediaRenderLayout(
        prefix: "ltc-"
    )
}
