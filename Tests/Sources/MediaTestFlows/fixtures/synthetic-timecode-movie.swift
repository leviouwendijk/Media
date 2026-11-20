import AVFoundation
import AudioToolbox
import CoreMedia
import CoreVideo
import Darwin
import Foundation
import Media

enum SyntheticTimecodeMovieError:
    Error,
    LocalizedError
{
    case track_association
    case pixel_buffer(
        CVReturn
    )
    case pixel_buffer_memory
    case audio_format_description(
        OSStatus
    )
    case audio_block_buffer(
        OSStatus
    )
    case audio_block_buffer_write(
        OSStatus
    )
    case audio_sample_buffer(
        OSStatus
    )
    case writer_failed(
        String
    )

    var errorDescription: String? {
        switch self {
        case .track_association:
            return "Could not associate synthetic video and timecode tracks."

        case .pixel_buffer(let status):
            return "Could not create synthetic video pixel buffer: \(status)."

        case .pixel_buffer_memory:
            return "Synthetic video pixel buffer had no writable memory."

        case .audio_format_description(let status):
            return "Could not create synthetic PCM audio format description: \(status)."

        case .audio_block_buffer(let status):
            return "Could not create synthetic PCM audio block buffer: \(status)."

        case .audio_block_buffer_write(let status):
            return "Could not write synthetic PCM audio data: \(status)."

        case .audio_sample_buffer(let status):
            return "Could not create synthetic PCM audio sample buffer: \(status)."

        case .writer_failed(let message):
            return "Synthetic movie writer failed: \(message)"
        }
    }
}

func makeSyntheticTimecodeMovie(
    at url: URL
) async throws {
    let writer = try AVAssetWriter(
        url: url,
        fileType: .mov
    )

    let videoInput = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64,
        ]
    )

    let mediaTimeScale: CMTimeScale = 25_000

    videoInput.mediaTimeScale = mediaTimeScale

    let audioInput = AVAssetWriterInput(
        mediaType: .audio,
        outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128_000,
        ]
    )

    let timecodeFormat = MediaTimecodeFormat.fps(
        25
    )

    let description = try timecodeFormat.formatDescription()

    let timecodeInput = AVAssetWriterInput(
        mediaType: .timecode,
        outputSettings: nil,
        sourceFormatHint: description
    )

    timecodeInput.mediaTimeScale = mediaTimeScale

    let videoReceiver = writer.inputPixelBufferReceiver(
        for: videoInput,
        pixelBufferAttributes: nil
    )

    let audioReceiver = writer.inputReceiver(
        for: audioInput
    )

    let association = AVAssetTrack.AssociationType.timecode.rawValue

    guard videoInput.canAddTrackAssociation(
        withTrackOf: timecodeInput,
        type: association
    ) else {
        throw SyntheticTimecodeMovieError.track_association
    }

    videoInput.addTrackAssociation(
        withTrackOf: timecodeInput,
        type: association
    )

    let timecodeReceiver = writer.inputReceiver(
        for: timecodeInput
    )

    try writer.start()

    writer.startSession(
        atSourceTime: .zero
    )

    let audioSample = try makeSilentAudioSample(
        frameCount: 4_800,
        sampleRate: 48_000,
        channelCount: 2
    )

    try await audioReceiver.append(
        audioSample
    )

    audioReceiver.finish()

    for frame in 0..<3 {
        let pixelBuffer = try makeBlackPixelBuffer(
            width: 64,
            height: 64
        )

        try await videoReceiver.append(
            pixelBuffer,
            with: CMTime(
                value: CMTimeValue(
                    frame * 1_000
                ),
                timescale: mediaTimeScale
            )
        )
    }

    videoReceiver.finish()

    let sample = try MediaTimecodeSampleFactory(
        format: timecodeFormat
    ).sample(
        frameNumber: 1_132_400,
        presentationTime: .zero,
        duration: CMTime(
            value: 3,
            timescale: 25
        ),
        formatDescription: description
    )

    try await timecodeReceiver.append(
        sample
    )

    timecodeReceiver.finish()

    await writer.finishWriting()

    guard writer.status == .completed else {
        throw SyntheticTimecodeMovieError.writer_failed(
            writer.error?.localizedDescription
                ?? "Unknown AVAssetWriter failure."
        )
    }
}

private func makeSilentAudioSample(
    frameCount: Int,
    sampleRate: Int32,
    channelCount: UInt32
) throws -> CMReadySampleBuffer<CMSampleBuffer.DynamicContent> {
    let bytesPerSample = MemoryLayout<Int16>.size
    let bytesPerFrame = bytesPerSample
        * Int(
            channelCount
        )

    var stream = AudioStreamBasicDescription()

    stream.mSampleRate = Float64(
        sampleRate
    )

    stream.mFormatID = kAudioFormatLinearPCM

    stream.mFormatFlags =
        kAudioFormatFlagIsSignedInteger
        | kAudioFormatFlagIsPacked

    stream.mBytesPerPacket = UInt32(
        bytesPerFrame
    )

    stream.mFramesPerPacket = 1

    stream.mBytesPerFrame = UInt32(
        bytesPerFrame
    )

    stream.mChannelsPerFrame = channelCount

    stream.mBitsPerChannel = UInt32(
        bytesPerSample * 8
    )

    var formatDescription: CMAudioFormatDescription?

    var status = CMAudioFormatDescriptionCreate(
        allocator: kCFAllocatorDefault,
        asbd: &stream,
        layoutSize: 0,
        layout: nil,
        magicCookieSize: 0,
        magicCookie: nil,
        extensions: nil,
        formatDescriptionOut: &formatDescription
    )

    guard status == noErr,
          let formatDescription else {
        throw SyntheticTimecodeMovieError.audio_format_description(
            status
        )
    }

    let byteCount = frameCount
        * bytesPerFrame

    var blockBuffer: CMBlockBuffer?

    status = CMBlockBufferCreateWithMemoryBlock(
        allocator: kCFAllocatorDefault,
        memoryBlock: nil,
        blockLength: byteCount,
        blockAllocator: kCFAllocatorDefault,
        customBlockSource: nil,
        offsetToData: 0,
        dataLength: byteCount,
        flags: kCMBlockBufferAssureMemoryNowFlag,
        blockBufferOut: &blockBuffer
    )

    guard status == kCMBlockBufferNoErr,
          let blockBuffer else {
        throw SyntheticTimecodeMovieError.audio_block_buffer(
            status
        )
    }

    let silence = Data(
        count: byteCount
    )

    status = silence.withUnsafeBytes { bytes in
        guard let baseAddress = bytes.baseAddress else {
            return noErr
        }

        return CMBlockBufferReplaceDataBytes(
            with: baseAddress,
            blockBuffer: blockBuffer,
            offsetIntoDestination: 0,
            dataLength: byteCount
        )
    }

    guard status == kCMBlockBufferNoErr else {
        throw SyntheticTimecodeMovieError.audio_block_buffer_write(
            status
        )
    }

    var timing = CMSampleTimingInfo(
        duration: CMTime(
            value: 1,
            timescale: sampleRate
        ),
        presentationTimeStamp: .zero,
        decodeTimeStamp: .invalid
    )

    var sampleSize = bytesPerFrame

    var sampleBuffer: CMSampleBuffer?

    status = CMSampleBufferCreateReady(
        allocator: kCFAllocatorDefault,
        dataBuffer: blockBuffer,
        formatDescription: formatDescription,
        sampleCount: frameCount,
        sampleTimingEntryCount: 1,
        sampleTimingArray: &timing,
        sampleSizeEntryCount: 1,
        sampleSizeArray: &sampleSize,
        sampleBufferOut: &sampleBuffer
    )

    guard status == noErr,
          let sampleBuffer else {
        throw SyntheticTimecodeMovieError.audio_sample_buffer(
            status
        )
    }

    return CMReadySampleBuffer(
        unsafeBuffer: sampleBuffer
    )
}

private func makeBlackPixelBuffer(
    width: Int,
    height: Int
) throws -> CVReadOnlyPixelBuffer {
    var buffer: CVPixelBuffer?

    let status = CVPixelBufferCreate(
        kCFAllocatorDefault,
        width,
        height,
        kCVPixelFormatType_32BGRA,
        nil,
        &buffer
    )

    guard status == kCVReturnSuccess,
          let buffer else {
        throw SyntheticTimecodeMovieError.pixel_buffer(
            status
        )
    }

    CVPixelBufferLockBaseAddress(
        buffer,
        []
    )

    do {
        defer {
            CVPixelBufferUnlockBaseAddress(
                buffer,
                []
            )
        }

        guard let baseAddress = CVPixelBufferGetBaseAddress(
            buffer
        ) else {
            throw SyntheticTimecodeMovieError.pixel_buffer_memory
        }

        memset(
            baseAddress,
            0,
            CVPixelBufferGetBytesPerRow(
                buffer
            ) * height
        )
    }

    return CVReadOnlyPixelBuffer(
        unsafeBuffer: buffer
    )
}
