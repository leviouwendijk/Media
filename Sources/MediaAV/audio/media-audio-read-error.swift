import Foundation

public enum MediaAudioReadError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case no_audio_track(URL)
    case audio_track_not_found(
        Int32,
        URL
    )
    case cannot_add_output(
        Int32
    )
    case missing_format_description(
        Int32
    )
    case missing_stream_description(
        Int32
    )
    case missing_data_buffer(
        Int32
    )
    case block_buffer_read_failed(
        Int32
    )
    case reader_failed(
        String
    )

    public var errorDescription: String? {
        switch self {
        case .no_audio_track(let url):
            return "Media asset contains no audio track: \(url.path)"

        case .audio_track_not_found(let id, let url):
            return "Audio track \(id) was not found in media asset: \(url.path)"

        case .cannot_add_output(let id):
            return "Could not attach reader output for audio track \(id)."

        case .missing_format_description(let id):
            return "Audio track \(id) produced a sample without a format description."

        case .missing_stream_description(let id):
            return "Audio track \(id) produced a sample without a PCM stream description."

        case .missing_data_buffer(let id):
            return "Audio track \(id) produced a sample without a data buffer."

        case .block_buffer_read_failed(let status):
            return "Could not copy PCM bytes from the Core Media block buffer: \(status)."

        case .reader_failed(let message):
            return "Media asset reader failed: \(message)"
        }
    }
}
