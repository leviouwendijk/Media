import CoreMedia

public struct MediaTimecodeFormat: Sendable {
    public let frameDuration: CMTime
    public let frameQuanta: UInt32
    public let dropFrame: Bool
    public let wraps24Hours: Bool

    public init(
        frameDuration: CMTime,
        frameQuanta: UInt32,
        dropFrame: Bool = false,
        wraps24Hours: Bool = true
    ) {
        self.frameDuration = frameDuration
        self.frameQuanta = frameQuanta
        self.dropFrame = dropFrame
        self.wraps24Hours = wraps24Hours
    }

    public static func frameRate(
        numerator: Int,
        denominator: Int,
        frameQuanta: Int,
        dropFrame: Bool = false
    ) -> MediaTimecodeFormat {
        precondition(
            numerator > 0
        )

        precondition(
            denominator > 0
        )

        precondition(
            frameQuanta > 0
        )

        return MediaTimecodeFormat(
            frameDuration: CMTime(
                value: CMTimeValue(
                    denominator
                ),
                timescale: CMTimeScale(
                    numerator
                )
            ),
            frameQuanta: UInt32(
                clamping: frameQuanta
            ),
            dropFrame: dropFrame
        )
    }

    public static func fps(
        _ fps: Int,
        dropFrame: Bool = false
    ) -> MediaTimecodeFormat {
        MediaTimecodeFormat(
            frameDuration: CMTime(
                value: 1,
                timescale: CMTimeScale(
                    fps
                )
            ),
            frameQuanta: UInt32(
                clamping: fps
            ),
            dropFrame: dropFrame
        )
    }

    public func formatDescription() throws -> CMTimeCodeFormatDescription {
        guard frameQuanta > 0,
              frameDuration.isValid,
              frameDuration.isNumeric,
              CMTimeGetSeconds(
                  frameDuration
              ) > 0 else {
            throw MediaTimecodeError.invalid_format
        }

        var flags: UInt32 = 0

        if dropFrame {
            flags |= kCMTimeCodeFlag_DropFrame
        }

        if wraps24Hours {
            flags |= kCMTimeCodeFlag_24HourMax
        }

        var description: CMTimeCodeFormatDescription?

        let status = CMTimeCodeFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            timeCodeFormatType: kCMTimeCodeFormatType_TimeCode32,
            frameDuration: frameDuration,
            frameQuanta: frameQuanta,
            flags: flags,
            extensions: nil,
            formatDescriptionOut: &description
        )

        guard status == noErr,
              let description else {
            throw MediaTimecodeError.format_description_failed(
                status
            )
        }

        return description
    }
}
