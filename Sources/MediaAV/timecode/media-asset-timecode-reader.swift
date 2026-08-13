import AVFoundation
import CoreMedia
import Foundation

public struct MediaAssetTimecodeReader: Sendable {
    public init() {}

    public func firstFrameNumber(
        _ url: URL
    ) async throws -> Int32 {
        let url = url.standardizedFileURL

        let asset = AVURLAsset(
            url: url,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true,
            ]
        )

        let tracks = try await asset.load(
            .tracks
        )

        guard let track = tracks.first(where: {
            $0.mediaType == .timecode
        }) else {
            throw MediaAssetTimecodeReadError.no_timecode_track(
                url
            )
        }

        let reader = try AVAssetReader(
            asset: asset
        )

        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: nil
        )

        let provider = reader.outputProvider(
            for: output
        )

        try reader.start()

        while let dynamic = try await provider.next() {
            if dynamic.contentType == .markerOnly {
                continue
            }

            guard let sample = CMReadySampleBuffer<CMReadOnlyDataBlockBuffer>(
                dynamic
            ) else {
                throw MediaAssetTimecodeReadError.unexpected_timecode_content_type(
                    String(
                        describing: dynamic.contentType
                    )
                )
            }

            let data = Data(
                sample.content
            )

            guard data.count >= MemoryLayout<Int32>.size else {
                throw MediaAssetTimecodeReadError.invalid_sample_size(
                    data.count
                )
            }

            let byte0 = UInt32(
                data[0]
            ) << 24

            let byte1 = UInt32(
                data[1]
            ) << 16

            let byte2 = UInt32(
                data[2]
            ) << 8

            let byte3 = UInt32(
                data[3]
            )

            let value = byte0
                | byte1
                | byte2
                | byte3

            return Int32(
                bitPattern: value
            )
        }

        throw MediaAssetTimecodeReadError.no_timecode_sample
    }
}
