import AVFoundation
import CoreMedia
import Foundation

public struct MediaAssetEssenceVerification:
    Sendable,
    Hashable,
    Codable
{
    public let source: URL
    public let candidate: URL
    public let tracks: [MediaTrackEssenceVerification]

    public init(
        source: URL,
        candidate: URL,
        tracks: [MediaTrackEssenceVerification]
    ) {
        self.source = source.standardizedFileURL
        self.candidate = candidate.standardizedFileURL
        self.tracks = tracks
    }

    public var totalByteCount: Int64 {
        tracks.reduce(
            0
        ) {
            $0 + $1.byteCount
        }
    }

    public var sourceBufferCount: Int {
        tracks.reduce(
            0
        ) {
            $0 + $1.sourceBufferCount
        }
    }

    public var candidateBufferCount: Int {
        tracks.reduce(
            0
        ) {
            $0 + $1.candidateBufferCount
        }
    }
}

public struct MediaTrackEssenceVerification:
    Sendable,
    Hashable,
    Codable
{
    public let mediaType: String
    public let mediaSubtype: String
    public let sourceTrackID: Int32
    public let candidateTrackID: Int32
    public let sourceBufferCount: Int
    public let candidateBufferCount: Int
    public let byteCount: Int64

    public init(
        mediaType: String,
        mediaSubtype: String,
        sourceTrackID: Int32,
        candidateTrackID: Int32,
        sourceBufferCount: Int,
        candidateBufferCount: Int,
        byteCount: Int64
    ) {
        self.mediaType = mediaType
        self.mediaSubtype = mediaSubtype
        self.sourceTrackID = sourceTrackID
        self.candidateTrackID = candidateTrackID
        self.sourceBufferCount = sourceBufferCount
        self.candidateBufferCount = candidateBufferCount
        self.byteCount = byteCount
    }
}

public enum MediaAssetEssenceVerificationError:
    Error,
    Sendable,
    LocalizedError,
    Equatable
{
    case media_track_count_mismatch(
        source: Int,
        candidate: Int
    )

    case media_type_mismatch(
        index: Int,
        source: String,
        candidate: String
    )

    case missing_format_description(
        Int32
    )

    case media_subtype_mismatch(
        index: Int,
        source: String,
        candidate: String
    )

    case cannot_add_reader_output(
        Int32
    )

    case unexpected_content_type(
        trackID: Int32,
        type: String
    )

    case stream_length_mismatch(
        index: Int,
        matchedBytes: Int64
    )

    case byte_mismatch(
        index: Int,
        offset: Int64
    )

    case reader_failed(
        trackID: Int32,
        message: String
    )

    public var errorDescription: String? {
        switch self {
        case .media_track_count_mismatch(
            let source,
            let candidate
        ):
            return "Media essence track count differs: source \(source), candidate \(candidate)."

        case .media_type_mismatch(
            let index,
            let source,
            let candidate
        ):
            return "Media essence track \(index) type differs: source \(source), candidate \(candidate)."

        case .missing_format_description(let trackID):
            return "Media essence track \(trackID) has no format description."

        case .media_subtype_mismatch(
            let index,
            let source,
            let candidate
        ):
            return "Media essence track \(index) subtype differs: source \(source), candidate \(candidate)."

        case .cannot_add_reader_output(let trackID):
            return "Could not attach essence reader output for track \(trackID)."

        case .unexpected_content_type(
            let trackID,
            let type
        ):
            return "Media essence track \(trackID) produced Core Media content type \(type)."

        case .stream_length_mismatch(
            let index,
            let matchedBytes
        ):
            return "Media essence track \(index) differs in length after \(matchedBytes) identical bytes."

        case .byte_mismatch(
            let index,
            let offset
        ):
            return "Media essence track \(index) differs at encoded byte offset \(offset)."

        case .reader_failed(
            let trackID,
            let message
        ):
            return "Media essence reader failed for track \(trackID): \(message)"
        }
    }
}

public struct MediaAssetEssenceVerifier: Sendable {
    public init() {}

    public func verify(
        _ source: URL,
        against candidate: URL
    ) async throws -> MediaAssetEssenceVerification {
        let source = source.standardizedFileURL
        let candidate = candidate.standardizedFileURL

        let sourceAsset = asset(
            source
        )

        let candidateAsset = asset(
            candidate
        )

        let sourceTracks = try await mediaTracks(
            sourceAsset
        )

        let candidateTracks = try await mediaTracks(
            candidateAsset
        )

        guard sourceTracks.count == candidateTracks.count else {
            throw MediaAssetEssenceVerificationError.media_track_count_mismatch(
                source: sourceTracks.count,
                candidate: candidateTracks.count
            )
        }

        var verified: [MediaTrackEssenceVerification] = []

        verified.reserveCapacity(
            sourceTracks.count
        )

        for index in sourceTracks.indices {
            let sourceTrack = sourceTracks[index]
            let candidateTrack = candidateTracks[index]

            guard sourceTrack.mediaType == candidateTrack.mediaType else {
                throw MediaAssetEssenceVerificationError.media_type_mismatch(
                    index: index,
                    source: sourceTrack.mediaType.rawValue,
                    candidate: candidateTrack.mediaType.rawValue
                )
            }

            let sourceSubtype = try await mediaSubtype(
                sourceTrack
            )

            let candidateSubtype = try await mediaSubtype(
                candidateTrack
            )

            guard sourceSubtype == candidateSubtype else {
                throw MediaAssetEssenceVerificationError.media_subtype_mismatch(
                    index: index,
                    source: fourCC(
                        sourceSubtype
                    ),
                    candidate: fourCC(
                        candidateSubtype
                    )
                )
            }

            let sourceStream = try stream(
                asset: sourceAsset,
                track: sourceTrack
            )

            let candidateStream = try stream(
                asset: candidateAsset,
                track: candidateTrack
            )

            let result = try await compare(
                sourceStream,
                candidateStream,
                index: index
            )

            verified.append(
                MediaTrackEssenceVerification(
                    mediaType: sourceTrack.mediaType.rawValue,
                    mediaSubtype: fourCC(
                        sourceSubtype
                    ),
                    sourceTrackID: sourceTrack.trackID,
                    candidateTrackID: candidateTrack.trackID,
                    sourceBufferCount: result.sourceBufferCount,
                    candidateBufferCount: result.candidateBufferCount,
                    byteCount: result.byteCount
                )
            )
        }

        return MediaAssetEssenceVerification(
            source: source,
            candidate: candidate,
            tracks: verified
        )
    }
}

private extension MediaAssetEssenceVerifier {
    func asset(
        _ url: URL
    ) -> AVURLAsset {
        AVURLAsset(
            url: url,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true,
            ]
        )
    }

    func mediaTracks(
        _ asset: AVURLAsset
    ) async throws -> [AVAssetTrack] {
        try await asset.load(
            .tracks
        )
        .filter {
            $0.mediaType == .video
                || $0.mediaType == .audio
        }
    }

    func mediaSubtype(
        _ track: AVAssetTrack
    ) async throws -> FourCharCode {
        let descriptions = try await track.load(
            .formatDescriptions
        )

        guard let description = descriptions.first else {
            throw MediaAssetEssenceVerificationError.missing_format_description(
                track.trackID
            )
        }

        return CMFormatDescriptionGetMediaSubType(
            description
        )
    }

    func stream(
        asset: AVURLAsset,
        track: AVAssetTrack
    ) throws -> MediaAssetEssenceStream {
        let reader = try AVAssetReader(
            asset: asset
        )

        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: nil
        )

        guard reader.canAdd(
            output
        ) else {
            throw MediaAssetEssenceVerificationError.cannot_add_reader_output(
                track.trackID
            )
        }

        let provider = reader.outputProvider(
            for: output
        )

        try reader.start()

        return MediaAssetEssenceStream(
            trackID: track.trackID,
            reader: reader,
            output: output,
            provider: provider
        )
    }

    func compare(
        _ source: MediaAssetEssenceStream,
        _ candidate: MediaAssetEssenceStream,
        index: Int
    ) async throws -> MediaAssetEssenceStreamResult {
        var sourceData = Data()
        var candidateData = Data()

        var sourceOffset = 0
        var candidateOffset = 0

        var sourceEnded = false
        var candidateEnded = false

        var sourceBufferCount = 0
        var candidateBufferCount = 0

        var byteCount: Int64 = 0

        while true {
            if sourceOffset == sourceData.count,
               !sourceEnded {
                if let next = try await source.next() {
                    sourceData = next
                    sourceOffset = 0
                    sourceBufferCount += 1
                } else {
                    sourceEnded = true
                    sourceData = Data()
                    sourceOffset = 0
                }
            }

            if candidateOffset == candidateData.count,
               !candidateEnded {
                if let next = try await candidate.next() {
                    candidateData = next
                    candidateOffset = 0
                    candidateBufferCount += 1
                } else {
                    candidateEnded = true
                    candidateData = Data()
                    candidateOffset = 0
                }
            }

            if sourceEnded,
               candidateEnded {
                break
            }

            guard !sourceEnded,
                  !candidateEnded else {
                throw MediaAssetEssenceVerificationError.stream_length_mismatch(
                    index: index,
                    matchedBytes: byteCount
                )
            }

            let sourceRemaining = sourceData.count
                - sourceOffset

            let candidateRemaining = candidateData.count
                - candidateOffset

            let count = min(
                sourceRemaining,
                candidateRemaining
            )

            guard count > 0 else {
                continue
            }

            let sourceRange = sourceOffset
                ..< sourceOffset + count

            let candidateRange = candidateOffset
                ..< candidateOffset + count

            guard sourceData[sourceRange].elementsEqual(
                candidateData[candidateRange]
            ) else {
                throw MediaAssetEssenceVerificationError.byte_mismatch(
                    index: index,
                    offset: byteCount
                )
            }

            sourceOffset += count
            candidateOffset += count
            byteCount += Int64(
                count
            )
        }

        return MediaAssetEssenceStreamResult(
            sourceBufferCount: sourceBufferCount,
            candidateBufferCount: candidateBufferCount,
            byteCount: byteCount
        )
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
           let string = String(
               bytes: bytes,
               encoding: .ascii
           ) {
            return string
        }

        return String(
            format: "0x%08X",
            value
        )
    }
}

private struct MediaAssetEssenceStreamResult {
    let sourceBufferCount: Int
    let candidateBufferCount: Int
    let byteCount: Int64
}

private final class MediaAssetEssenceStream {
    private let trackID: Int32

    private let reader: AVAssetReader

    private let output: AVAssetReaderTrackOutput

    private let provider: AVAssetReaderOutput.Provider<
        CMReadySampleBuffer<CMSampleBuffer.DynamicContent>
    >

    init(
        trackID: Int32,
        reader: AVAssetReader,
        output: AVAssetReaderTrackOutput,
        provider: AVAssetReaderOutput.Provider<
            CMReadySampleBuffer<CMSampleBuffer.DynamicContent>
        >
    ) {
        self.trackID = trackID
        self.reader = reader
        self.output = output
        self.provider = provider
    }

    func next() async throws -> Data? {
        while let dynamic = try await provider.next() {
            if dynamic.contentType == .markerOnly {
                continue
            }

            guard let sample = CMReadySampleBuffer<
                CMReadOnlyDataBlockBuffer
            >(
                dynamic
            ) else {
                throw MediaAssetEssenceVerificationError.unexpected_content_type(
                    trackID: trackID,
                    type: String(
                        describing: dynamic.contentType
                    )
                )
            }

            let data = Data(
                sample.content
            )

            if data.isEmpty {
                continue
            }

            return data
        }

        if reader.status == .failed {
            throw MediaAssetEssenceVerificationError.reader_failed(
                trackID: trackID,
                message: reader.error?.localizedDescription
                    ?? "Unknown AVAssetReader failure."
            )
        }

        _ = output

        return nil
    }
}
