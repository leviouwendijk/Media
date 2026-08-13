import Foundation
import Media
import TestFlows

extension MediaFlowSuite {
    static var avFlow: TestFlow {
        TestFlow(
            "media-av",
            tags: [
                "av",
                "inspection",
                "audio",
            ]
        ) {
            Step("inspector recognizes generated stereo WAV") {
                let workspace = try MediaTestWorkspace(
                    "av-inspection"
                )

                defer {
                    workspace.remove()
                }

                let fixture = workspace.file(
                    "stereo.wav"
                )

                try makePCM16WAV().write(
                    to: fixture
                )

                let inspection = try await MediaAssetInspector().inspect(
                    fixture
                )

                try Expect.equal(
                    inspection.audioTracks.count,
                    1,
                    "media-av.inspect.audio-track-count"
                )

                try Expect.equal(
                    inspection.videoTracks.count,
                    0,
                    "media-av.inspect.video-track-count"
                )

                let track = try Expect.notNil(
                    inspection.audioTracks.first,
                    "media-av.inspect.audio-track"
                )

                let format = try Expect.notNil(
                    track.formats.first,
                    "media-av.inspect.audio-format"
                )

                try Expect.equal(
                    format.sampleRate,
                    48_000,
                    "media-av.inspect.sample-rate"
                )

                try Expect.equal(
                    format.channelCount,
                    2,
                    "media-av.inspect.channel-count"
                )
            }

            Step("synthetic MOV contains associated tmcd timecode track") {
                let workspace = try MediaTestWorkspace(
                    "av-timecode"
                )

                defer {
                    workspace.remove()
                }

                let fixture = workspace.file(
                    "timecode.mov"
                )

                try await makeSyntheticTimecodeMovie(
                    at: fixture
                )

                let inspection = try await MediaAssetInspector().inspect(
                    fixture
                )

                try Expect.equal(
                    inspection.videoTracks.count,
                    1,
                    "media-av.timecode.video-track-count"
                )

                try Expect.equal(
                    inspection.audioTracks.count,
                    1,
                    "media-av.timecode.audio-track-count"
                )

                try Expect.equal(
                    inspection.timecodeTracks.count,
                    1,
                    "media-av.timecode.track-count"
                )

                let track = try Expect.notNil(
                    inspection.timecodeTracks.first,
                    "media-av.timecode.track"
                )

                let format = try Expect.notNil(
                    track.formats.first,
                    "media-av.timecode.format"
                )

                try Expect.equal(
                    format.mediaSubtype,
                    "tmcd",
                    "media-av.timecode.subtype"
                )

                let timecode = try Expect.notNil(
                    format.timecode,
                    "media-av.timecode.format-details"
                )

                try Expect.equal(
                    timecode.frameDurationValue,
                    1,
                    "media-av.timecode.frame-duration-value"
                )

                try Expect.equal(
                    timecode.frameDurationTimescale,
                    25,
                    "media-av.timecode.frame-duration-timescale"
                )

                try Expect.equal(
                    timecode.frameQuanta,
                    25,
                    "media-av.timecode.frame-quanta"
                )

                try Expect.equal(
                    timecode.dropFrame,
                    false,
                    "media-av.timecode.drop-frame"
                )

                try Expect.equal(
                    timecode.wraps24Hours,
                    true,
                    "media-av.timecode.wraps-24-hours"
                )

                let videoTrack = try Expect.notNil(
                    inspection.videoTracks.first,
                    "media-av.timecode.video-track"
                )

                try Expect.equal(
                    videoTrack.associatedTimecodeTrackIDs,
                    [
                        track.id,
                    ],
                    "media-av.timecode.video-association"
                )
            }

            Step("tmcd remux preserves compressed video and audio sample data") {
                let workspace = try MediaTestWorkspace(
                    "av-timecode-remux"
                )

                defer {
                    workspace.remove()
                }

                let source = workspace.file(
                    "source.mov"
                )

                let output = workspace.file(
                    "output.mov"
                )

                try await makeSyntheticTimecodeMovie(
                    at: source
                )

                try await MediaAssetTimecodeRemuxer().remux(
                    source,
                    to: output,
                    frameNumber: 42,
                    format: .fps(
                        25
                    )
                )

                let sourceInspection = try await MediaAssetInspector().inspect(
                    source
                )

                let outputInspection = try await MediaAssetInspector().inspect(
                    output
                )

                try Expect.equal(
                    outputInspection.videoTracks.count,
                    sourceInspection.videoTracks.count,
                    "media-av.remux.video-track-count"
                )

                try Expect.equal(
                    outputInspection.audioTracks.count,
                    sourceInspection.audioTracks.count,
                    "media-av.remux.audio-track-count"
                )

                try Expect.equal(
                    outputInspection.timecodeTracks.count,
                    1,
                    "media-av.remux.timecode-track-count"
                )

                let sourceFormat = try Expect.notNil(
                    sourceInspection.videoTracks.first?.formats.first,
                    "media-av.remux.source-format"
                )

                let outputFormat = try Expect.notNil(
                    outputInspection.videoTracks.first?.formats.first,
                    "media-av.remux.output-format"
                )

                try Expect.equal(
                    outputFormat.mediaSubtype,
                    sourceFormat.mediaSubtype,
                    "media-av.remux.video-subtype"
                )

                let sourceAudioFormat = try Expect.notNil(
                    sourceInspection.audioTracks.first?.formats.first,
                    "media-av.remux.source-audio-format"
                )

                let outputAudioFormat = try Expect.notNil(
                    outputInspection.audioTracks.first?.formats.first,
                    "media-av.remux.output-audio-format"
                )

                try Expect.equal(
                    outputAudioFormat.mediaSubtype,
                    sourceAudioFormat.mediaSubtype,
                    "media-av.remux.audio-subtype"
                )

                let essence = try await MediaAssetEssenceVerifier().verify(
                    source,
                    against: output
                )

                try Expect.equal(
                    essence.tracks.count,
                    2,
                    "media-av.remux.essence-track-count"
                )

                try Expect.true(
                    essence.totalByteCount > 0,
                    "media-av.remux.essence-byte-count"
                )

                try Expect.equal(
                    try await MediaAssetTimecodeReader().firstFrameNumber(
                        output
                    ),
                    42,
                    "media-av.remux.timecode-frame-number"
                )
            }

            Step("phase-aligned tmcd persists LTC boundary sample") {
                let workspace = try MediaTestWorkspace(
                    "av-timecode-phase"
                )

                defer {
                    workspace.remove()
                }

                let source = workspace.file(
                    "source.mov"
                )

                let output = workspace.file(
                    "phase.mov"
                )

                try await makeSyntheticTimecodeMovie(
                    at: source
                )

                try await MediaAssetTimecodeRemuxer().remux(
                    source,
                    to: output,
                    frameNumber: 42,
                    phaseWithinFrame: 0.5,
                    format: .fps(
                        25
                    )
                )

                let frames = try await MediaAssetTimecodeReader()
                    .frameNumbers(
                        output
                    )

                try Expect.equal(
                    frames,
                    [
                        42,
                        43,
                    ],
                    "media-av.timecode.phase-samples"
                )

                let essence = try await MediaAssetEssenceVerifier()
                    .verify(
                        source,
                        against: output
                    )

                try Expect.true(
                    essence.totalByteCount > 0,
                    "media-av.timecode.phase-preserves-essence"
                )
            }

            Step("audio reader decodes generated WAV to float32 chunks") {
                let workspace = try MediaTestWorkspace(
                    "av-audio-reader"
                )

                defer {
                    workspace.remove()
                }

                let fixture = workspace.file(
                    "stereo.wav"
                )

                try makePCM16WAV(
                    frames: 480
                ).write(
                    to: fixture
                )

                let collector = MediaAudioChunkCollector()

                try await MediaAssetAudioReader().read(
                    fixture
                ) { chunk in
                    collector.append(
                        chunk
                    )
                }

                let chunks = collector.snapshot()

                try Expect.notEmpty(
                    chunks,
                    "media-av.reader.chunks"
                )

                let first = try Expect.notNil(
                    chunks.first,
                    "media-av.reader.first"
                )

                try Expect.equal(
                    first.buffer.sample,
                    .float32,
                    "media-av.reader.sample"
                )

                try Expect.equal(
                    first.buffer.sampleRate,
                    48_000,
                    "media-av.reader.sample-rate"
                )

                try Expect.equal(
                    first.buffer.channelCount,
                    2,
                    "media-av.reader.channel-count"
                )

                try Expect.equal(
                    chunks.reduce(0) {
                        $0 + $1.buffer.frameCount
                    },
                    480,
                    "media-av.reader.total-frames"
                )
            }
        }
    }
}
