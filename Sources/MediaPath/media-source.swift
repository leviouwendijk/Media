import Foundation

public struct MediaSource: Sendable, Hashable {
    public let url: URL
    public let relative: String

    public init(
        url: URL,
        relative: String
    ) {
        self.url = url.standardizedFileURL
        self.relative = relative
    }
}
