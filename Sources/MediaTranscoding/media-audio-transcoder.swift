import Foundation
import MediaCore
import MediaAV

public protocol MediaAudioEncodingSink: Sendable {
    func append(_ buffer: MediaAudioBuffer) throws
    func finish() throws
}

public protocol MediaAudioEncoder: Sendable {
    var name: String { get }
    var fileExtension: String { get }
    func makeSink(at url: URL, sampleRate: Int, channelCount: Int) throws -> any MediaAudioEncodingSink
}

public enum MediaAudioTranscodeError: Error, Sendable {
    case invalidSource
    case invalidDestination
    case destinationExists
    case emptySource
    case unsupportedBuffer
    case inconsistentFormat
    case verificationFailed
    case backendFailure(Int32)
}

public struct MediaAudioTranscodeResult: Sendable, Codable {
    public let source: URL
    public let output: URL
    public let encoder: String
    public let sourceFrames: Int64
    public let decodedFrames: Int64
    public let sampleRate: Int
    public let channelCount: Int
    public let outputBytes: Int64
}

public struct MediaAudioTranscoder: Sendable {
    public init() {}

    public func transcode(
        _ source: URL,
        to destination: URL,
        using encoder: any MediaAudioEncoder,
        channelIndex: Int? = nil
    ) async throws -> MediaAudioTranscodeResult {
        let source = source.standardizedFileURL
        let destination = destination.standardizedFileURL
        let files = FileManager.default

        guard source.isFileURL, files.fileExists(atPath: source.path) else {
            throw MediaAudioTranscodeError.invalidSource
        }
        guard destination.isFileURL, source != destination,
              destination.pathExtension.lowercased() == encoder.fileExtension.lowercased() else {
            throw MediaAudioTranscodeError.invalidDestination
        }
        guard !files.fileExists(atPath: destination.path) else {
            throw MediaAudioTranscodeError.destinationExists
        }

        let temporary = destination.deletingLastPathComponent()
            .appendingPathComponent(".\(UUID().uuidString).\(encoder.fileExtension)")
        defer { try? files.removeItem(at: temporary) }

        let collector = MediaAudioEncodeCollector(encoder: encoder, output: temporary)
        try await MediaAssetAudioReader().read(source) { chunk in
            if let channelIndex {
                try collector.consume(try chunk.buffer.selectingChannel(channelIndex))
            } else {
                try collector.consume(chunk.buffer)
            }
        }
        let sourceInfo = try collector.finish()

        let verification = MediaAudioVerifyCollector()
        try await MediaAssetAudioReader().read(temporary) { chunk in
            try verification.consume(chunk.buffer)
        }
        let decoded = verification.snapshot()
        let tolerance = max(1, Int64(Double(sourceInfo.rate) * 0.25))
        guard decoded.frames > 0,
              decoded.channels == sourceInfo.channels,
              decoded.rate == sourceInfo.rate,
              abs(decoded.frames - sourceInfo.frames) <= tolerance else {
            throw MediaAudioTranscodeError.verificationFailed
        }
        let attrs = try files.attributesOfItem(atPath: temporary.path)
        let outputBytes = (attrs[.size] as? NSNumber)?.int64Value ?? 0
        guard outputBytes > 0 else {
            throw MediaAudioTranscodeError.verificationFailed
        }
        guard !files.fileExists(atPath: destination.path) else {
            throw MediaAudioTranscodeError.destinationExists
        }
        try files.moveItem(at: temporary, to: destination)
        return MediaAudioTranscodeResult(
            source: source,
            output: destination,
            encoder: encoder.name,
            sourceFrames: sourceInfo.frames,
            decodedFrames: decoded.frames,
            sampleRate: sourceInfo.rate,
            channelCount: sourceInfo.channels,
            outputBytes: outputBytes
        )
    }
}

private struct MediaAudioFrameSummary {
    let frames: Int64
    let rate: Int
    let channels: Int
    let rms: Double
}

private final class MediaAudioEncodeCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let encoder: any MediaAudioEncoder
    private let output: URL
    private var sink: (any MediaAudioEncodingSink)?
    private var frames: Int64 = 0
    private var rate = 0
    private var channels = 0
    private var sumOfSquares: Double = 0

    init(encoder: any MediaAudioEncoder, output: URL) {
        self.encoder = encoder
        self.output = output
    }

    func consume(_ buffer: MediaAudioBuffer) throws {
        lock.lock()
        defer { lock.unlock() }
        guard buffer.sample == .float32, buffer.frameCount > 0,
              buffer.sampleRate > 0, (1...2).contains(buffer.channelCount),
              buffer.frameCount <= Int.max / (buffer.channelCount * 4),
              buffer.data.count >= buffer.frameCount * buffer.channelCount * 4 else {
            throw MediaAudioTranscodeError.unsupportedBuffer
        }
        if sink == nil {
            rate = buffer.sampleRate
            channels = buffer.channelCount
            sink = try encoder.makeSink(at: output, sampleRate: rate, channelCount: channels)
        }
        guard rate == buffer.sampleRate, channels == buffer.channelCount else {
            throw MediaAudioTranscodeError.inconsistentFormat
        }
        guard let sink else {
            throw MediaAudioTranscodeError.emptySource
        }
        try sink.append(buffer)
        sumOfSquares += media_audio_mean_square(buffer) * Double(buffer.frameCount)
        frames += Int64(buffer.frameCount)
    }

    func finish() throws -> MediaAudioFrameSummary {
        lock.lock()
        defer { lock.unlock() }
        guard let sink, frames > 0 else {
            throw MediaAudioTranscodeError.emptySource
        }
        try sink.finish()
        return .init(frames: frames, rate: rate, channels: channels,
                     rms: (sumOfSquares / Double(frames)).squareRoot())
    }
}

private final class MediaAudioVerifyCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var frames: Int64 = 0
    private var rate = 0
    private var channels = 0
    private var sumOfSquares: Double = 0

    func consume(_ buffer: MediaAudioBuffer) throws {
        lock.lock()
        defer { lock.unlock() }
        if frames == 0 {
            rate = buffer.sampleRate
            channels = buffer.channelCount
        }
        guard rate == buffer.sampleRate, channels == buffer.channelCount,
              buffer.sample == .float32, buffer.frameCount > 0,
              buffer.channelCount > 0,
              buffer.frameCount <= Int.max / (buffer.channelCount * 4),
              buffer.data.count >= buffer.frameCount * buffer.channelCount * 4 else {
            throw MediaAudioTranscodeError.verificationFailed
        }
        sumOfSquares += media_audio_mean_square(buffer) * Double(buffer.frameCount)
        frames += Int64(buffer.frameCount)
    }

    func snapshot() -> MediaAudioFrameSummary {
        lock.lock()
        defer { lock.unlock() }
        return .init(frames: frames, rate: rate, channels: channels,
                     rms: frames > 0 ? (sumOfSquares / Double(frames)).squareRoot() : 0)
    }
}

// Measure every PCM channel independently: an anti-phase stereo recording
// must not appear silent merely because its mono downmix cancels out.
private func media_audio_mean_square(_ buffer: MediaAudioBuffer) -> Double {
    let count = buffer.frameCount * buffer.channelCount
    guard count > 0 else { return 0 }
    let total = buffer.data.withUnsafeBytes { bytes -> Double in
        var sum: Double = 0
        for index in 0..<count {
            let value = Double(bytes.loadUnaligned(
                fromByteOffset: index * MemoryLayout<Float>.size,
                as: Float.self
            ))
            sum += value * value
        }
        return sum
    }
    return total / Double(count)
}
