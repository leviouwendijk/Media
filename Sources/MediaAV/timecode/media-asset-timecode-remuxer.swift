import AVFoundation
import CoreMedia
import Foundation

public struct MediaAssetTimecodeRemuxer: Sendable {
    public init() {}

    public func remux(
        _ source: URL,
        to output: URL,
        frameNumber: Int32,
        format: MediaTimecodeFormat
    ) async throws {
        let source = source.standardizedFileURL
        let output = output.standardizedFileURL

        guard source != output else {
            throw MediaAssetTimecodeRemuxError.identical_source_and_output
        }

        guard !FileManager.default.fileExists(
            atPath: output.path
        ) else {
            throw MediaAssetTimecodeRemuxError.output_exists(
                output
            )
        }

        let asset = AVURLAsset(
            url: source,
            options: [
                AVURLAssetPreferPreciseDurationAndTimingKey: true,
            ]
        )

        let tracks = try await asset.load(
            .tracks
        )

        let mediaTracks = tracks.filter {
            $0.mediaType == .video
                || $0.mediaType == .audio
        }

        guard let referenceVideoTrack = mediaTracks.first(where: {
            $0.mediaType == .video
        }) else {
            throw MediaAssetTimecodeRemuxError.no_video_track
        }

        let duration = try await asset.load(
            .duration
        )

        let durationSeconds = CMTimeGetSeconds(
            duration
        )

        guard duration.isValid,
              durationSeconds.isFinite,
              durationSeconds > 0 else {
            throw MediaAssetTimecodeRemuxError.invalid_duration
        }

        let reader = try AVAssetReader(
            asset: asset
        )

        let writer = try AVAssetWriter(
            url: output,
            fileType: .mov
        )

        let timecodeDescription = try format.formatDescription()

        let timecodeInput = AVAssetWriterInput(
            mediaType: .timecode,
            outputSettings: nil,
            sourceFormatHint: timecodeDescription
        )

        timecodeInput.mediaTimeScale = try await referenceVideoTrack.load(
            .naturalTimeScale
        )

        guard writer.canAdd(
            timecodeInput
        ) else {
            throw MediaAssetTimecodeRemuxError.cannot_add_timecode_input
        }

        var pending: [MediaAssetPassthroughPending] = []

        pending.reserveCapacity(
            mediaTracks.count
        )

        for track in mediaTracks {
            let descriptions = try await track.load(
                .formatDescriptions
            )

            guard let description = descriptions.first else {
                throw MediaAssetTimecodeRemuxError.missing_format_description(
                    track.trackID
                )
            }

            let readerOutput = AVAssetReaderTrackOutput(
                track: track,
                outputSettings: nil
            )

            guard reader.canAdd(
                readerOutput
            ) else {
                throw MediaAssetTimecodeRemuxError.cannot_add_reader_output(
                    track.trackID
                )
            }

            let writerInput = AVAssetWriterInput(
                mediaType: track.mediaType,
                outputSettings: nil,
                sourceFormatHint: description
            )

            guard writer.canAdd(
                writerInput
            ) else {
                throw MediaAssetTimecodeRemuxError.cannot_add_writer_input(
                    track.trackID
                )
            }

            if track.mediaType == .video {
                writerInput.transform = try await track.load(
                    .preferredTransform
                )

                writerInput.mediaTimeScale = try await track.load(
                    .naturalTimeScale
                )
            }

            if track.mediaType == .audio {
                writerInput.preferredVolume = try await track.load(
                    .preferredVolume
                )
            }

            writerInput.languageCode = try await track.load(
                .languageCode
            )

            writerInput.extendedLanguageTag = try await track.load(
                .extendedLanguageTag
            )

            pending.append(
                MediaAssetPassthroughPending(
                    trackID: track.trackID,
                    mediaType: track.mediaType,
                    readerOutput: readerOutput,
                    writerInput: writerInput
                )
            )
        }

        for item in pending where item.mediaType == .video {
            guard item.writerInput.canAddTrackAssociation(
                withTrackOf: timecodeInput,
                type: AVAssetTrack.AssociationType.timecode.rawValue
            ) else {
                throw MediaAssetTimecodeRemuxError.cannot_associate_timecode(
                    item.trackID
                )
            }

            item.writerInput.addTrackAssociation(
                withTrackOf: timecodeInput,
                type: AVAssetTrack.AssociationType.timecode.rawValue
            )
        }

        var transfers: [MediaAssetPassthroughTransfer] = []

        transfers.reserveCapacity(
            pending.count
        )

        for item in pending {
            transfers.append(
                MediaAssetPassthroughTransfer(
                    provider: reader.outputProvider(
                        for: item.readerOutput
                    ),
                    receiver: writer.inputReceiver(
                        for: item.writerInput
                    )
                )
            )
        }

        let timecodeReceiver = writer.inputReceiver(
            for: timecodeInput
        )

        let timecodeSample = try MediaTimecodeSampleFactory(
            format: format
        ).sample(
            frameNumber: frameNumber,
            presentationTime: .zero,
            duration: duration,
            formatDescription: timecodeDescription
        )

        do {
            try writer.start()

            writer.startSession(
                atSourceTime: .zero
            )

            try reader.start()

            try await timecodeReceiver.append(
                timecodeSample
            )

            timecodeReceiver.finish()

            try await withThrowingTaskGroup(
                of: Void.self
            ) { group in
                for transfer in transfers {
                    group.addTask {
                        try await transfer.run()
                    }
                }

                try await group.waitForAll()
            }

            await writer.finishWriting()
        } catch {
            reader.cancelReading()
            writer.cancelWriting()

            throw error
        }

        guard writer.status == .completed else {
            throw MediaAssetTimecodeRemuxError.writer_failed(
                writer.error?.localizedDescription
                    ?? "Unknown AVAssetWriter failure."
            )
        }
    }
}

private struct MediaAssetPassthroughPending {
    let trackID: Int32
    let mediaType: AVMediaType
    let readerOutput: AVAssetReaderTrackOutput
    let writerInput: AVAssetWriterInput
}

private actor MediaAssetPassthroughTransfer {
    private let provider: AVAssetReaderOutput.Provider<
        CMReadySampleBuffer<CMSampleBuffer.DynamicContent>
    >

    private let receiver: AVAssetWriterInput.SampleBufferReceiver

    init(
        provider: sending AVAssetReaderOutput.Provider<
            CMReadySampleBuffer<CMSampleBuffer.DynamicContent>
        >,
        receiver: sending AVAssetWriterInput.SampleBufferReceiver
    ) {
        self.provider = provider
        self.receiver = receiver
    }

    func run() async throws {
        while let sample = try await provider.next() {
            try await receiver.append(
                sample
            )
        }

        receiver.finish()
    }
}
