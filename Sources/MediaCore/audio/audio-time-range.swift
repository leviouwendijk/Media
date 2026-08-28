import Foundation

public extension Audio {
    struct TimeRange:
        Sendable,
        Codable,
        Hashable
    {
        public let start: TimeInterval
        public let duration: TimeInterval

        public init(
            start: TimeInterval,
            duration: TimeInterval
        ) {
            self.start = start
            self.duration = duration
        }

        public var end: TimeInterval {
            start + duration
        }
    }
}
