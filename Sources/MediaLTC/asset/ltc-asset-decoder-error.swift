import Foundation

public extension LTC {
    enum AssetDecoderError:
        Error,
        Sendable,
        LocalizedError,
        Equatable
    {
        case no_audio_samples(
            URL
        )

        public var errorDescription: String? {
            switch self {
            case .no_audio_samples(let url):
                return "Media asset produced no audio samples for LTC decoding: \(url.path)"
            }
        }
    }
}
