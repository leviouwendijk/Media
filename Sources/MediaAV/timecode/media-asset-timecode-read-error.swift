import Foundation

public enum MediaAssetTimecodeReadError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case no_timecode_track(
        URL
    )
    case no_timecode_sample
    case unexpected_timecode_content_type(
        String
    )
    case invalid_sample_size(
        Int
    )

    public var errorDescription: String? {
        switch self {
        case .no_timecode_track(let url):
            return "Media asset contains no timecode track: \(url.path)"

        case .no_timecode_sample:
            return "Timecode track contained no sample."

        case .unexpected_timecode_content_type(let type):
            return "Timecode track received Core Media content type: \(type)."

        case .invalid_sample_size(let size):
            return "Timecode sample contained \(size) bytes instead of at least 4."
        }
    }
}
