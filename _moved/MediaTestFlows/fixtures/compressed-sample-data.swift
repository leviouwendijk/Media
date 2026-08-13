import AVFoundation
import CoreMedia
import Foundation

enum CompressedSampleDataError:
    Error,
    LocalizedError
{
    case track_not_found
    case sample_not_found
    case unexpected_compressed_content_type(
        String
    )
    case invalid_sample_size

    var errorDescription: String? {
        switch self {
        case .track_not_found:
            return "Compressed sample fixture track was not found."

        case .sample_not_found:
            return "Compressed sample fixture contained no media sample."

        case .unexpected_compressed_content_type(let type):
            return "Compressed sample fixture received Core Media content type: \(type)."

        case .invalid_sample_size:
            return "Compressed sample fixture contained no sample bytes."
        }
    }
}

func firstCompressedSampleData(
    at url: URL,
    mediaType: AVMediaType
) async throws -> Data {
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
        $0.mediaType == mediaType
    }) else {
        throw CompressedSampleDataError.track_not_found
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
            throw CompressedSampleDataError.unexpected_compressed_content_type(
                String(
                    describing: dynamic.contentType
                )
            )
        }

        let data = Data(
            sample.content
        )

        guard !data.isEmpty else {
            throw CompressedSampleDataError.invalid_sample_size
        }

        return data
    }

    throw CompressedSampleDataError.sample_not_found
}
