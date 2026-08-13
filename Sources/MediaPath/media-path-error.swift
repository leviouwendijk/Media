import Foundation

public enum MediaPathError: Error, Sendable, LocalizedError, Equatable {
    case source_not_found(URL)
    case invalid_output_relative_path(String)

    public var errorDescription: String? {
        switch self {
        case .source_not_found(let url):
            return "Media source does not exist: \(url.path)"

        case .invalid_output_relative_path(let path):
            return "Invalid media output relative path: \(path)"
        }
    }
}
