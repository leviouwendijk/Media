import Foundation
import MediaAV

public extension LTC {
    enum AssetSignalResolutionError:
        Error,
        Sendable,
        LocalizedError,
        Equatable
    {
        case noSignal(
            URL
        )

        case ambiguousSignals(
            URL,
            count: Int
        )

        public var errorDescription: String? {
            switch self {
            case .noSignal(let url):
                return "No decodable LTC signal was found in media asset: \(url.path)"

            case .ambiguousSignals(let url, let count):
                return "Media asset contains \(count) independently decodable LTC signals; selection must be explicit: \(url.path)"
            }
        }
    }

    struct AssetSignalResolver: Sendable {
        public let seeds: [FrameRate]
        public let rateDetector: FrameRateDetector

        public init(
            seeds: [FrameRate] = [
                .fps30,
                .fps25,
                .fps24,
            ],
            rateDetector: FrameRateDetector = FrameRateDetector()
        ) {
            self.seeds = seeds
            self.rateDetector = rateDetector
        }

        public func scan(
            _ url: URL
        ) async throws -> [AssetSignal] {
            let url = url.standardizedFileURL

            let inspection = try await MediaAssetInspector().inspect(
                url
            )

            let decoder = AssetDecoder()

            var signals: [AssetSignal] = []

            for track in inspection.audioTracks.sorted(by: {
                $0.id < $1.id
            }) {
                let channelCount = max(
                    1,
                    track.formats
                        .compactMap(\.channelCount)
                        .max()
                        ?? 1
                )

                for channel in 0..<channelCount {
                    for seed in seeds {
                        do {
                            let decode = try await decoder.decode(
                                url,
                                trackID: track.id,
                                channel: channel,
                                fps: seed.framesPerSecond
                            )

                            guard !decode.frames.isEmpty else {
                                continue
                            }

                            let detection = try rateDetector.detect(
                                decode
                            )

                            signals.append(
                                AssetSignal(
                                    decode: decode,
                                    detection: detection
                                )
                            )

                            break
                        } catch {
                            continue
                        }
                    }
                }
            }

            return signals
        }

        public func resolve(
            _ url: URL
        ) async throws -> AssetSignal {
            let url = url.standardizedFileURL

            let signals = try await scan(
                url
            )

            guard !signals.isEmpty else {
                throw AssetSignalResolutionError.noSignal(
                    url
                )
            }

            guard signals.count == 1,
                  let signal = signals.first else {
                throw AssetSignalResolutionError.ambiguousSignals(
                    url,
                    count: signals.count
                )
            }

            return signal
        }
    }
}
