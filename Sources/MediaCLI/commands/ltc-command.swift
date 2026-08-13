import Arguments
import Foundation
import Media
import Terminal

enum LTCCommand:
    ArgumentCommand
{
    static let name = "ltc"

    static let children: [ArgumentCommandType] = [
        Probe.self,
        Remux.self,
    ]

    enum Probe:
        RunnableArgumentCommand
    {
        static let name = "probe"

        static func components() throws -> [CommandComponentLowerable] {
            [
                arg(
                    "source",
                    as: String.self,
                    help: "Media file whose native timecode and audio LTC should be compared."
                ),
            ]
        }

        static func run(
            _ invocation: ParsedInvocation
        ) async throws {
            let source = try requiredPath(
                invocation,
                name: "source"
            )

            let inspection = try await MediaAssetInspector().inspect(
                source
            )

            print(
                "source \(source.path)"
            )

            if let videoFPS = inspection.videoTracks
                .compactMap(\.nominalFrameRate)
                .first(where: {
                    $0 > 0
                }) {
                print(
                    "video_fps \(videoFPS)"
                )
            }

            do {
                let frame = try await MediaAssetTimecodeReader()
                    .firstFrameNumber(
                        source
                    )

                guard let timecodeTrack = inspection
                    .timecodeTracks
                    .first,
                      let format = timecodeTrack
                    .formats
                    .compactMap(\.timecode)
                    .first else {
                    throw LTCCommandError.missing_timecode_format(
                        inspection.timecodeTracks.first?.id
                            ?? -1
                    )
                }

                print(
                    [
                        "native_tmcd",
                        "frame=\(frame)",
                        "value=\(format.timecodeString(frameNumber: Int64(frame)))",
                        "rate=\(format.frameRateString)",
                        "fps=\(format.framesPerSecond)",
                        "nominal=\(format.frameQuanta)",
                        "drop_frame=\(format.dropFrame)",
                        "media_timescale=\(timecodeTrack.naturalTimeScale)",
                    ]
                    .joined(
                        separator: " "
                    )
                )

                let samples = try await MediaAssetTimecodeReader()
                    .samples(
                        source
                    )

                for (
                    index,
                    sample
                ) in samples.enumerated() {
                    print(
                        [
                            "tmcd_sample",
                            "index=\(index)",
                            "frame=\(sample.frameNumber)",
                            "pts=\(sample.presentationTimeSeconds)",
                            "pts_raw=\(sample.presentationTimeValue)/\(sample.presentationTimeTimescale)",
                            "duration=\(sample.durationSeconds)",
                            "duration_raw=\(sample.durationValue)/\(sample.durationTimescale)",
                        ]
                        .joined(
                            separator: " "
                        )
                    )
                }
            } catch {
                print(
                    "native_tmcd_error \(error.localizedDescription)"
                )
            }

            let signals = try await LTC.AssetSignalResolver().scan(
                source
            )

            guard !signals.isEmpty else {
                print(
                    "ltc none"
                )

                return
            }

            for signal in signals {
                let detection = signal.detection
                let rate = detection.format.frameRate

                print(
                    [
                        "ltc",
                        "track=\(signal.trackID)",
                        "channel=\(signal.channel)",
                        "rate=\(rate.rationalString)",
                        "fps=\(rate.framesPerSecond)",
                        "nominal=\(rate.nominalFrameRate)",
                        "drop_frame=\(detection.format.dropFrame)",
                        "measured_fps=\(detection.measuredFramesPerSecond)",
                        "median_samples_per_frame=\(detection.medianSamplesPerFrame)",
                        "decoded=\(detection.frameCount)",
                    ]
                    .joined(
                        separator: " "
                    )
                )

                print(
                    [
                        "timing",
                        "first=\(detection.firstTimecode.string)",
                        "first_start=\(detection.firstSampleStart)",
                        "first_end=\(detection.firstSampleEnd)",
                        "last=\(detection.lastTimecode.string)",
                        "last_start=\(detection.lastSampleStart)",
                        "last_end=\(detection.lastSampleEnd)",
                    ]
                    .joined(
                        separator: " "
                    )
                )

                do {
                    let anchor = try signal.anchor()

                    print(
                        [
                            "anchor",
                            "ltc=\(anchor.timecode.string)",
                            "containing_frame=\(anchor.containingFrameAtMediaStart)",
                            "estimated=\(anchor.frameAtMediaStart)",
                            "phase=\(anchor.phaseWithinContainingFrame)",
                            "used=\(anchor.framesUsed)",
                            "residual=\(anchor.maxResidualFrames)",
                        ]
                        .joined(
                            separator: " "
                        )
                    )
                } catch {
                    print(
                        "anchor_error \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    enum Remux:
        RunnableArgumentCommand
    {
        static let name = "remux"

        static func components() throws -> [CommandComponentLowerable] {
            [
                arg(
                    "source",
                    as: String.self,
                    help: "Media file containing embedded audio LTC."
                ),
                arg(
                    "output",
                    as: String.self,
                    help: "New MOV file receiving LTC-derived source timecode."
                ),
            ]
        }

        static func run(
            _ invocation: ParsedInvocation
        ) async throws {
            let source = try requiredPath(
                invocation,
                name: "source"
            )

            let output = try requiredPath(
                invocation,
                name: "output"
            )

            guard output.pathExtension.lowercased() == "mov" else {
                throw LTCCommandError.output_must_be_mov(
                    output
                )
            }

            let startedAt = Date()

            let signal = try await withStatus(
                "Detecting LTC signal",
                success: { signal in
                    let rate = signal.format.frameRate

                    return [
                        "LTC detected",
                        "track \(signal.trackID)",
                        "channel \(signal.channel)",
                        rate.rationalString,
                        signal.format.dropFrame
                            ? "DF"
                            : "NDF",
                    ]
                    .joined(
                        separator: " "
                    )
                }
            ) {
                try await LTC.AssetSignalResolver().resolve(
                    source
                )
            }

            let anchor = try signal.anchor()

            let sourceFrame = anchor.containingFrameAtMediaStart

            guard let frameNumber = Int32(
                exactly: sourceFrame
            ) else {
                throw LTCCommandError.frame_number_out_of_range(
                    sourceFrame
                )
            }

            try await withStatus(
                "Remuxing media",
                success: { _ in
                    "Media remux complete"
                }
            ) {
                try await MediaAssetTimecodeRemuxer().remux(
                    source,
                    to: output,
                    frameNumber: frameNumber,
                    phaseWithinFrame: anchor.phaseWithinContainingFrame,
                    format: signal.format.mediaTimecodeFormat
                )
            }

            let verification = try await withStatus(
                "Verifying output",
                success: { (verification: LTCRemuxVerification) in
                    let essence = verification.essence

                    return [
                        "Output verified:",
                        "tmcd frame \(verification.frame),",
                        "\(essence.tracks.count) media tracks,",
                        "\(essence.totalByteCount) bytes unchanged",
                    ]
                    .joined(
                        separator: " "
                    )
                }
            ) {
                let writtenFrame = try await MediaAssetTimecodeReader()
                    .firstFrameNumber(
                        output
                    )

                guard writtenFrame == frameNumber else {
                    throw LTCCommandError.timecode_readback_mismatch(
                        expected: frameNumber,
                        actual: writtenFrame
                    )
                }

                let inspection = try await MediaAssetInspector().inspect(
                    output
                )

                guard inspection.timecodeTracks.count == 1 else {
                    throw LTCCommandError.unexpected_timecode_track_count(
                        inspection.timecodeTracks.count
                    )
                }

                let timecodeTrack = inspection.timecodeTracks[0]

                for videoTrack in inspection.videoTracks {
                    guard videoTrack.associatedTimecodeTrackIDs.contains(
                        timecodeTrack.id
                    ) else {
                        throw LTCCommandError.missing_timecode_association(
                            videoTrackID: videoTrack.id,
                            timecodeTrackID: timecodeTrack.id
                        )
                    }
                }

                guard let inspectedFormat = timecodeTrack
                    .formats
                    .first?
                    .timecode else {
                    throw LTCCommandError.missing_timecode_format(
                        timecodeTrack.id
                    )
                }

                let expectedFormat = signal.format.mediaTimecodeFormat

                guard inspectedFormat.frameDurationValue
                        == expectedFormat.frameDuration.value,
                      inspectedFormat.frameDurationTimescale
                        == expectedFormat.frameDuration.timescale,
                      inspectedFormat.frameQuanta
                        == expectedFormat.frameQuanta,
                      inspectedFormat.dropFrame
                        == expectedFormat.dropFrame,
                      inspectedFormat.wraps24Hours
                        == expectedFormat.wraps24Hours else {
                    throw LTCCommandError.timecode_format_mismatch(
                        timecodeTrack.id
                    )
                }

                let essence = try await MediaAssetEssenceVerifier().verify(
                    source,
                    against: output
                )

                return LTCRemuxVerification(
                    frame: writtenFrame,
                    essence: essence
                )
            }

            let writtenFrame = verification.frame

            let rate = signal.format.frameRate

            print(
                "output \(output.path)"
            )

            print(
                [
                    "ltc",
                    "track=\(signal.trackID)",
                    "channel=\(signal.channel)",
                    "rate=\(rate.rationalString)",
                    "fps=\(rate.framesPerSecond)",
                    "nominal=\(rate.nominalFrameRate)",
                    "drop_frame=\(signal.format.dropFrame)",
                ]
                .joined(
                    separator: " "
                )
            )

            print(
                [
                    "source_timecode=\(anchor.timecode.string)",
                    "frame=\(frameNumber)",
                    "phase=\(anchor.phaseWithinContainingFrame)",
                    "residual=\(anchor.maxResidualFrames)",
                ]
                .joined(
                    separator: " "
                )
            )

            print(
                "tmcd_readback \(writtenFrame)"
            )

            let totalElapsed = TerminalDurationFormatter.format(
                Date().timeIntervalSince(
                    startedAt
                )
            )

            print(
                "completed \(totalElapsed)"
            )
        }
    }
}

enum LTCCommandError:
    Error,
    LocalizedError
{
    case missing_path(
        String
    )

    case output_must_be_mov(
        URL
    )

    case frame_number_out_of_range(
        Int64
    )

    case timecode_readback_mismatch(
        expected: Int32,
        actual: Int32
    )

    case unexpected_timecode_track_count(
        Int
    )

    case missing_timecode_association(
        videoTrackID: Int32,
        timecodeTrackID: Int32
    )

    case missing_timecode_format(
        Int32
    )

    case timecode_format_mismatch(
        Int32
    )

    var errorDescription: String? {
        switch self {
        case .missing_path(let name):
            return "Missing required \(name) path."

        case .output_must_be_mov(let url):
            return "LTC remux output must use a .mov extension: \(url.path)"

        case .frame_number_out_of_range(let frame):
            return "LTC source frame does not fit the TimeCode32 representation: \(frame)."

        case .timecode_readback_mismatch(let expected, let actual):
            return "Written timecode readback mismatch; expected \(expected), received \(actual)."

        case .unexpected_timecode_track_count(let count):
            return "Remuxed media contains \(count) timecode tracks instead of exactly one."

        case .missing_timecode_association(
            let videoTrackID,
            let timecodeTrackID
        ):
            return "Video track \(videoTrackID) is not associated with timecode track \(timecodeTrackID)."

        case .missing_timecode_format(let trackID):
            return "Timecode track \(trackID) has no inspectable timecode format description."

        case .timecode_format_mismatch(let trackID):
            return "Timecode track \(trackID) does not contain the requested LTC-derived timecode format."
        }
    }
}

private struct LTCRemuxVerification: Sendable {
    let frame: Int32
    let essence: MediaAssetEssenceVerification
}

private func withStatus<Value>(
    _ line: String,
    success: (Value) -> String,
    operation: () async throws -> Value
) async throws -> Value {
    let startedAt = Date()

    let status = TerminalLiveStatusLine { frame in
        "\(line) \(frame.elapsedText)"
    }

    await status.start()

    do {
        let value = try await operation()

        let elapsed = TerminalDurationFormatter.format(
            Date().timeIntervalSince(
                startedAt
            )
        )

        await status.stop(
            finalLine: "\(success(value)) in \(elapsed)"
        )

        return value
    } catch {
        let elapsed = TerminalDurationFormatter.format(
            Date().timeIntervalSince(
                startedAt
            )
        )

        await status.stop(
            finalLine: "Failed: \(line) after \(elapsed)"
        )

        throw error
    }
}

private func requiredPath(
    _ invocation: ParsedInvocation,
    name: ParamName
) throws -> URL {
    guard let value = try invocation.value(
        name,
        as: String.self
    ) else {
        throw LTCCommandError.missing_path(
            name.rawValue
        )
    }

    return URL(
        fileURLWithPath: NSString(
            string: value
        ).expandingTildeInPath
    )
    .standardizedFileURL
}
