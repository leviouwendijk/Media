import Foundation

public extension MediaAudioBuffer {
    var peakAmplitude: Float {
        var peak: Float = 0

        forEachMonoFloatSample { sample in
            peak = max(
                peak,
                abs(sample)
            )
        }

        return peak
    }

    var rmsAmplitude: Float {
        var sampleCount = 0
        var squareSum: Float = 0

        forEachMonoFloatSample { sample in
            sampleCount += 1
            squareSum += sample * sample
        }

        guard sampleCount > 0 else {
            return 0
        }

        return (
            squareSum
            / Float(
                sampleCount
            )
        ).squareRoot()
    }
}
