public extension LTC {
    struct AssetSignal:
        Sendable,
        Hashable,
        Codable
    {
        public let decode: AssetDecode
        public let detection: FrameRateDetection

        public init(
            decode: AssetDecode,
            detection: FrameRateDetection
        ) {
            self.decode = decode
            self.detection = detection
        }

        public var trackID: Int32 {
            decode.trackID
        }

        public var channel: Int {
            decode.channel
        }

        public var format: SignalFormat {
            detection.format
        }

        public func anchor(
            minimumFrames: Int = 3,
            maximumResidualFrames: Double = 0.25
        ) throws -> Anchor {
            try decode.anchor(
                frameRate: detection.format.frameRate,
                minimumFrames: minimumFrames,
                maximumResidualFrames: maximumResidualFrames
            )
        }
    }
}
