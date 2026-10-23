import Foundation

public enum MediaAudioChannelSelectionError: Error, Sendable, Equatable {
    case invalidChannel
    case invalidBuffer
}

public extension MediaAudioBuffer {
    /// Extract a single interleaved channel without mixing or changing its sample encoding.
    /// This is a PCM operation; container and codec policy belong to higher layers.
    func selectingChannel(_ channel: Int) throws -> MediaAudioBuffer {
        guard channelCount > 0, channel >= 0, channel < channelCount else {
            throw MediaAudioChannelSelectionError.invalidChannel
        }
        let bytes_per_sample = sample.bytes
        guard frameCount >= 0, bytes_per_sample > 0 else {
            throw MediaAudioChannelSelectionError.invalidBuffer
        }
        let (stride, stride_overflow) = channelCount.multipliedReportingOverflow(by: bytes_per_sample)
        let (input_size, input_overflow) = frameCount.multipliedReportingOverflow(by: stride)
        let (output_size, output_overflow) = frameCount.multipliedReportingOverflow(by: bytes_per_sample)
        guard !stride_overflow, !input_overflow, !output_overflow,
              data.count >= input_size else {
            throw MediaAudioChannelSelectionError.invalidBuffer
        }

        var output = Data(count: output_size)
        output.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) in
            data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                for frame in 0..<frameCount {
                    let source_offset = frame * stride + channel * bytes_per_sample
                    let destination_offset = frame * bytes_per_sample
                    for byte in 0..<bytes_per_sample {
                        destination[destination_offset + byte] = source[source_offset + byte]
                    }
                }
            }
        }
        return MediaAudioBuffer(
            data: output,
            frameCount: frameCount,
            packetCount: packetCount,
            sampleRate: sampleRate,
            channelCount: 1,
            sample: sample,
            hostTimeSeconds: hostTimeSeconds
        )
    }
}
