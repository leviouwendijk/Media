import AVFoundation
import CoreMedia
import Foundation

public struct MediaAssetTimecodeReader: Sendable {
    public init() {}

    public func firstFrameNumber(
        _ url: URL
    ) async throws -> Int32 {
        let samples = try await samples(
            url
        )

        guard let sample = samples.first else {
            throw MediaAssetTimecodeReadError.no_timecode_sample
        }

        return sample.frameNumber
    }

    public func frameNumbers(
        _ url: URL
    ) async throws -> [Int32] {
        try await samples(
            url
        )
        .map(
            \.frameNumber
        )
    }

    public func samples(
        _ url: URL
    ) async throws -> [MediaTimecodeSampleReadback] {
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

        var samples: [MediaTimecodeSampleReadback] = []

        while let dynamic = try await provider.next() {
            if dynamic.contentType == .markerOnly {
                continue
            }

            guard let sample = CMReadySampleBuffer<
                CMReadOnlyDataBlockBuffer
            >(
                dynamic
            ) else {
                throw MediaAssetTimecodeReadError
                    .unexpected_timecode_content_type(
                        String(
                            describing: dynamic.contentType
                        )
                    )
            }

            let frame = try frameNumber(
                from: Data(
                    sample.content
                )
            )

            let presentationTime = sample.withUnsafeSampleBuffer {
                CMSampleBufferGetPresentationTimeStamp(
                    $0
                )
            }

            let duration = sample.withUnsafeSampleBuffer {
                CMSampleBufferGetDuration(
                    $0
                )
            }

            samples.append(
                MediaTimecodeSampleReadback(
                    frameNumber: frame,
                    presentationTimeValue: presentationTime.value,
                    presentationTimeTimescale: presentationTime.timescale,
                    durationValue: duration.value,
                    durationTimescale: duration.timescale
                )
            )
        }

        guard !samples.isEmpty else {
            throw MediaAssetTimecodeReadError.no_timecode_sample
        }

        return samples
    }
}

private extension MediaAssetTimecodeReader {
    func frameNumber(
        from data: Data
    ) throws -> Int32 {
        guard data.count >= MemoryLayout<Int32>.size else {
            throw MediaAssetTimecodeReadError.invalid_sample_size(
                data.count
            )
        }

        let value = UInt32(
            data[0]
        ) << 24
            | UInt32(
                data[1]
            ) << 16
            | UInt32(
                data[2]
            ) << 8
            | UInt32(
                data[3]
            )

        return Int32(
            bitPattern: value
        )
    }
}
