import Foundation
import MediaCore
import MediaLTCBridge

public extension LTC {
    final class Decoder:
        @unchecked Sendable
    {
        public let sampleRate: Int
        public let fps: Double

        private let handle: UnsafeMutableRawPointer
        private let lock = NSLock()

        public init(
            sampleRate: Int,
            fps: Double,
            queueSize: Int = 32
        ) throws {
            guard sampleRate > 0,
                  fps > 0 else {
                throw DecoderError.invalid_configuration(
                    sampleRate: sampleRate,
                    fps: fps
                )
            }

            guard let handle = media_ltc_decoder_create(
                Int32(
                    clamping: sampleRate
                ),
                fps,
                Int32(
                    clamping: queueSize
                )
            ) else {
                throw DecoderError.creation_failed
            }

            self.sampleRate = sampleRate
            self.fps = fps
            self.handle = handle
        }

        deinit {
            media_ltc_decoder_destroy(
                handle
            )
        }

        public func append(
            _ buffer: MediaAudioBuffer,
            channel: Int,
            sampleOffset: Int64
        ) throws -> [Frame] {
            guard buffer.sampleRate == sampleRate else {
                throw DecoderError.sample_rate_mismatch(
                    expected: sampleRate,
                    actual: buffer.sampleRate
                )
            }

            return append(
                try buffer.floatSamples(
                    channel: channel
                ),
                sampleOffset: sampleOffset
            )
        }

        public func append(
            _ samples: [Float],
            sampleOffset: Int64
        ) -> [Frame] {
            lock.lock()

            defer {
                lock.unlock()
            }

            samples.withUnsafeBufferPointer { buffer in
                guard let baseAddress = buffer.baseAddress,
                      !buffer.isEmpty else {
                    return
                }

                media_ltc_decoder_write_float(
                    handle,
                    baseAddress,
                    buffer.count,
                    sampleOffset
                )
            }

            var frames: [Frame] = []

            while true {
                var decoded = MediaLTCDecodedFrame()

                guard media_ltc_decoder_read(
                    handle,
                    &decoded
                ) != 0 else {
                    break
                }

                frames.append(
                    Frame(
                        hours: Int(
                            decoded.hours
                        ),
                        minutes: Int(
                            decoded.minutes
                        ),
                        seconds: Int(
                            decoded.seconds
                        ),
                        frame: Int(
                            decoded.frame
                        ),
                        dropFrame: decoded.drop_frame != 0,
                        reverse: decoded.reverse != 0,
                        sampleStart: decoded.sample_start,
                        sampleEnd: decoded.sample_end,
                        volume: decoded.volume
                    )
                )
            }

            return frames
        }
    }
}
