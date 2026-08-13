import Foundation
import Media
import TestFlows

extension MediaFlowSuite {
    static var ltcFlow: TestFlow {
        TestFlow(
            "media-ltc",
            tags: [
                "ltc",
                "decoder",
                "timecode",
            ]
        ) {
            Step("generated 25fps LTC decodes to expected timecode") {
                let samples = try makeLTCFloatSignal(
                    sampleRate: 48_000,
                    fps: 25,
                    hours: 12,
                    minutes: 34,
                    seconds: 56,
                    frame: 0,
                    frameCount: 4
                )

                let decoder = try LTC.Decoder(
                    sampleRate: 48_000,
                    fps: 25
                )

                let frames = decoder.append(
                    samples,
                    sampleOffset: 0
                )

                try Expect.notEmpty(
                    frames,
                    "media-ltc.frames"
                )

                let target = try Expect.notNil(
                    frames.first {
                        $0.hours == 12
                            && $0.minutes == 34
                            && $0.seconds == 56
                    },
                    "media-ltc.expected-time"
                )

                try Expect.equal(
                    target.hours,
                    12,
                    "media-ltc.hours"
                )

                try Expect.equal(
                    target.minutes,
                    34,
                    "media-ltc.minutes"
                )

                try Expect.equal(
                    target.seconds,
                    56,
                    "media-ltc.seconds"
                )

                try Expect.equal(
                    target.frame,
                    0,
                    "media-ltc.frame"
                )

                try Expect.equal(
                    target.dropFrame,
                    false,
                    "media-ltc.drop-frame"
                )
            }

            Step("consecutive LTC frames resolve media-start timecode") {
                let decode = LTC.AssetDecode(
                    url: URL(
                        fileURLWithPath: "/tmp/anchor.wav"
                    ),
                    trackID: 1,
                    channel: 0,
                    sampleRate: 48_000,
                    fps: 25,
                    frames: [
                        LTC.Frame(
                            hours: 12,
                            minutes: 34,
                            seconds: 56,
                            frame: 5,
                            dropFrame: false,
                            reverse: false,
                            sampleStart: 9_600,
                            sampleEnd: 11_519,
                            volume: 0
                        ),
                        LTC.Frame(
                            hours: 12,
                            minutes: 34,
                            seconds: 56,
                            frame: 6,
                            dropFrame: false,
                            reverse: false,
                            sampleStart: 11_520,
                            sampleEnd: 13_439,
                            volume: 0
                        ),
                        LTC.Frame(
                            hours: 12,
                            minutes: 34,
                            seconds: 56,
                            frame: 7,
                            dropFrame: false,
                            reverse: false,
                            sampleStart: 13_440,
                            sampleEnd: 15_359,
                            volume: 0
                        ),
                        LTC.Frame(
                            hours: 12,
                            minutes: 34,
                            seconds: 56,
                            frame: 8,
                            dropFrame: false,
                            reverse: false,
                            sampleStart: 15_360,
                            sampleEnd: 17_279,
                            volume: 0
                        ),
                    ]
                )

                let anchor = try decode.anchor()

                try Expect.equal(
                    anchor.timecode.hours,
                    12,
                    "media-ltc.anchor.hours"
                )

                try Expect.equal(
                    anchor.timecode.minutes,
                    34,
                    "media-ltc.anchor.minutes"
                )

                try Expect.equal(
                    anchor.timecode.seconds,
                    56,
                    "media-ltc.anchor.seconds"
                )

                try Expect.equal(
                    anchor.timecode.frame,
                    0,
                    "media-ltc.anchor.frame"
                )

                try Expect.equal(
                    anchor.framesUsed,
                    4,
                    "media-ltc.anchor.frames-used"
                )

                try Expect.equal(
                    anchor.timecode.string,
                    "12:34:56:00",
                    "media-ltc.anchor.string"
                )
            }

            Step("frame-rate detector distinguishes 29.97 from 30") {
                let sampleRate = 48_000
                let rate = LTC.FrameRate.fps29_97
                let samplesPerFrame = Double(
                    sampleRate
                ) / rate.framesPerSecond

                var frames: [LTC.Frame] = []

                for index in 0..<120 {
                    let start = Int64(
                        (
                            Double(
                                index
                            ) * samplesPerFrame
                        ).rounded()
                    )

                    let end = Int64(
                        (
                            Double(
                                index + 1
                            ) * samplesPerFrame
                        ).rounded()
                    ) - 1

                    frames.append(
                        LTC.Frame(
                            hours: 0,
                            minutes: 0,
                            seconds: index / 30,
                            frame: index % 30,
                            dropFrame: false,
                            reverse: false,
                            sampleStart: start,
                            sampleEnd: end,
                            volume: 0
                        )
                    )
                }

                let decode = LTC.AssetDecode(
                    url: URL(
                        fileURLWithPath: "/tmp/media-ltc-rate-fixture.wav"
                    ),
                    trackID: 3,
                    channel: 0,
                    sampleRate: sampleRate,
                    fps: 25,
                    frames: frames
                )

                let detection = try LTC.FrameRateDetector().detect(
                    decode
                )

                try Expect.equal(
                    detection.format.frameRate,
                    .fps29_97,
                    "media-ltc.rate.detect-29.97"
                )

                try Expect.equal(
                    detection.format.dropFrame,
                    false,
                    "media-ltc.rate.detect-ndf"
                )

                try Expect.equal(
                    detection.format.frameRate.nominalFrameRate,
                    30,
                    "media-ltc.rate.nominal-30"
                )

                let anchor = try decode.anchor(
                    frameRate: detection.format.frameRate
                )

                try Expect.equal(
                    anchor.nominalFrameRate,
                    30,
                    "media-ltc.rate.anchor-nominal"
                )

                try Expect.equal(
                    anchor.framesUsed,
                    120,
                    "media-ltc.rate.anchor-frames-used"
                )
            }

            Step("29.97 NDF maps to rational media timecode format") {
                let signal = LTC.SignalFormat(
                    frameRate: .fps29_97,
                    dropFrame: false
                )

                let format = signal.mediaTimecodeFormat

                try Expect.equal(
                    format.frameDuration.value,
                    1_001,
                    "media-ltc.timecode.frame-duration-value"
                )

                try Expect.equal(
                    format.frameDuration.timescale,
                    30_000,
                    "media-ltc.timecode.frame-duration-timescale"
                )

                try Expect.equal(
                    format.frameQuanta,
                    30,
                    "media-ltc.timecode.frame-quanta"
                )

                try Expect.equal(
                    format.dropFrame,
                    false,
                    "media-ltc.timecode.non-drop"
                )
            }

            Step("anchor exposes containing frame and phase") {
                let anchor = LTC.Anchor(
                    timecode: LTC.Timecode(
                        hours: 1,
                        minutes: 13,
                        seconds: 23,
                        frame: 12,
                        dropFrame: false
                    ),
                    fps: LTC.FrameRate.fps29_97.framesPerSecond,
                    nominalFrameRate: 30,
                    frameAtMediaStart: 132_102.48976023975,
                    roundedFrameAtMediaStart: 132_102,
                    framesUsed: 625,
                    maxResidualFrames: 0.0034965034865308553
                )

                try Expect.equal(
                    anchor.containingFrameAtMediaStart,
                    132_102,
                    "media-ltc.anchor.containing-frame"
                )

                try Expect.equal(
                    anchor.phaseWithinContainingFrame > 0.48
                        && anchor.phaseWithinContainingFrame < 0.50,
                    true,
                    "media-ltc.anchor.phase"
                )
            }

            Step("asset decoder finds LTC only on the selected channel") {
                let workspace = try MediaTestWorkspace(
                    "ltc-asset"
                )

                defer {
                    workspace.remove()
                }

                let fixture = workspace.file(
                    "ltc-stereo.wav"
                )

                let ltc = try makeLTCFloatSignal(
                    sampleRate: 48_000,
                    fps: 25,
                    hours: 12,
                    minutes: 34,
                    seconds: 56,
                    frame: 0,
                    frameCount: 6
                )

                let silence = Array(
                    repeating: Float(0),
                    count: ltc.count
                )

                try makePCM16WAV(
                    sampleRate: 48_000,
                    channels: [
                        silence,
                        ltc,
                    ]
                ).write(
                    to: fixture
                )

                let active = try await LTC.AssetDecoder().decode(
                    fixture,
                    channel: 1,
                    fps: 25
                )

                try Expect.equal(
                    active.channel,
                    1,
                    "media-ltc.asset.channel"
                )

                try Expect.equal(
                    active.sampleRate,
                    48_000,
                    "media-ltc.asset.sample-rate"
                )

                try Expect.notEmpty(
                    active.frames,
                    "media-ltc.asset.frames"
                )

                let target = try Expect.notNil(
                    active.frames.first {
                        $0.hours == 12
                            && $0.minutes == 34
                            && $0.seconds == 56
                    },
                    "media-ltc.asset.expected-time"
                )

                try Expect.equal(
                    target.frame,
                    0,
                    "media-ltc.asset.frame"
                )

                let silent = try await LTC.AssetDecoder().decode(
                    fixture,
                    channel: 0,
                    fps: 25
                )

                try Expect.equal(
                    silent.frames.count,
                    0,
                    "media-ltc.asset.silent-channel"
                )

                let signals = try await LTC.AssetSignalResolver().scan(
                    fixture
                )

                try Expect.equal(
                    signals.count,
                    1,
                    "media-ltc.asset-signal.count"
                )

                let signal = try await LTC.AssetSignalResolver().resolve(
                    fixture
                )

                try Expect.equal(
                    signal.channel,
                    1,
                    "media-ltc.asset-signal.channel"
                )

                try Expect.equal(
                    signal.detection.format.frameRate,
                    .fps25,
                    "media-ltc.asset-signal.rate"
                )
            }
        }
    }
}
