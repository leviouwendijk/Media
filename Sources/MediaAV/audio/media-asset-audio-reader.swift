import AVFoundation
import AudioToolbox
import CoreMedia
import Foundation
import MediaCore

public struct MediaAssetAudioReader: Sendable {
    public init() {}

    public func read(
        _ url: URL,
        trackID: Int32? = nil,
        consume: @escaping @Sendable (MediaAudioChunk) throws -> Void
    ) async throws {
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

        let audioTracks = tracks.filter {
            $0.mediaType == .audio
        }

        guard !audioTracks.isEmpty else {
            throw MediaAudioReadError.no_audio_track(
                url
            )
        }

        let track: AVAssetTrack

        if let trackID {
            guard let resolved = audioTracks.first(where: {
                $0.trackID == trackID
            }) else {
                throw MediaAudioReadError.audio_track_not_found(
                    trackID,
                    url
                )
            }

            track = resolved
        } else {
            track = audioTracks[0]
        }

        let reader = try AVAssetReader(
            asset: asset
        )

        let output = AVAssetReaderTrackOutput(
            track: track,
            outputSettings: outputSettings
        )

        guard reader.canAdd(
            output
        ) else {
            throw MediaAudioReadError.cannot_add_output(
                track.trackID
            )
        }

        try await read(
            reader: reader,
            output: output,
            trackID: track.trackID,
            consume: consume
        )
    }
}

private extension MediaAssetAudioReader {
    var outputSettings: [String: Any] {
        [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ]
    }

    func read(
        reader: AVAssetReader,
        output: AVAssetReaderTrackOutput,
        trackID: Int32,
        consume: @escaping @Sendable (MediaAudioChunk) throws -> Void
    ) async throws {
        let provider = reader.outputProvider(
            for: output
        )

        try reader.start()

        while let ready = try await provider.next() {
            try ready.withUnsafeSampleBuffer { sampleBuffer in
                try consume(
                    try chunk(
                        from: sampleBuffer,
                        trackID: trackID
                    )
                )
            }
        }
    }

    func chunk(
        from sampleBuffer: CMSampleBuffer,
        trackID: Int32
    ) throws -> MediaAudioChunk {
        guard let formatDescription = CMSampleBufferGetFormatDescription(
            sampleBuffer
        ) else {
            throw MediaAudioReadError.missing_format_description(
                trackID
            )
        }

        guard let streamDescription = CMAudioFormatDescriptionGetStreamBasicDescription(
            formatDescription
        )?.pointee else {
            throw MediaAudioReadError.missing_stream_description(
                trackID
            )
        }

        guard let blockBuffer = CMSampleBufferGetDataBuffer(
            sampleBuffer
        ) else {
            throw MediaAudioReadError.missing_data_buffer(
                trackID
            )
        }

        let byteCount = CMBlockBufferGetDataLength(
            blockBuffer
        )

        var data = Data(
            count: byteCount
        )

        let status = data.withUnsafeMutableBytes { bytes -> OSStatus in
            guard byteCount > 0,
                  let baseAddress = bytes.baseAddress else {
                return noErr
            }

            return CMBlockBufferCopyDataBytes(
                blockBuffer,
                atOffset: 0,
                dataLength: byteCount,
                destination: baseAddress
            )
        }

        guard status == noErr else {
            throw MediaAudioReadError.block_buffer_read_failed(
                status
            )
        }

        let frameCount = CMSampleBufferGetNumSamples(
            sampleBuffer
        )

        let presentationTime = CMSampleBufferGetPresentationTimeStamp(
            sampleBuffer
        )

        let duration = CMSampleBufferGetDuration(
            sampleBuffer
        )

        return MediaAudioChunk(
            trackID: trackID,
            buffer: MediaAudioBuffer(
                data: data,
                frameCount: frameCount,
                packetCount: UInt32(
                    clamping: frameCount
                ),
                sampleRate: Int(
                    streamDescription.mSampleRate.rounded()
                ),
                channelCount: Int(
                    streamDescription.mChannelsPerFrame
                ),
                sample: .float32,
                hostTimeSeconds: nil
            ),
            presentationTimeSeconds: seconds(
                presentationTime
            ),
            durationSeconds: seconds(
                duration
            )
        )
    }

    func seconds(
        _ time: CMTime
    ) -> TimeInterval? {
        guard time.isValid else {
            return nil
        }

        let value = CMTimeGetSeconds(
            time
        )

        guard value.isFinite else {
            return nil
        }

        return value
    }
}
