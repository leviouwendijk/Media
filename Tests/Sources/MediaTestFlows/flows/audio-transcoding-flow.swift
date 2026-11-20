import Foundation
import Media
import TestFlows

extension MediaFlowSuite {
    static var audioTranscodingFlow: TestFlow {
        TestFlow("audio-transcoding", tags: ["audio", "transcoding"]) {
            Step("missing source is rejected before any encoding") {
                let workspace = try MediaTestWorkspace("transcoding-preflight")
                defer { workspace.remove() }
                let source = workspace.file("nonexistent.wav")
                let output = workspace.file("encoded.mp3")
                do {
                    _ = try await MediaAudioTranscoder().transcode(
                        source, to: output, using: MediaTestUnavailableEncoder()
                    )
                    throw MediaAudioTranscodeError.verificationFailed
                } catch MediaAudioTranscodeError.invalidSource {
                    try Expect.true(
                        !FileManager.default.fileExists(atPath: output.path),
                        "transcoding.preflight.no-output"
                    )
                }
            }
            Step("existing output is never overwritten") {
                let workspace = try MediaTestWorkspace("transcoding-collision")
                defer { workspace.remove() }
                let source = workspace.file("original.wav")
                let output = workspace.file("encoded.mp3")
                try makePCM16WAV().write(to: source)
                let protected = Data("unchanged".utf8)
                try protected.write(to: output)
                do {
                    _ = try await MediaAudioTranscoder().transcode(
                        source, to: output, using: MediaTestUnavailableEncoder()
                    )
                    throw MediaAudioTranscodeError.verificationFailed
                } catch MediaAudioTranscodeError.destinationExists {
                    try Expect.equal(
                        try Data(contentsOf: output), protected,
                        "transcoding.existing-output-preserved"
                    )
                }
            }
        }
    }
}

private struct MediaTestUnavailableEncoder: MediaAudioEncoder {
    var name: String { "test-unavailable" }
    var fileExtension: String { "mp3" }
    func makeSink(
        at url: URL, sampleRate: Int, channelCount: Int
    ) throws -> any MediaAudioEncodingSink {
        throw MediaAudioTranscodeError.unsupportedBuffer
    }
}
