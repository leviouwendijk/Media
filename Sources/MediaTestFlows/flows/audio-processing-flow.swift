import Foundation
import Media
import TestFlows

extension MediaFlowSuite {
    static var audioProcessingFlow: TestFlow {
        TestFlow(
            "audio-processing",
            tags: [
                "audio",
                "processing",
                "analysis",
            ]
        ) {
            Step("analysis enhancer raises quiet speech while preserving buffer shape") {
                let samples = sine(
                    frequency: 180,
                    amplitude: 0.02,
                    count: 16_000,
                    sampleRate: 16_000
                )
                let buffer = MediaAudioBuffer(
                    data: floatData(samples),
                    frameCount: samples.count,
                    packetCount: UInt32(samples.count),
                    sampleRate: 16_000,
                    channelCount: 1,
                    sample: .float32,
                    hostTimeSeconds: 3
                )
                var enhancer = Audio.Processing.AnalysisEnhancer()
                let result = enhancer.process(
                    buffer
                )

                try Expect.equal(
                    result.buffer.frameCount,
                    buffer.frameCount,
                    "audio-processing.frame-count"
                )
                try Expect.equal(
                    result.buffer.sampleRate,
                    buffer.sampleRate,
                    "audio-processing.sample-rate"
                )
                try Expect.equal(
                    result.buffer.hostTimeSeconds,
                    buffer.hostTimeSeconds,
                    "audio-processing.host-time"
                )
                try Expect.equal(
                    result.telemetry.outputRMSDB
                        > result.telemetry.inputRMSDB,
                    true,
                    "audio-processing.quiet-speech-raised"
                )
            }

            Step("analysis enhancer remains bounded for hot input") {
                let samples = sine(
                    frequency: 180,
                    amplitude: 0.95,
                    count: 16_000,
                    sampleRate: 16_000
                )
                let buffer = MediaAudioBuffer(
                    data: floatData(samples),
                    frameCount: samples.count,
                    packetCount: UInt32(samples.count),
                    sampleRate: 16_000,
                    channelCount: 1,
                    sample: .float32,
                    hostTimeSeconds: nil
                )
                var enhancer = Audio.Processing.AnalysisEnhancer()
                let result = enhancer.process(
                    buffer
                )

                try Expect.equal(
                    result.buffer.monoFloatSamples().allSatisfy {
                        abs($0) <= 1
                    },
                    true,
                    "audio-processing.bounded"
                )
            }
        }
    }
}

private func sine(
    frequency: Double,
    amplitude: Float,
    count: Int,
    sampleRate: Int
) -> [Float] {
    (0..<count).map { index in
        amplitude * Float(
            sin(
                2 * Double.pi * frequency
                    * Double(index)
                    / Double(sampleRate)
            )
        )
    }
}

private func floatData(
    _ samples: [Float]
) -> Data {
    samples.withUnsafeBytes {
        Data($0)
    }
}
