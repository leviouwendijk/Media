import Foundation
import MediaAV

public extension LTC {
    struct AssetDecoder: Sendable {
        public init() {}

        public func decode(
            _ url: URL,
            trackID: Int32? = nil,
            channel: Int,
            fps: Double
        ) async throws -> AssetDecode {
            let url = url.standardizedFileURL
            let state = LTCAssetDecodeState()

            try await MediaAssetAudioReader().read(
                url,
                trackID: trackID
            ) { chunk in
                try state.consume(
                    chunk,
                    channel: channel,
                    fps: fps
                )
            }

            return try state.snapshot(
                url: url,
                channel: channel,
                fps: fps
            )
        }
    }
}

private final class LTCAssetDecodeState:
    @unchecked Sendable
{
    private let lock = NSLock()

    private var decoder: LTC.Decoder?
    private var sampleRate: Int?
    private var trackID: Int32?
    private var frames: [LTC.Frame] = []
    private var nextSampleOffset: Int64 = 0

    func consume(
        _ chunk: MediaAudioChunk,
        channel: Int,
        fps: Double
    ) throws {
        lock.lock()

        defer {
            lock.unlock()
        }

        let decoder: LTC.Decoder

        if let existing = self.decoder {
            decoder = existing
        } else {
            let created = try LTC.Decoder(
                sampleRate: chunk.buffer.sampleRate,
                fps: fps
            )

            self.decoder = created
            sampleRate = chunk.buffer.sampleRate
            trackID = chunk.trackID

            decoder = created
        }

        let sampleOffset: Int64

        if let presentationTime = chunk.presentationTimeSeconds {
            sampleOffset = Int64(
                (
                    presentationTime
                    * Double(
                        chunk.buffer.sampleRate
                    )
                ).rounded()
            )
        } else {
            sampleOffset = nextSampleOffset
        }

        frames.append(
            contentsOf: try decoder.append(
                chunk.buffer,
                channel: channel,
                sampleOffset: sampleOffset
            )
        )

        nextSampleOffset = sampleOffset
            + Int64(
                chunk.buffer.frameCount
            )
    }

    func snapshot(
        url: URL,
        channel: Int,
        fps: Double
    ) throws -> LTC.AssetDecode {
        lock.lock()

        defer {
            lock.unlock()
        }

        guard let sampleRate,
              let trackID else {
            throw LTC.AssetDecoderError.no_audio_samples(
                url
            )
        }

        return LTC.AssetDecode(
            url: url,
            trackID: trackID,
            channel: channel,
            sampleRate: sampleRate,
            fps: fps,
            frames: frames
        )
    }
}
