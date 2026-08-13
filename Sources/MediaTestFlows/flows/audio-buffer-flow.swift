import Foundation
import Media
import TestFlows

extension MediaFlowSuite {
    static var audioBufferFlow: TestFlow {
        TestFlow(
            "audio-buffer",
            tags: [
                "core",
                "audio",
                "buffer",
            ]
        ) {
            Step("float32 stereo samples mix down to mono") {
                let buffer = MediaAudioBuffer(
                    data: floatData(
                        [
                            1.0,
                            -1.0,
                            0.5,
                            0.25,
                        ]
                    ),
                    frameCount: 2,
                    packetCount: 2,
                    sampleRate: 48_000,
                    channelCount: 2,
                    sample: .float32,
                    hostTimeSeconds: nil
                )

                try Expect.equal(
                    buffer.monoFloatSamples(),
                    [
                        0.0,
                        0.375,
                    ],
                    "audio-buffer.mono"
                )
            }

            Step("individual channels remain independently addressable") {
                let buffer = MediaAudioBuffer(
                    data: floatData(
                        [
                            1.0,
                            -1.0,
                            0.5,
                            0.25,
                            -0.5,
                            0.75,
                            -0.25,
                            0.125,
                        ]
                    ),
                    frameCount: 2,
                    packetCount: 2,
                    sampleRate: 48_000,
                    channelCount: 4,
                    sample: .float32,
                    hostTimeSeconds: nil
                )

                try Expect.equal(
                    try buffer.floatSamples(
                        channel: 0
                    ),
                    [
                        1.0,
                        -0.5,
                    ],
                    "audio-buffer.channel-0"
                )

                try Expect.equal(
                    try buffer.floatSamples(
                        channel: 1
                    ),
                    [
                        -1.0,
                        0.75,
                    ],
                    "audio-buffer.channel-1"
                )

                try Expect.equal(
                    try buffer.floatSamples(
                        channel: 2
                    ),
                    [
                        0.5,
                        -0.25,
                    ],
                    "audio-buffer.channel-2"
                )

                try Expect.equal(
                    try buffer.floatSamples(
                        channel: 3
                    ),
                    [
                        0.25,
                        0.125,
                    ],
                    "audio-buffer.channel-3"
                )
            }

            Step("float sample mapping preserves buffer shape") {
                let buffer = MediaAudioBuffer(
                    data: floatData(
                        [
                            1.0,
                            -1.0,
                            0.5,
                            0.25,
                        ]
                    ),
                    frameCount: 2,
                    packetCount: 2,
                    sampleRate: 48_000,
                    channelCount: 2,
                    sample: .float32,
                    hostTimeSeconds: 12.5
                )

                let mapped = buffer.mapFloatSamples {
                    $0 * 0.5
                }

                try Expect.equal(
                    mapped.frameCount,
                    2,
                    "audio-buffer.map.frame-count"
                )

                try Expect.equal(
                    mapped.channelCount,
                    2,
                    "audio-buffer.map.channel-count"
                )

                try Expect.equal(
                    mapped.sampleRate,
                    48_000,
                    "audio-buffer.map.sample-rate"
                )

                try Expect.equal(
                    mapped.hostTimeSeconds,
                    12.5,
                    "audio-buffer.map.host-time"
                )

                try Expect.equal(
                    mapped.monoFloatSamples(),
                    [
                        0.0,
                        0.1875,
                    ],
                    "audio-buffer.map.samples"
                )
            }
        }
    }
}

private func floatData(
    _ samples: [Float]
) -> Data {
    samples.withUnsafeBufferPointer { buffer in
        guard let baseAddress = buffer.baseAddress else {
            return Data()
        }

        return Data(
            bytes: baseAddress,
            count: buffer.count * MemoryLayout<Float>.size
        )
    }
}
