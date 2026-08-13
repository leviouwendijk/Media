public extension LTC {
    struct FrameRateDetection:
        Sendable,
        Hashable,
        Codable
    {
        public let format: SignalFormat
        public let measuredFramesPerSecond: Double
        public let medianSamplesPerFrame: Double
        public let frameCount: Int
        public let firstTimecode: Timecode
        public let lastTimecode: Timecode
        public let firstSampleStart: Int64
        public let firstSampleEnd: Int64
        public let lastSampleStart: Int64
        public let lastSampleEnd: Int64

        public init(
            format: SignalFormat,
            measuredFramesPerSecond: Double,
            medianSamplesPerFrame: Double,
            frameCount: Int,
            firstTimecode: Timecode,
            lastTimecode: Timecode,
            firstSampleStart: Int64,
            firstSampleEnd: Int64,
            lastSampleStart: Int64,
            lastSampleEnd: Int64
        ) {
            self.format = format
            self.measuredFramesPerSecond = measuredFramesPerSecond
            self.medianSamplesPerFrame = medianSamplesPerFrame
            self.frameCount = frameCount
            self.firstTimecode = firstTimecode
            self.lastTimecode = lastTimecode
            self.firstSampleStart = firstSampleStart
            self.firstSampleEnd = firstSampleEnd
            self.lastSampleStart = lastSampleStart
            self.lastSampleEnd = lastSampleEnd
        }

        public var firstFrameSampleCount: Int64 {
            firstSampleEnd
                - firstSampleStart
                + 1
        }

        public var lastFrameSampleCount: Int64 {
            lastSampleEnd
                - lastSampleStart
                + 1
        }
    }

    enum FrameRateDetectionError:
        Error,
        Sendable,
        Equatable
    {
        case invalidConfiguration
        case invalidSampleRate(
            Int
        )
        case insufficientFrames(
            required: Int,
            actual: Int
        )
        case inconsistentDropFrame
        case unsupportedRate(
            Double
        )
    }

    struct FrameRateDetector: Sendable {
        public let minimumFrames: Int
        public let maximumRelativeError: Double
        public let candidates: [FrameRate]

        public init(
            minimumFrames: Int = 3,
            maximumRelativeError: Double = 0.01,
            candidates: [FrameRate] = FrameRate.common
        ) {
            self.minimumFrames = minimumFrames
            self.maximumRelativeError = maximumRelativeError
            self.candidates = candidates
        }

        public func detect(
            _ decode: AssetDecode
        ) throws -> FrameRateDetection {
            guard minimumFrames >= 3,
                  maximumRelativeError >= 0,
                  maximumRelativeError.isFinite,
                  !candidates.isEmpty else {
                throw FrameRateDetectionError.invalidConfiguration
            }

            guard decode.sampleRate > 0 else {
                throw FrameRateDetectionError.invalidSampleRate(
                    decode.sampleRate
                )
            }

            let frames = decode.frames
                .filter {
                    !$0.reverse
                }
                .sorted {
                    if $0.sampleStart == $1.sampleStart {
                        return $0.sampleEnd < $1.sampleEnd
                    }

                    return $0.sampleStart < $1.sampleStart
                }

            guard frames.count >= minimumFrames else {
                throw FrameRateDetectionError.insufficientFrames(
                    required: minimumFrames,
                    actual: frames.count
                )
            }

            let dropFrameValues = Set(
                frames.map(
                    \.dropFrame
                )
            )

            guard dropFrameValues.count == 1,
                  let dropFrame = dropFrameValues.first else {
                throw FrameRateDetectionError.inconsistentDropFrame
            }

            var deltas: [Double] = []

            deltas.reserveCapacity(
                frames.count - 1
            )

            for index in 1..<frames.count {
                let delta = frames[index].sampleStart
                    - frames[index - 1].sampleStart

                guard delta > 0 else {
                    continue
                }

                deltas.append(
                    Double(
                        delta
                    )
                )
            }

            guard deltas.count >= minimumFrames - 1 else {
                throw FrameRateDetectionError.insufficientFrames(
                    required: minimumFrames,
                    actual: deltas.count + 1
                )
            }

            let medianSamplesPerFrame = median(
                deltas
            )

            let measuredFramesPerSecond = Double(
                decode.sampleRate
            ) / medianSamplesPerFrame

            let maximumFrame = frames
                .map(
                    \.frame
                )
                .max()
                ?? 0

            let compatibleCandidates = candidates.filter {
                $0.nominalFrameRate > maximumFrame
            }

            guard let nearest = compatibleCandidates.min(by: {
                abs(
                    $0.framesPerSecond
                        - measuredFramesPerSecond
                ) < abs(
                    $1.framesPerSecond
                        - measuredFramesPerSecond
                )
            }) else {
                throw FrameRateDetectionError.unsupportedRate(
                    measuredFramesPerSecond
                )
            }

            let relativeError = abs(
                nearest.framesPerSecond
                    - measuredFramesPerSecond
            ) / nearest.framesPerSecond

            guard relativeError <= maximumRelativeError else {
                throw FrameRateDetectionError.unsupportedRate(
                    measuredFramesPerSecond
                )
            }

            guard let first = frames.first,
                  let last = frames.last else {
                throw FrameRateDetectionError.insufficientFrames(
                    required: minimumFrames,
                    actual: 0
                )
            }

            return FrameRateDetection(
                format: SignalFormat(
                    frameRate: nearest,
                    dropFrame: dropFrame
                ),
                measuredFramesPerSecond: measuredFramesPerSecond,
                medianSamplesPerFrame: medianSamplesPerFrame,
                frameCount: frames.count,
                firstTimecode: first.timecode,
                lastTimecode: last.timecode,
                firstSampleStart: first.sampleStart,
                firstSampleEnd: first.sampleEnd,
                lastSampleStart: last.sampleStart,
                lastSampleEnd: last.sampleEnd
            )
        }
    }
}

private extension LTC.FrameRateDetector {
    func median(
        _ values: [Double]
    ) -> Double {
        let values = values.sorted()

        let middle = values.count / 2

        if values.count.isMultiple(
            of: 2
        ) {
            return (
                values[middle - 1]
                    + values[middle]
            ) / 2
        }

        return values[middle]
    }
}
