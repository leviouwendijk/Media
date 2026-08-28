import Foundation
import MediaCore

public extension Audio {
    enum Processing {}
}

public extension Audio.Processing {
    struct Telemetry:
        Sendable,
        Codable,
        Hashable
    {
        public let inputRMSDB: Double
        public let outputRMSDB: Double
        public let appliedGainDB: Double

        public init(
            inputRMSDB: Double,
            outputRMSDB: Double,
            appliedGainDB: Double
        ) {
            self.inputRMSDB = inputRMSDB
            self.outputRMSDB = outputRMSDB
            self.appliedGainDB = appliedGainDB
        }
    }

    struct Result: Sendable {
        public let buffer: MediaAudioBuffer
        public let telemetry: Telemetry

        public init(
            buffer: MediaAudioBuffer,
            telemetry: Telemetry
        ) {
            self.buffer = buffer
            self.telemetry = telemetry
        }
    }

    struct AnalysisEnhancer: Sendable {
        public struct Configuration:
            Sendable,
            Codable,
            Hashable
        {
            public let targetRMSDB: Double
            public let maximumBoostDB: Double
            public let maximumCutDB: Double
            public let compressorThresholdDB: Double
            public let compressorRatio: Double
            public let expanderThresholdDB: Double
            public let expanderRatio: Double
            public let maximumExpansionReductionDB: Double

            public init(
                targetRMSDB: Double = -24,
                maximumBoostDB: Double = 12,
                maximumCutDB: Double = 6,
                compressorThresholdDB: Double = -18,
                compressorRatio: Double = 2.5,
                expanderThresholdDB: Double = -52,
                expanderRatio: Double = 1.6,
                maximumExpansionReductionDB: Double = 12
            ) {
                precondition(compressorRatio >= 1)
                precondition(expanderRatio >= 1)
                precondition(maximumBoostDB >= 0)
                precondition(maximumCutDB >= 0)
                precondition(maximumExpansionReductionDB >= 0)

                self.targetRMSDB = targetRMSDB
                self.maximumBoostDB = maximumBoostDB
                self.maximumCutDB = maximumCutDB
                self.compressorThresholdDB = compressorThresholdDB
                self.compressorRatio = compressorRatio
                self.expanderThresholdDB = expanderThresholdDB
                self.expanderRatio = expanderRatio
                self.maximumExpansionReductionDB = maximumExpansionReductionDB
            }
        }

        public let configuration: Configuration
        private var smoothedGain: Double = 1

        public init(
            configuration: Configuration = .init()
        ) {
            self.configuration = configuration
        }

        public mutating func process(
            _ buffer: MediaAudioBuffer
        ) -> Result {
            let inputSamples = buffer.monoFloatSamples()
            let inputRMS = Self.rms(inputSamples)
            let inputRMSDB = Self.db(inputRMS)

            let desiredGainDB = min(
                configuration.maximumBoostDB,
                max(
                    -configuration.maximumCutDB,
                    configuration.targetRMSDB - inputRMSDB
                )
            )

            let desiredGain = Self.linear(desiredGainDB)
            smoothedGain += 0.25 * (
                desiredGain - smoothedGain
            )

            let compressorThreshold = Self.linear(
                configuration.compressorThresholdDB
            )
            let expanderThreshold = Self.linear(
                configuration.expanderThresholdDB
            )
            let minimumExpanderGain = Self.linear(
                -configuration.maximumExpansionReductionDB
            )

            let processed = buffer.mapFloatSamples { sample in
                var value = Double(sample) * smoothedGain
                let level = abs(value)

                if level > compressorThreshold,
                   compressorThreshold > 0 {
                    let inputDB = Self.db(level)
                    let excessDB = inputDB
                        - configuration.compressorThresholdDB
                    let outputDB = configuration.compressorThresholdDB
                        + excessDB / configuration.compressorRatio
                    let gain = Self.linear(
                        outputDB - inputDB
                    )
                    value *= gain
                }

                let expandedLevel = abs(value)

                if expandedLevel < expanderThreshold,
                   expanderThreshold > 0 {
                    let ratio = max(
                        expandedLevel / expanderThreshold,
                        1e-9
                    )
                    let gain = max(
                        minimumExpanderGain,
                        pow(
                            ratio,
                            configuration.expanderRatio - 1
                        )
                    )
                    value *= gain
                }

                return Float(
                    max(
                        -1,
                        min(
                            1,
                            value
                        )
                    )
                )
            }

            let outputRMS = Self.rms(
                processed.monoFloatSamples()
            )
            let outputRMSDB = Self.db(outputRMS)

            return .init(
                buffer: processed,
                telemetry: .init(
                    inputRMSDB: inputRMSDB,
                    outputRMSDB: outputRMSDB,
                    appliedGainDB: outputRMSDB - inputRMSDB
                )
            )
        }
    }
}

private extension Audio.Processing.AnalysisEnhancer {
    static func rms(
        _ samples: [Float]
    ) -> Double {
        guard !samples.isEmpty else {
            return 0
        }

        let squared = samples.reduce(0.0) {
            $0 + Double($1) * Double($1)
        }

        return sqrt(
            squared / Double(samples.count)
        )
    }

    static func db(
        _ value: Double
    ) -> Double {
        20 * log10(
            max(
                value,
                1e-12
            )
        )
    }

    static func linear(
        _ db: Double
    ) -> Double {
        pow(
            10,
            db / 20
        )
    }
}
