import Foundation

public enum MediaAudioBufferError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case invalid_channel(
        Int,
        count: Int
    )

    public var errorDescription: String? {
        switch self {
        case .invalid_channel(let channel, let count):
            return "Audio channel \(channel) is outside the available channel range 0..<\(count)."
        }
    }
}
