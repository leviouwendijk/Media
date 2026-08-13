import MediaAV

public extension LTC.SignalFormat {
    var mediaTimecodeFormat: MediaTimecodeFormat {
        MediaTimecodeFormat.frameRate(
            numerator: frameRate.numerator,
            denominator: frameRate.denominator,
            frameQuanta: frameRate.nominalFrameRate,
            dropFrame: dropFrame
        )
    }
}
