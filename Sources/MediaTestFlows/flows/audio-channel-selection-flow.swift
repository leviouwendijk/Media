import Foundation
import Media
import TestFlows

extension MediaFlowSuite {
    static var audioChannelSelectionFlow: TestFlow {
        TestFlow("audio-channel-selection", tags: ["audio", "pcm", "channels"]) {
            Step("float32 stereo channels preserve independent samples and metadata") {
                let original_samples: [Float] = [0.25, 0.75, 0.5, 0.125]
                var original_bytes = Data()
                for sample in original_samples {
                    var bits = sample.bitPattern.littleEndian
                    Swift.withUnsafeBytes(of: &bits) { original_bytes.append(contentsOf: $0) }
                }
                let original = MediaAudioBuffer(
                    data: original_bytes,
                    frameCount: 2,
                    packetCount: 2,
                    sampleRate: 48_000,
                    channelCount: 2,
                    sample: .float32,
                    hostTimeSeconds: 2.5
                )
                let left = try original.selectingChannel(0)
                let right = try original.selectingChannel(1)
                try Expect.equal(try left.floatSamples(channel: 0), [Float(0.25), Float(0.5)], "channels.left.samples")
                try Expect.equal(try right.floatSamples(channel: 0), [Float(0.75), Float(0.125)], "channels.right.samples")
                try Expect.equal(left.channelCount, 1, "channels.left.mono")
                try Expect.equal(right.channelCount, 1, "channels.right.mono")
                try Expect.equal(right.frameCount, 2, "channels.right.frame-count")
                try Expect.equal(right.sampleRate, 48_000, "channels.right.sample-rate")
                try Expect.equal(right.hostTimeSeconds, 2.5, "channels.right.start-time")
                try Expect.equal(original.data, original_bytes, "channels.original-preserved")
                do {
                    _ = try original.selectingChannel(2)
                    try Expect.true(false, "channels.reject-out-of-bounds")
                } catch MediaAudioChannelSelectionError.invalidChannel {
                    try Expect.true(true, "channels.reject-out-of-bounds")
                }
            }
            Step("int24 sample bytes are extracted exactly without float conversion") {
                let original = MediaAudioBuffer(
                    data: Data([0x01,0x02,0x03,0xA1,0xA2,0xA3,0x04,0x05,0x06,0xB1,0xB2,0xB3]),
                    frameCount: 2,
                    packetCount: 2,
                    sampleRate: 44_100,
                    channelCount: 2,
                    sample: .int24,
                    hostTimeSeconds: nil
                )
                try Expect.equal(try original.selectingChannel(0).data, Data([0x01,0x02,0x03,0x04,0x05,0x06]), "channels.int24-left")
                try Expect.equal(try original.selectingChannel(1).data, Data([0xA1,0xA2,0xA3,0xB1,0xB2,0xB3]), "channels.int24-right")
            }
        }
    }
}
