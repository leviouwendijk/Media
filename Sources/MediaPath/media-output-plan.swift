import Foundation

public struct MediaOutputPlan: Sendable, Hashable {
    public let sourceRoot: URL
    public let outputRoot: URL
    public let sources: [MediaSource]

    public init(
        sourceRoot: URL,
        outputRoot: URL,
        sources: [MediaSource]
    ) {
        self.sourceRoot = sourceRoot.standardizedFileURL
        self.outputRoot = outputRoot.standardizedFileURL
        self.sources = sources
    }

    public func output(
        for source: MediaSource
    ) throws -> URL {
        let components = source.relative
            .split(
                separator: "/",
                omittingEmptySubsequences: true
            )
            .map(String.init)

        guard !components.isEmpty,
              !components.contains("..") else {
            throw MediaPathError.invalid_output_relative_path(
                source.relative
            )
        }

        return components.reduce(
            outputRoot
        ) { url, component in
            url.appendingPathComponent(
                component
            )
        }
    }
}
