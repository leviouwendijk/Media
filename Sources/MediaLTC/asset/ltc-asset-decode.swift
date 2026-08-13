import Foundation

public extension LTC {
    struct AssetDecode:
        Sendable,
        Hashable,
        Codable
    {
        public let url: URL
        public let trackID: Int32
        public let channel: Int
        public let sampleRate: Int
        public let fps: Double
        public let frames: [Frame]

        public init(
            url: URL,
            trackID: Int32,
            channel: Int,
            sampleRate: Int,
            fps: Double,
            frames: [Frame]
        ) {
            self.url = url.standardizedFileURL
            self.trackID = trackID
            self.channel = channel
            self.sampleRate = sampleRate
            self.fps = fps
            self.frames = frames
        }

        public func mediaSeconds(
            for frame: Frame
        ) -> TimeInterval {
            Double(
                frame.sampleStart
            ) / Double(
                sampleRate
            )
        }

        public func mediaEndSeconds(
            for frame: Frame
        ) -> TimeInterval {
            Double(
                frame.sampleEnd
            ) / Double(
                sampleRate
            )
        }
    }
}
