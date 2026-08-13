import Foundation

public enum MediaAssetTimecodeRemuxError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case identical_source_and_output
    case output_exists(
        URL
    )
    case no_video_track
    case invalid_duration
    case invalid_timecode_phase(
        Double
    )
    case timecode_frame_overflow(
        Int32
    )
    case timecode_phase_boundary_outside_media
    case missing_format_description(
        Int32
    )
    case cannot_add_reader_output(
        Int32
    )
    case cannot_add_writer_input(
        Int32
    )
    case cannot_add_timecode_input
    case cannot_associate_timecode(
        Int32
    )
    case writer_failed(
        String
    )

    public var errorDescription: String? {
        switch self {
        case .identical_source_and_output:
            return "Media timecode remux requires distinct source and output files."

        case .output_exists(let url):
            return "Media timecode remux output already exists: \(url.path)"

        case .no_video_track:
            return "Media timecode remux requires at least one video track."

        case .invalid_duration:
            return "Media asset has no finite positive duration."

        case .invalid_timecode_phase(let phase):
            return "Timecode phase must be finite and in [0, 1): \(phase)."

        case .timecode_frame_overflow(let frame):
            return "Timecode frame cannot advance beyond TimeCode32: \(frame)."

        case .timecode_phase_boundary_outside_media:
            return "Timecode phase boundary does not fall inside the media duration."

        case .missing_format_description(let id):
            return "Media track \(id) has no format description for passthrough."

        case .cannot_add_reader_output(let id):
            return "Could not attach passthrough reader output for track \(id)."

        case .cannot_add_writer_input(let id):
            return "Could not attach passthrough writer input for track \(id)."

        case .cannot_add_timecode_input:
            return "Could not attach the output timecode track."

        case .cannot_associate_timecode(let id):
            return "Could not associate video track \(id) with the output timecode track."

        case .writer_failed(let message):
            return "Media timecode remux writer failed: \(message)"
        }
    }
}
