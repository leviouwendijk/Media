public extension LTC {
    struct Timecode:
        Sendable,
        Hashable,
        Codable
    {
        public let hours: Int
        public let minutes: Int
        public let seconds: Int
        public let frame: Int
        public let dropFrame: Bool

        public init(
            hours: Int,
            minutes: Int,
            seconds: Int,
            frame: Int,
            dropFrame: Bool
        ) {
            self.hours = hours
            self.minutes = minutes
            self.seconds = seconds
            self.frame = frame
            self.dropFrame = dropFrame
        }

        public var string: String {
            let separator = dropFrame
                ? ";"
                : ":"

            return String(
                format: "%02d:%02d:%02d%@%02d",
                hours,
                minutes,
                seconds,
                separator,
                frame
            )
        }
    }
}

public extension LTC.Frame {
    var timecode: LTC.Timecode {
        LTC.Timecode(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            frame: frame,
            dropFrame: dropFrame
        )
    }
}
