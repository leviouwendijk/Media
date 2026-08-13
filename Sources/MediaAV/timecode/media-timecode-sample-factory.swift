import CoreMedia

public struct MediaTimecodeSampleFactory: Sendable {
    public let format: MediaTimecodeFormat

    public init(
        format: MediaTimecodeFormat
    ) {
        self.format = format
    }

    public func sample(
        frameNumber: Int32,
        presentationTime: CMTime,
        duration: CMTime,
        formatDescription: CMTimeCodeFormatDescription? = nil
    ) throws -> CMReadySampleBuffer<CMSampleBuffer.DynamicContent> {
        let description = try formatDescription
            ?? format.formatDescription()

        var dataBuffer: CMBlockBuffer?

        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: MemoryLayout<Int32>.size,
            blockAllocator: kCFAllocatorDefault,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: MemoryLayout<Int32>.size,
            flags: kCMBlockBufferAssureMemoryNowFlag,
            blockBufferOut: &dataBuffer
        )

        guard status == kCMBlockBufferNoErr,
              let dataBuffer else {
            throw MediaTimecodeError.block_buffer_failed(
                status
            )
        }

        var bigEndianFrameNumber = frameNumber.bigEndian

        status = Swift.withUnsafeBytes(
            of: &bigEndianFrameNumber
        ) { bytes in
            guard let baseAddress = bytes.baseAddress else {
                return -1
            }

            return CMBlockBufferReplaceDataBytes(
                with: baseAddress,
                blockBuffer: dataBuffer,
                offsetIntoDestination: 0,
                dataLength: MemoryLayout<Int32>.size
            )
        }

        guard status == kCMBlockBufferNoErr else {
            throw MediaTimecodeError.block_buffer_write_failed(
                status
            )
        }

        var timing = CMSampleTimingInfo(
            duration: duration,
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var sampleSize = MemoryLayout<Int32>.size
        var sampleBuffer: CMSampleBuffer?

        status = CMSampleBufferCreateReady(
            allocator: kCFAllocatorDefault,
            dataBuffer: dataBuffer,
            formatDescription: description,
            sampleCount: 1,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timing,
            sampleSizeEntryCount: 1,
            sampleSizeArray: &sampleSize,
            sampleBufferOut: &sampleBuffer
        )

        guard status == noErr,
              let sampleBuffer else {
            throw MediaTimecodeError.sample_buffer_failed(
                status
            )
        }

        return CMReadySampleBuffer(
            unsafeBuffer: sampleBuffer
        )
    }
}
