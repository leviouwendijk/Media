public struct MediaTimecodeSampleReadback:
    Sendable,
    Hashable,
    Codable
{
    public let frameNumber: Int32
    public let presentationTimeValue: Int64
    public let presentationTimeTimescale: Int32
    public let durationValue: Int64
    public let durationTimescale: Int32

    public init(
        frameNumber: Int32,
        presentationTimeValue: Int64,
        presentationTimeTimescale: Int32,
        durationValue: Int64,
        durationTimescale: Int32
    ) {
        self.frameNumber = frameNumber
        self.presentationTimeValue = presentationTimeValue
        self.presentationTimeTimescale = presentationTimeTimescale
        self.durationValue = durationValue
        self.durationTimescale = durationTimescale
    }

    public var presentationTimeSeconds: Double {
        guard presentationTimeTimescale != 0 else {
            return 0
        }

        return Double(
            presentationTimeValue
        ) / Double(
            presentationTimeTimescale
        )
    }

    public var durationSeconds: Double {
        guard durationTimescale != 0 else {
            return 0
        }

        return Double(
            durationValue
        ) / Double(
            durationTimescale
        )
    }
}
