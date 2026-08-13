public struct MediaTrackInspection:
    Sendable,
    Hashable,
    Codable
{
    public let id: Int32
    public let kind: MediaTrackKind
    public let mediaType: String
    public let startSeconds: Double?
    public let durationSeconds: Double?
    public let naturalTimeScale: Int32
    public let estimatedDataRate: Float
    public let nominalFrameRate: Float?
    public let formats: [MediaFormatInspection]
    public let associatedTimecodeTrackIDs: [Int32]

    public init(
        id: Int32,
        kind: MediaTrackKind,
        mediaType: String,
        startSeconds: Double?,
        durationSeconds: Double?,
        naturalTimeScale: Int32,
        estimatedDataRate: Float,
        nominalFrameRate: Float?,
        formats: [MediaFormatInspection],
        associatedTimecodeTrackIDs: [Int32] = []
    ) {
        self.id = id
        self.kind = kind
        self.mediaType = mediaType
        self.startSeconds = startSeconds
        self.durationSeconds = durationSeconds
        self.naturalTimeScale = naturalTimeScale
        self.estimatedDataRate = estimatedDataRate
        self.nominalFrameRate = nominalFrameRate
        self.formats = formats
        self.associatedTimecodeTrackIDs = associatedTimecodeTrackIDs
    }
}
