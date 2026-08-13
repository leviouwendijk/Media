import Foundation

public extension LTC {
    struct AnchorResolver: Sendable {
        public let minimumFrames: Int
        public let maximumResidualFrames: Double

        public init(
            minimumFrames: Int = 3,
            maximumResidualFrames: Double = 0.25
        ) {
            self.minimumFrames = minimumFrames
            self.maximumResidualFrames = maximumResidualFrames
        }

        public func resolve(
            _ decode: AssetDecode,
            frameRate: LTC.FrameRate? = nil
        ) throws -> Anchor {
            guard minimumFrames >= 2,
                  maximumResidualFrames >= 0,
                  maximumResidualFrames.isFinite else {
                throw AnchorError.invalidConfiguration
            }

            let fps = frameRate?.framesPerSecond
                ?? decode.fps

            guard fps > 0,
                  fps.isFinite else {
                throw AnchorError.invalidFrameRate(
                    fps
                )
            }

            let nominalFrameRate = frameRate?.nominalFrameRate
                ?? Int(
                    fps.rounded()
                )

            guard nominalFrameRate > 0 else {
                throw AnchorError.invalidFrameRate(
                    decode.fps
                )
            }

            let available = decode.frames.filter {
                !$0.reverse
            }

            guard !available.isEmpty else {
                throw AnchorError.noFrames
            }

            guard !available.contains(where: {
                $0.dropFrame
            }) else {
                throw AnchorError.unsupportedDropFrame
            }

            let ordered = available.sorted {
                if $0.sampleStart == $1.sampleStart {
                    return $0.sampleEnd < $1.sampleEnd
                }

                return $0.sampleStart < $1.sampleStart
            }

            let run = try longestRun(
                ordered,
                nominalFrameRate: nominalFrameRate
            )

            guard run.count >= minimumFrames else {
                throw AnchorError.insufficientConsecutiveFrames(
                    required: minimumFrames,
                    actual: run.count
                )
            }

            let firstFrameNumber = try dayFrameNumber(
                run[0],
                nominalFrameRate: nominalFrameRate
            )

            var estimates: [Double] = []

            estimates.reserveCapacity(
                run.count
            )

            for index in run.indices {
                let timecodeFrame = firstFrameNumber
                    + Int64(
                        index
                    )

                let mediaFrames = Double(
                    run[index].sampleStart
                )
                    * fps
                    / Double(
                        decode.sampleRate
                    )

                estimates.append(
                    Double(
                        timecodeFrame
                    ) - mediaFrames
                )
            }

            let frameAtMediaStart = median(
                estimates
            )

            let maxResidualFrames = estimates
                .map {
                    abs(
                        $0 - frameAtMediaStart
                    )
                }
                .max()
                ?? 0

            guard maxResidualFrames <= maximumResidualFrames else {
                throw AnchorError.unstable(
                    residual: maxResidualFrames,
                    limit: maximumResidualFrames
                )
            }

            let roundedFrameAtMediaStart = Int64(
                frameAtMediaStart.rounded()
            )

            let timecode = timecode(
                frameNumber: roundedFrameAtMediaStart,
                nominalFrameRate: nominalFrameRate
            )

            return Anchor(
                timecode: timecode,
                fps: fps,
                nominalFrameRate: nominalFrameRate,
                frameAtMediaStart: frameAtMediaStart,
                roundedFrameAtMediaStart: roundedFrameAtMediaStart,
                framesUsed: run.count,
                maxResidualFrames: maxResidualFrames
            )
        }
    }
}

public extension LTC.AssetDecode {
    func anchor(
        minimumFrames: Int = 3,
        maximumResidualFrames: Double = 0.25
    ) throws -> LTC.Anchor {
        try LTC.AnchorResolver(
            minimumFrames: minimumFrames,
            maximumResidualFrames: maximumResidualFrames
        ).resolve(
            self
        )
    }

    func anchor(
        frameRate: LTC.FrameRate,
        minimumFrames: Int = 3,
        maximumResidualFrames: Double = 0.25
    ) throws -> LTC.Anchor {
        try LTC.AnchorResolver(
            minimumFrames: minimumFrames,
            maximumResidualFrames: maximumResidualFrames
        ).resolve(
            self,
            frameRate: frameRate
        )
    }
}

private extension LTC.AnchorResolver {
    func longestRun(
        _ frames: [LTC.Frame],
        nominalFrameRate: Int
    ) throws -> [LTC.Frame] {
        var best: [LTC.Frame] = []
        var current: [LTC.Frame] = []

        for frame in frames {
            _ = try dayFrameNumber(
                frame,
                nominalFrameRate: nominalFrameRate
            )

            guard let previous = current.last else {
                current = [
                    frame,
                ]

                if current.count > best.count {
                    best = current
                }

                continue
            }

            let previousNumber = try dayFrameNumber(
                previous,
                nominalFrameRate: nominalFrameRate
            )

            let currentNumber = try dayFrameNumber(
                frame,
                nominalFrameRate: nominalFrameRate
            )

            let framesPerDay = Int64(
                nominalFrameRate
                    * 60
                    * 60
                    * 24
            )

            let expected = (
                previousNumber + 1
            ) % framesPerDay

            if currentNumber == expected,
               frame.sampleStart > previous.sampleStart {
                current.append(
                    frame
                )
            } else {
                current = [
                    frame,
                ]
            }

            if current.count > best.count {
                best = current
            }
        }

        return best
    }

    func dayFrameNumber(
        _ frame: LTC.Frame,
        nominalFrameRate: Int
    ) throws -> Int64 {
        guard frame.hours >= 0,
              frame.hours < 24,
              frame.minutes >= 0,
              frame.minutes < 60,
              frame.seconds >= 0,
              frame.seconds < 60,
              frame.frame >= 0,
              frame.frame < nominalFrameRate else {
            throw LTC.AnchorError.invalidTimecode
        }

        return Int64(
            (
                (
                    frame.hours
                        * 60
                        + frame.minutes
                )
                    * 60
                    + frame.seconds
            )
                * nominalFrameRate
                + frame.frame
        )
    }

    func timecode(
        frameNumber: Int64,
        nominalFrameRate: Int
    ) -> LTC.Timecode {
        let framesPerDay = Int64(
            nominalFrameRate
                * 60
                * 60
                * 24
        )

        let normalized = (
            (
                frameNumber % framesPerDay
            ) + framesPerDay
        ) % framesPerDay

        let totalSeconds = normalized
            / Int64(
                nominalFrameRate
            )

        let frame = Int(
            normalized
                % Int64(
                    nominalFrameRate
                )
        )

        let seconds = Int(
            totalSeconds % 60
        )

        let totalMinutes = totalSeconds / 60

        let minutes = Int(
            totalMinutes % 60
        )

        let hours = Int(
            (
                totalMinutes / 60
            ) % 24
        )

        return LTC.Timecode(
            hours: hours,
            minutes: minutes,
            seconds: seconds,
            frame: frame,
            dropFrame: false
        )
    }

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
