import Foundation

public extension LTC {
    enum DecoderError:
        Error,
        Sendable,
        LocalizedError,
        Equatable
    {
        case invalid_configuration(
            sampleRate: Int,
            fps: Double
        )
        case creation_failed
        case sample_rate_mismatch(
            expected: Int,
            actual: Int
        )

        public var errorDescription: String? {
            switch self {
            case .invalid_configuration(let sampleRate, let fps):
                return "Invalid LTC decoder configuration: sample rate \(sampleRate), fps \(fps)."

            case .creation_failed:
                return "Could not create the LTC decoder."

            case .sample_rate_mismatch(let expected, let actual):
                return "LTC decoder sample rate mismatch: expected \(expected), received \(actual)."
            }
        }
    }
}
