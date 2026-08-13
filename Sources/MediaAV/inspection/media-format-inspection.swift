public struct MediaFormatInspection:
    Sendable,
    Hashable,
    Codable
{
    public let mediaType: String
    public let mediaSubtype: String
    public let sampleRate: Double?
    public let channelCount: Int?
    public let width: Int32?
    public let height: Int32?
    public let timecode: MediaTimecodeFormatInspection?

    public init(
        mediaType: String,
        mediaSubtype: String,
        sampleRate: Double? = nil,
        channelCount: Int? = nil,
        width: Int32? = nil,
        height: Int32? = nil,
        timecode: MediaTimecodeFormatInspection? = nil
    ) {
        self.mediaType = mediaType
        self.mediaSubtype = mediaSubtype
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.width = width
        self.height = height
        self.timecode = timecode
    }
}
