import Foundation
import Media
import TestFlows

extension MediaFlowSuite {
    static var audioTimeFlow: TestFlow {
        TestFlow(
            "audio-time",
            tags: [
                "core",
                "audio",
                "time",
            ]
        ) {
            Step("audio time range derives end") {
                let range = Audio.TimeRange(
                    start: 12.5,
                    duration: 3.25
                )

                try Expect.equal(
                    range.end,
                    15.75,
                    "audio-time.range-end"
                )
            }

            Step("timed audio chunk exposes canonical time range") {
                let chunk = MediaAudioChunk(
                    trackID: 1,
                    buffer: MediaAudioBuffer(
                        data: Data(),
                        frameCount: 0,
                        packetCount: 0,
                        sampleRate: 48_000,
                        channelCount: 1,
                        sample: .float32,
                        hostTimeSeconds: nil
                    ),
                    presentationTimeSeconds: 4.0,
                    durationSeconds: 1.5
                )

                let range = try Expect.notNil(
                    chunk.timeRange,
                    "audio-time.chunk-range"
                )

                try Expect.equal(
                    range.start,
                    4.0,
                    "audio-time.chunk-start"
                )

                try Expect.equal(
                    range.duration,
                    1.5,
                    "audio-time.chunk-duration"
                )

                try Expect.equal(
                    range.end,
                    5.5,
                    "audio-time.chunk-end"
                )
            }
        }
    }
}
