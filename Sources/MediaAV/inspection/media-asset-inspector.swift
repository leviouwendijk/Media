import AVFoundation
import CoreMedia
import Foundation

public struct MediaAssetInspector: Sendable {
    public init() {}

    public func inspect(
        _ url: URL
    ) async throws -> MediaAssetInspection {
        let url = url.standardizedFileURL

        let asset = AVURLAsset(
            url: url,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true,
            ]
        )

        let duration = try await asset.load(
            .duration
        )

        let tracks = try await asset.load(
            .tracks
        )

        var inspectedTracks: [MediaTrackInspection] = []

        inspectedTracks.reserveCapacity(
            tracks.count
        )

        for track in tracks {
            inspectedTracks.append(
                try await inspect(
                    track
                )
            )
        }

        return MediaAssetInspection(
            url: url,
            durationSeconds: seconds(
                duration
            ),
            tracks: inspectedTracks
        )
    }
}

private extension MediaAssetInspector {
    func inspect(
        _ track: AVAssetTrack
    ) async throws -> MediaTrackInspection {
        let formatDescriptions = try await track.load(
            .formatDescriptions
        )

        let timeRange = try await track.load(
            .timeRange
        )

        let naturalTimeScale = try await track.load(
            .naturalTimeScale
        )

        let estimatedDataRate = try await track.load(
            .estimatedDataRate
        )

        let kind = trackKind(
            for: track.mediaType
        )

        let nominalFrameRate: Float?

        if kind == .video {
            nominalFrameRate = try await track.load(
                .nominalFrameRate
            )
        } else {
            nominalFrameRate = nil
        }

        let associatedTimecodeTrackIDs: [Int32]

        if kind == .video {
            associatedTimecodeTrackIDs = try await track
                .loadAssociatedTracks(
                    ofType: .timecode
                )
                .map(
                    \.trackID
                )
                .sorted()
        } else {
            associatedTimecodeTrackIDs = []
        }

        return MediaTrackInspection(
            id: track.trackID,
            kind: kind,
            mediaType: track.mediaType.rawValue,
            startSeconds: seconds(
                timeRange.start
            ),
            durationSeconds: seconds(
                timeRange.duration
            ),
            naturalTimeScale: naturalTimeScale,
            estimatedDataRate: estimatedDataRate,
            nominalFrameRate: nominalFrameRate,
            formats: formatDescriptions.map(
                inspect
            ),
            associatedTimecodeTrackIDs: associatedTimecodeTrackIDs
        )
    }

    func inspect(
        _ description: CMFormatDescription
    ) -> MediaFormatInspection {
        let mediaType = CMFormatDescriptionGetMediaType(
            description
        )

        let mediaSubtype = CMFormatDescriptionGetMediaSubType(
            description
        )

        var sampleRate: Double?
        var channelCount: Int?
        var width: Int32?
        var height: Int32?
        var timecode: MediaTimecodeFormatInspection?

        if mediaType == kCMMediaType_Audio,
           let basic = CMAudioFormatDescriptionGetStreamBasicDescription(
               description
           )?.pointee {
            sampleRate = basic.mSampleRate
            channelCount = Int(
                basic.mChannelsPerFrame
            )
        }

        if mediaType == kCMMediaType_Video {
            let dimensions = CMVideoFormatDescriptionGetDimensions(
                description
            )

            width = dimensions.width
            height = dimensions.height
        }

        if mediaType == kCMMediaType_TimeCode {
            let frameDuration = CMTimeCodeFormatDescriptionGetFrameDuration(
                description
            )

            let flags = CMTimeCodeFormatDescriptionGetTimeCodeFlags(
                description
            )

            timecode = MediaTimecodeFormatInspection(
                frameDurationValue: frameDuration.value,
                frameDurationTimescale: frameDuration.timescale,
                frameQuanta: CMTimeCodeFormatDescriptionGetFrameQuanta(
                    description
                ),
                dropFrame: flags
                    & kCMTimeCodeFlag_DropFrame
                    != 0,
                wraps24Hours: flags
                    & kCMTimeCodeFlag_24HourMax
                    != 0
            )
        }

        return MediaFormatInspection(
            mediaType: fourCC(
                mediaType
            ),
            mediaSubtype: fourCC(
                mediaSubtype
            ),
            sampleRate: sampleRate,
            channelCount: channelCount,
            width: width,
            height: height,
            timecode: timecode
        )
    }

    func trackKind(
        for mediaType: AVMediaType
    ) -> MediaTrackKind {
        switch mediaType {
        case .video:
            return .video

        case .audio:
            return .audio

        case .timecode:
            return .timecode

        default:
            return .other
        }
    }

    func seconds(
        _ time: CMTime
    ) -> Double? {
        let value = CMTimeGetSeconds(
            time
        )

        guard value.isFinite else {
            return nil
        }

        return value
    }

    func fourCC(
        _ value: FourCharCode
    ) -> String {
        let bytes: [UInt8] = [
            UInt8(
                truncatingIfNeeded: value >> 24
            ),
            UInt8(
                truncatingIfNeeded: value >> 16
            ),
            UInt8(
                truncatingIfNeeded: value >> 8
            ),
            UInt8(
                truncatingIfNeeded: value
            ),
        ]

        if bytes.allSatisfy({
            $0 >= 32 && $0 <= 126
        }),
           let value = String(
               bytes: bytes,
               encoding: .ascii
           ) {
            return value
        }

        return String(
            format: "0x%08X",
            value
        )
    }
}
