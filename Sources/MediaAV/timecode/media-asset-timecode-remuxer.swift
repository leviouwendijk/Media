import AVFoundation
import CoreMedia
import Foundation

public struct MediaAssetTimecodeRemuxer: Sendable {
    public init() {}

    public func remux(
        _ source: URL,
        to output: URL,
        frameNumber: Int32,
        phaseWithinFrame: Double? = nil,
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

        if let phaseWithinFrame {
            guard phaseWithinFrame.isFinite,
                  phaseWithinFrame >= 0,
                  phaseWithinFrame < 1 else {
                throw MediaAssetTimecodeRemuxError.invalid_timecode_phase(
                    phaseWithinFrame
                )
            }
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

        let referenceTimeScale = try await referenceVideoTrack.load(
            .naturalTimeScale
        )

        timecodeInput.mediaTimeScale = referenceTimeScale

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

        let timecodeFactory = MediaTimecodeSampleFactory(
            format: format
        )

        var timecodeSamples = [
            try timecodeFactory.sample(
                frameNumber: frameNumber,
                presentationTime: .zero,
                duration: duration,
                formatDescription: timecodeDescription
            ),
        ]

        if let phaseWithinFrame,
           phaseWithinFrame > 0 {
            let unscaledBoundary = CMTimeMultiplyByFloat64(
                format.frameDuration,
                multiplier: 1 - phaseWithinFrame
            )

            let boundary = CMTimeConvertScale(
                unscaledBoundary,
                timescale: referenceTimeScale,
                method: .roundHalfAwayFromZero
            )

            guard boundary.isValid,
                  boundary.isNumeric,
                  CMTimeCompare(
                      boundary,
                      .zero
                  ) > 0,
                  CMTimeCompare(
                      boundary,
                      duration
                  ) < 0 else {
                throw MediaAssetTimecodeRemuxError
                    .timecode_phase_boundary_outside_media
            }

            let nextFrame = frameNumber.addingReportingOverflow(
                1
            )

            guard !nextFrame.overflow else {
                throw MediaAssetTimecodeRemuxError.timecode_frame_overflow(
                    frameNumber
                )
            }

            timecodeSamples = [
                try timecodeFactory.sample(
                    frameNumber: frameNumber,
                    presentationTime: .zero,
                    duration: boundary,
                    formatDescription: timecodeDescription
                ),
                try timecodeFactory.sample(
                    frameNumber: nextFrame.partialValue,
                    presentationTime: boundary,
                    duration: CMTimeSubtract(
                        duration,
                        boundary
                    ),
                    formatDescription: timecodeDescription
                ),
            ]
        }

        do {
            try writer.start()

            writer.startSession(
                atSourceTime: .zero
            )

            try reader.start()

            for sample in timecodeSamples {
                try await timecodeReceiver.append(
                    sample
                )
            }

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
