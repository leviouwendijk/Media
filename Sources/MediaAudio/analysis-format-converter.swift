import Foundation
import MediaCore

public extension Audio.Processing {
    struct AnalysisFormatConversionResult: Sendable {
        public let buffer: MediaAudioBuffer
        public let sourceOffsetSeconds: TimeInterval

        public init(
            buffer: MediaAudioBuffer,
            sourceOffsetSeconds: TimeInterval
        ) {
            self.buffer = buffer
            self.sourceOffsetSeconds = sourceOffsetSeconds
        }
    }

    struct AnalysisFormatConverter: Sendable {
        public let targetSampleRate: Int

        private var sourceSampleRate: Int?
        private var globalSourceOffset: Int64 = 0
        private var nextSourcePosition: Double = 0
        private var previousSample: Float?
        private var filterState = Array(
            repeating: 0.0,
            count: 4
        )

        public init(
            targetSampleRate: Int = 16_000
        ) {
            precondition(targetSampleRate > 0)
            self.targetSampleRate = targetSampleRate
        }

        public mutating func process(
            _ buffer: MediaAudioBuffer
        ) -> AnalysisFormatConversionResult {
            let actualRate = buffer.sampleRate

            guard actualRate > 0 else {
                return .init(
                    buffer: emptyBuffer(
                        hostTimeSeconds: buffer.hostTimeSeconds
                    ),
                    sourceOffsetSeconds: 0
                )
            }

            if sourceSampleRate != actualRate {
                reset(
                    sourceSampleRate: actualRate
                )
            }

            var samples = buffer.monoFloatSamples()

            guard !samples.isEmpty else {
                return .init(
                    buffer: emptyBuffer(
                        hostTimeSeconds: buffer.hostTimeSeconds
                    ),
                    sourceOffsetSeconds: 0
                )
            }

            if actualRate > targetSampleRate {
                samples = lowPass(
                    samples,
                    sourceSampleRate: actualRate
                )
            }

            let chunkStart = Double(
                globalSourceOffset
            )
            let chunkLast = chunkStart
                + Double(samples.count - 1)
            let step = Double(actualRate)
                / Double(targetSampleRate)

            var output: [Float] = []
            output.reserveCapacity(
                max(
                    1,
                    Int(
                        ceil(
                            Double(samples.count)
                                / step
                        )
                    )
                )
            )

            var firstOutputPosition: Double?

            while nextSourcePosition <= chunkLast + 1e-12 {
                let lowerIndex = Int64(
                    floor(nextSourcePosition)
                )
                let fraction = nextSourcePosition
                    - Double(lowerIndex)

                guard let lower = sample(
                    at: lowerIndex,
                    samples: samples,
                    chunkStart: globalSourceOffset
                ) else {
                    break
                }

                let value: Float

                if fraction <= 1e-12 {
                    value = lower
                } else {
                    let upperIndex = lowerIndex + 1

                    guard let upper = sample(
                        at: upperIndex,
                        samples: samples,
                        chunkStart: globalSourceOffset
                    ) else {
                        break
                    }

                    value = lower
                        + Float(fraction)
                            * (upper - lower)
                }

                if firstOutputPosition == nil {
                    firstOutputPosition = nextSourcePosition
                }

                output.append(
                    value
                )
                nextSourcePosition += step
            }

            previousSample = samples.last
            globalSourceOffset += Int64(
                samples.count
            )

            let data = output.withUnsafeBytes {
                Data($0)
            }

            let outputBuffer = MediaAudioBuffer(
                data: data,
                frameCount: output.count,
                packetCount: UInt32(
                    clamping: output.count
                ),
                sampleRate: targetSampleRate,
                channelCount: 1,
                sample: .float32,
                hostTimeSeconds: buffer.hostTimeSeconds
            )

            let sourceOffset = firstOutputPosition.map {
                ($0 - chunkStart)
                    / Double(actualRate)
            } ?? 0

            return .init(
                buffer: outputBuffer,
                sourceOffsetSeconds: sourceOffset
            )
        }
    }
}

private extension Audio.Processing.AnalysisFormatConverter {
    mutating func reset(
        sourceSampleRate: Int
    ) {
        self.sourceSampleRate = sourceSampleRate
        globalSourceOffset = 0
        nextSourcePosition = 0
        previousSample = nil
        filterState = Array(
            repeating: 0,
            count: 4
        )
    }

    mutating func lowPass(
        _ samples: [Float],
        sourceSampleRate: Int
    ) -> [Float] {
        let cutoff = min(
            Double(targetSampleRate) * 0.45,
            Double(sourceSampleRate) * 0.45
        )
        let alpha = 1
            - exp(
                -2
                    * Double.pi
                    * cutoff
                    / Double(sourceSampleRate)
            )

        var output = Array(
            repeating: Float(0),
            count: samples.count
        )

        for index in samples.indices {
            var value = Double(
                samples[index]
            )

            for pole in filterState.indices {
                filterState[pole] += alpha
                    * (value - filterState[pole])
                value = filterState[pole]
            }

            output[index] = Float(value)
        }

        return output
    }

    func sample(
        at globalIndex: Int64,
        samples: [Float],
        chunkStart: Int64
    ) -> Float? {
        if globalIndex == chunkStart - 1 {
            return previousSample
        }

        let local = globalIndex
            - chunkStart

        guard local >= 0,
              local < Int64(samples.count) else {
            return nil
        }

        return samples[
            Int(local)
        ]
    }

    func emptyBuffer(
        hostTimeSeconds: TimeInterval?
    ) -> MediaAudioBuffer {
        .init(
            data: Data(),
            frameCount: 0,
            packetCount: 0,
            sampleRate: targetSampleRate,
            channelCount: 1,
            sample: .float32,
            hostTimeSeconds: hostTimeSeconds
        )
    }
}
