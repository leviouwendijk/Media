import Foundation
import MediaLTCBridge

enum LTCTestSignalError: Error {
    case encoder_creation_failed
    case empty_encoder_buffer
    case encoding_failed
}

func makeLTCFloatSignal(
    sampleRate: Int = 48_000,
    fps: Double = 25,
    hours: Int = 12,
    minutes: Int = 34,
    seconds: Int = 56,
    frame: Int = 0,
    frameCount: Int = 4
) throws -> [Float] {
    guard let encoder = media_ltc_encoder_create(
        Int32(
            clamping: sampleRate
        ),
        fps
    ) else {
        throw LTCTestSignalError.encoder_creation_failed
    }

    defer {
        media_ltc_encoder_destroy(
            encoder
        )
    }

    media_ltc_encoder_set_time(
        encoder,
        Int32(
            clamping: hours
        ),
        Int32(
            clamping: minutes
        ),
        Int32(
            clamping: seconds
        ),
        Int32(
            clamping: frame
        )
    )

    let capacity = Int(
        media_ltc_encoder_max_samples(
            encoder
        )
    )

    guard capacity > 0 else {
        throw LTCTestSignalError.empty_encoder_buffer
    }

    var frameSamples = Array(
        repeating: Float(0),
        count: capacity
    )

    var output: [Float] = []

    output.reserveCapacity(
        capacity * frameCount
    )

    for _ in 0..<frameCount {
        let count = frameSamples.withUnsafeMutableBufferPointer { buffer in
            media_ltc_encoder_encode_frame(
                encoder,
                buffer.baseAddress,
                buffer.count
            )
        }

        guard count > 0 else {
            throw LTCTestSignalError.encoding_failed
        }

        output.append(
            contentsOf: frameSamples.prefix(
                Int(
                    count
                )
            )
        )
    }

    return output
}
