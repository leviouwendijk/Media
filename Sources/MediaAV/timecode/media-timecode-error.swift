import Foundation

public enum MediaTimecodeError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case invalid_format
    case format_description_failed(
        OSStatus
    )
    case block_buffer_failed(
        OSStatus
    )
    case block_buffer_write_failed(
        OSStatus
    )
    case sample_buffer_failed(
        OSStatus
    )

    public var errorDescription: String? {
        switch self {
        case .invalid_format:
            return "Invalid media timecode format."

        case .format_description_failed(let status):
            return "Could not create the timecode format description: \(status)."

        case .block_buffer_failed(let status):
            return "Could not create the timecode data buffer: \(status)."

        case .block_buffer_write_failed(let status):
            return "Could not write the timecode frame number: \(status)."

        case .sample_buffer_failed(let status):
            return "Could not create the timecode sample buffer: \(status)."
        }
    }
}
