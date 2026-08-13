import Foundation

public struct MediaTimecodeFormatInspection:
    Sendable,
    Hashable,
    Codable
{
    public let frameDurationValue: Int64
    public let frameDurationTimescale: Int32
    public let frameQuanta: UInt32
    public let dropFrame: Bool
    public let wraps24Hours: Bool

    public init(
        frameDurationValue: Int64,
        frameDurationTimescale: Int32,
        frameQuanta: UInt32,
        dropFrame: Bool,
        wraps24Hours: Bool
    ) {
        self.frameDurationValue = frameDurationValue
        self.frameDurationTimescale = frameDurationTimescale
        self.frameQuanta = frameQuanta
        self.dropFrame = dropFrame
        self.wraps24Hours = wraps24Hours
    }

    public var framesPerSecond: Double {
        guard frameDurationValue > 0 else {
            return 0
        }

        return Double(
            frameDurationTimescale
        ) / Double(
            frameDurationValue
        )
    }

    public var frameRateString: String {
        let divisor = greatestCommonDivisor(
            Int64(
                frameDurationTimescale
            ),
            frameDurationValue
        )

        let numerator = Int64(
            frameDurationTimescale
        ) / divisor

        let denominator = frameDurationValue
            / divisor

        return String(
            numerator
        ) + "/" + String(
            denominator
        )
    }

    public func timecodeString(
        frameNumber: Int64
    ) -> String {
        let nominal = Int64(
            frameQuanta
        )

        guard nominal > 0 else {
            return String(
                frameNumber
            )
        }

        if dropFrame {
            return dropFrameTimecodeString(
                frameNumber: frameNumber,
                nominal: nominal
            )
        }

        var frameNumber = frameNumber

        if wraps24Hours {
            let framesPerDay = nominal
                * 60
                * 60
                * 24

            frameNumber = positiveModulo(
                frameNumber,
                framesPerDay
            )
        }

        return componentsString(
            frameNumber: frameNumber,
            nominal: nominal,
            separator: ":"
        )
    }
}

private extension MediaTimecodeFormatInspection {
    func dropFrameTimecodeString(
        frameNumber: Int64,
        nominal: Int64
    ) -> String {
        let droppedPerMinute = Int64(
            (
                Double(
                    nominal
                ) * 0.06666666666666667
            ).rounded()
        )

        guard droppedPerMinute > 0 else {
            return componentsString(
                frameNumber: frameNumber,
                nominal: nominal,
                separator: ":"
            )
        }

        let framesPerMinute = nominal
            * 60
            - droppedPerMinute

        let framesPerTenMinutes = nominal
            * 60
            * 10
            - droppedPerMinute
            * 9

        var frameNumber = frameNumber

        if wraps24Hours {
            let framesPerDay = framesPerTenMinutes
                * 6
                * 24

            frameNumber = positiveModulo(
                frameNumber,
                framesPerDay
            )
        }

        let tenMinuteBlocks = frameNumber
            / framesPerTenMinutes

        let remainder = frameNumber
            % framesPerTenMinutes

        var labelledFrame = frameNumber
            + droppedPerMinute
            * 9
            * tenMinuteBlocks

        if remainder > droppedPerMinute {
            labelledFrame += droppedPerMinute
                * (
                    (
                        remainder
                        - droppedPerMinute
                    ) / framesPerMinute
                )
        }

        return componentsString(
            frameNumber: labelledFrame,
            nominal: nominal,
            separator: ";"
        )
    }

    func componentsString(
        frameNumber: Int64,
        nominal: Int64,
        separator: Character
    ) -> String {
        let frame = frameNumber
            % nominal

        let totalSeconds = frameNumber
            / nominal

        let second = totalSeconds
            % 60

        let minute = (
            totalSeconds
            / 60
        ) % 60

        let hour = (
            totalSeconds
            / 3600
        ) % 24

        return String(
            format: "%02lld:%02lld:%02lld%c%02lld",
            hour,
            minute,
            second,
            separator.asciiValue ?? 58,
            frame
        )
    }

    func positiveModulo(
        _ value: Int64,
        _ modulus: Int64
    ) -> Int64 {
        (
            value % modulus
            + modulus
        ) % modulus
    }

    func greatestCommonDivisor(
        _ lhs: Int64,
        _ rhs: Int64
    ) -> Int64 {
        var lhs = abs(
            lhs
        )

        var rhs = abs(
            rhs
        )

        while rhs != 0 {
            let next = lhs
                % rhs

            lhs = rhs
            rhs = next
        }

        return max(
            lhs,
            1
        )
    }
}
