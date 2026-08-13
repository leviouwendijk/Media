import Foundation

public extension LTC {
    enum AnchorError:
        Error,
        Sendable,
        LocalizedError,
        Equatable
    {
        case invalidConfiguration
        case invalidFrameRate(
            Double
        )
        case unsupportedDropFrame
        case noFrames
        case insufficientConsecutiveFrames(
            required: Int,
            actual: Int
        )
        case invalidTimecode
        case unstable(
            residual: Double,
            limit: Double
        )

        public var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "Invalid LTC anchor resolver configuration."

            case .invalidFrameRate(let fps):
                return "Invalid LTC anchor frame rate: \(fps)."

            case .unsupportedDropFrame:
                return "Drop-frame LTC anchor resolution is not implemented yet."

            case .noFrames:
                return "No forward LTC frames are available for anchor resolution."

            case .insufficientConsecutiveFrames(let required, let actual):
                return "LTC anchor requires \(required) consecutive frames but found \(actual)."

            case .invalidTimecode:
                return "Decoded LTC contains an invalid timecode value."

            case .unstable(let residual, let limit):
                return "LTC anchor residual \(residual) frames exceeds the allowed \(limit) frames."
            }
        }
    }
}
