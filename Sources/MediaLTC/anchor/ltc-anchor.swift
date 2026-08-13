import Foundation

public extension LTC {
    struct Anchor:
        Sendable,
        Hashable,
        Codable
    {
        public let timecode: Timecode
        public let fps: Double
        public let nominalFrameRate: Int
        public let frameAtMediaStart: Double
        public let roundedFrameAtMediaStart: Int64
        public let framesUsed: Int
        public let maxResidualFrames: Double

        public init(
            timecode: Timecode,
            fps: Double,
            nominalFrameRate: Int,
            frameAtMediaStart: Double,
            roundedFrameAtMediaStart: Int64,
            framesUsed: Int,
            maxResidualFrames: Double
        ) {
            self.timecode = timecode
            self.fps = fps
            self.nominalFrameRate = nominalFrameRate
            self.frameAtMediaStart = frameAtMediaStart
            self.roundedFrameAtMediaStart = roundedFrameAtMediaStart
            self.framesUsed = framesUsed
            self.maxResidualFrames = maxResidualFrames
        }

        public var containingFrameAtMediaStart: Int64 {
            Int64(
                floor(
                    frameAtMediaStart
                )
            )
        }

        public var phaseWithinContainingFrame: Double {
            frameAtMediaStart
                - floor(
                    frameAtMediaStart
                )
        }

        public var fractionalFrameAtMediaStart: Double {
            frameAtMediaStart
                - Double(
                    roundedFrameAtMediaStart
                )
        }
    }
}
