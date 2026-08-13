public extension LTC {
    struct FrameRate:
        Sendable,
        Hashable,
        Codable
    {
        public let numerator: Int
        public let denominator: Int
        public let nominalFrameRate: Int

        public init(
            numerator: Int,
            denominator: Int,
            nominalFrameRate: Int
        ) {
            precondition(
                numerator > 0
            )

            precondition(
                denominator > 0
            )

            precondition(
                nominalFrameRate > 0
            )

            self.numerator = numerator
            self.denominator = denominator
            self.nominalFrameRate = nominalFrameRate
        }

        public var framesPerSecond: Double {
            Double(
                numerator
            ) / Double(
                denominator
            )
        }

        public var rationalString: String {
            "\(numerator)/\(denominator)"
        }

        public static let fps23_976 = FrameRate(
            numerator: 24_000,
            denominator: 1_001,
            nominalFrameRate: 24
        )

        public static let fps24 = FrameRate(
            numerator: 24,
            denominator: 1,
            nominalFrameRate: 24
        )

        public static let fps25 = FrameRate(
            numerator: 25,
            denominator: 1,
            nominalFrameRate: 25
        )

        public static let fps29_97 = FrameRate(
            numerator: 30_000,
            denominator: 1_001,
            nominalFrameRate: 30
        )

        public static let fps30 = FrameRate(
            numerator: 30,
            denominator: 1,
            nominalFrameRate: 30
        )

        public static let common: [FrameRate] = [
            .fps23_976,
            .fps24,
            .fps25,
            .fps29_97,
            .fps30,
        ]
    }

    struct SignalFormat:
        Sendable,
        Hashable,
        Codable
    {
        public let frameRate: FrameRate
        public let dropFrame: Bool

        public init(
            frameRate: FrameRate,
            dropFrame: Bool
        ) {
            self.frameRate = frameRate
            self.dropFrame = dropFrame
        }
    }
}
