import Foundation

public struct MediaAssetInspection:
    Sendable,
    Hashable,
    Codable
{
    public let url: URL
    public let durationSeconds: Double?
    public let tracks: [MediaTrackInspection]

    public init(
        url: URL,
        durationSeconds: Double?,
        tracks: [MediaTrackInspection]
    ) {
        self.url = url.standardizedFileURL
        self.durationSeconds = durationSeconds
        self.tracks = tracks
    }

    public var videoTracks: [MediaTrackInspection] {
        tracks.filter {
            $0.kind == .video
        }
    }

    public var audioTracks: [MediaTrackInspection] {
        tracks.filter {
            $0.kind == .audio
        }
    }

    public var timecodeTracks: [MediaTrackInspection] {
        tracks.filter {
            $0.kind == .timecode
        }
    }
}
