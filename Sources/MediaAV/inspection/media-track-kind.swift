public enum MediaTrackKind:
    String,
    Sendable,
    Hashable,
    Codable
{
    case video
    case audio
    case timecode
    case other
}
