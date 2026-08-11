import Foundation

public struct MediaAudioBuffer: Sendable {
    public let data: Data
    public let frameCount: Int
    public let packetCount: UInt32
    public let sampleRate: Int
    public let channelCount: Int
    public let sample: Audio.Sample
    public let hostTimeSeconds: TimeInterval?

    public init(
        data: Data,
        frameCount: Int,
        packetCount: UInt32,
        sampleRate: Int,
        channelCount: Int,
        sample: Audio.Sample = .int16,
        hostTimeSeconds: TimeInterval?
    ) {
        self.data = data
        self.frameCount = frameCount
        self.packetCount = packetCount
        self.sampleRate = sampleRate
        self.channelCount = channelCount
        self.sample = sample
        self.hostTimeSeconds = hostTimeSeconds
    }

    public var isEmpty: Bool {
        data.isEmpty || frameCount <= 0
    }
}

public extension MediaAudioBuffer {
    func withInt16Samples<Result>(
        _ body: (UnsafeBufferPointer<Int16>) throws -> Result
    ) rethrows -> Result {
        precondition(
            sample == .int16,
            "withInt16Samples requires Audio.Sample.int16."
        )

        return try data.withUnsafeBytes { rawBuffer in
            let samples = rawBuffer.bindMemory(
                to: Int16.self
            )

            return try body(
                samples
            )
        }
    }

    func forEachMonoFloatSample(
        _ body: (Float) throws -> Void
    ) rethrows {
        guard channelCount > 0,
              frameCount > 0,
              !data.isEmpty else {
            return
        }

        try data.withUnsafeBytes { rawBuffer in
            guard let base = rawBuffer.bindMemory(
                to: UInt8.self
            ).baseAddress else {
                return
            }

            let resolvedFrameCount = min(
                frameCount,
                data.count / max(
                    1,
                    channelCount * sample.bytes
                )
            )

            guard resolvedFrameCount > 0 else {
                return
            }

            for frameIndex in 0..<resolvedFrameCount {
                var sum: Float = 0

                for channelIndex in 0..<channelCount {
                    let sampleIndex = frameIndex * channelCount + channelIndex
                    let offset = sampleIndex * sample.bytes

                    sum += Self.readFloat(
                        from: base,
                        offset: offset,
                        sample: sample
                    )
                }

                try body(
                    sum / Float(
                        channelCount
                    )
                )
            }
        }
    }

    func appendMonoFloatSamples(
        to output: inout [Float]
    ) {
        forEachMonoFloatSample { sample in
            output.append(
                sample
            )
        }
    }

    func monoFloatSamples() -> [Float] {
        var output: [Float] = []

        output.reserveCapacity(
            max(
                0,
                frameCount
            )
        )

        appendMonoFloatSamples(
            to: &output
        )

        return output
    }

    func mapFloatSamples(
        _ transform: (Float) throws -> Float
    ) rethrows -> MediaAudioBuffer {
        guard !data.isEmpty else {
            return self
        }

        let totalSamples = min(
            frameCount * channelCount,
            data.count / sample.bytes
        )

        guard totalSamples > 0 else {
            return self
        }

        var output = Array(
            repeating: UInt8(0),
            count: totalSamples * sample.bytes
        )

        try data.withUnsafeBytes { inputBytes in
            guard let input = inputBytes.bindMemory(
                to: UInt8.self
            ).baseAddress else {
                return
            }

            for sampleIndex in 0..<totalSamples {
                let offset = sampleIndex * sample.bytes
                let value = Self.readFloat(
                    from: input,
                    offset: offset,
                    sample: sample
                )
                let processed = try transform(
                    value
                )

                Self.writeFloat(
                    processed,
                    to: &output,
                    offset: offset,
                    sample: sample
                )
            }
        }

        return MediaAudioBuffer(
            data: Data(
                output
            ),
            frameCount: frameCount,
            packetCount: packetCount,
            sampleRate: sampleRate,
            channelCount: channelCount,
            sample: sample,
            hostTimeSeconds: hostTimeSeconds
        )
    }

    func mapFloatSamplesWithChannel(
        _ transform: (Float, Int) throws -> Float
    ) rethrows -> MediaAudioBuffer {
        guard !data.isEmpty else {
            return self
        }

        let totalSamples = min(
            frameCount * channelCount,
            data.count / sample.bytes
        )

        guard totalSamples > 0 else {
            return self
        }

        let resolvedChannelCount = max(
            1,
            channelCount
        )

        var output = Array(
            repeating: UInt8(0),
            count: totalSamples * sample.bytes
        )

        try data.withUnsafeBytes { inputBytes in
            guard let input = inputBytes.bindMemory(
                to: UInt8.self
            ).baseAddress else {
                return
            }

            for sampleIndex in 0..<totalSamples {
                let offset = sampleIndex * sample.bytes
                let channel = sampleIndex % resolvedChannelCount
                let value = Self.readFloat(
                    from: input,
                    offset: offset,
                    sample: sample
                )
                let processed = try transform(
                    value,
                    channel
                )

                Self.writeFloat(
                    processed,
                    to: &output,
                    offset: offset,
                    sample: sample
                )
            }
        }

        return MediaAudioBuffer(
            data: Data(
                output
            ),
            frameCount: frameCount,
            packetCount: packetCount,
            sampleRate: sampleRate,
            channelCount: channelCount,
            sample: sample,
            hostTimeSeconds: hostTimeSeconds
        )
    }
}

private extension MediaAudioBuffer {
    static func readFloat(
        from bytes: UnsafePointer<UInt8>,
        offset: Int,
        sample: Audio.Sample
    ) -> Float {
        switch sample {
        case .int16:
            let value = UInt16(bytes[offset])
                | UInt16(bytes[offset + 1]) << 8

            return Float(
                Int16(
                    bitPattern: value
                )
            ) / 32768.0

        case .int24:
            var value = Int32(bytes[offset])
                | Int32(bytes[offset + 1]) << 8
                | Int32(bytes[offset + 2]) << 16

            if value & 0x0080_0000 != 0 {
                value |= -0x0100_0000
            }

            return Float(
                value
            ) / 8_388_608.0

        case .int32:
            let value = UInt32(bytes[offset])
                | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16
                | UInt32(bytes[offset + 3]) << 24

            return Float(
                Int32(
                    bitPattern: value
                )
            ) / 2_147_483_648.0

        case .float32:
            let value = UInt32(bytes[offset])
                | UInt32(bytes[offset + 1]) << 8
                | UInt32(bytes[offset + 2]) << 16
                | UInt32(bytes[offset + 3]) << 24

            return Float(
                bitPattern: value
            )
        }
    }

    static func writeFloat(
        _ value: Float,
        to bytes: inout [UInt8],
        offset: Int,
        sample: Audio.Sample
    ) {
        switch sample {
        case .int16:
            let raw = Int16(
                clamping: Int(
                    (clamp(value) * 32767.0).rounded()
                )
            )
            let bits = UInt16(
                bitPattern: raw
            )

            bytes[offset] = UInt8(
                bits & 0x00ff
            )
            bytes[offset + 1] = UInt8(
                (bits >> 8) & 0x00ff
            )

        case .int24:
            let scaled = Int32(
                max(
                    -8_388_608,
                    min(
                        8_388_607,
                        Int(
                            (clamp(value) * 8_388_607.0).rounded()
                        )
                    )
                )
            )
            let bits = UInt32(
                bitPattern: scaled
            )

            bytes[offset] = UInt8(
                bits & 0x000000ff
            )
            bytes[offset + 1] = UInt8(
                (bits >> 8) & 0x000000ff
            )
            bytes[offset + 2] = UInt8(
                (bits >> 16) & 0x000000ff
            )

        case .int32:
            let scaled = Int64(
                max(
                    -2_147_483_648,
                    min(
                        2_147_483_647,
                        Int64(
                            (Double(clamp(value)) * 2_147_483_647.0).rounded()
                        )
                    )
                )
            )
            let bits = UInt32(
                bitPattern: Int32(
                    scaled
                )
            )

            bytes[offset] = UInt8(
                bits & 0x000000ff
            )
            bytes[offset + 1] = UInt8(
                (bits >> 8) & 0x000000ff
            )
            bytes[offset + 2] = UInt8(
                (bits >> 16) & 0x000000ff
            )
            bytes[offset + 3] = UInt8(
                (bits >> 24) & 0x000000ff
            )

        case .float32:
            let bits = value.bitPattern

            bytes[offset] = UInt8(
                bits & 0x000000ff
            )
            bytes[offset + 1] = UInt8(
                (bits >> 8) & 0x000000ff
            )
            bytes[offset + 2] = UInt8(
                (bits >> 16) & 0x000000ff
            )
            bytes[offset + 3] = UInt8(
                (bits >> 24) & 0x000000ff
            )
        }
    }

    static func clamp(
        _ value: Float
    ) -> Float {
        max(
            -1,
            min(
                1,
                value
            )
        )
    }
}
