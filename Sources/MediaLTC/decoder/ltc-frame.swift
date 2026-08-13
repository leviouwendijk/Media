public extension LTC {
    struct Frame:
        Sendable,
        Hashable,
        Codable
    {
        public let hours: Int
        public let minutes: Int
        public let seconds: Int
        public let frame: Int
        public let dropFrame: Bool
        public let reverse: Bool
        public let sampleStart: Int64
        public let sampleEnd: Int64
        public let volume: Double

        public init(
            hours: Int,
            minutes: Int,
            seconds: Int,
            frame: Int,
            dropFrame: Bool,
            reverse: Bool,
            sampleStart: Int64,
            sampleEnd: Int64,
            volume: Double
        ) {
            self.hours = hours
            self.minutes = minutes
            self.seconds = seconds
            self.frame = frame
            self.dropFrame = dropFrame
            self.reverse = reverse
            self.sampleStart = sampleStart
            self.sampleEnd = sampleEnd
            self.volume = volume
        }
    }
}
