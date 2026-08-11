import Foundation

public extension Audio {
    enum Sample: String, Sendable, Codable, Hashable, CaseIterable {
        case int16
        case int24
        case int32
        case float32

        public var bits: Int {
            switch self {
            case .int16:
                return 16

            case .int24:
                return 24

            case .int32:
                return 32

            case .float32:
                return 32
            }
        }

        public var bytes: Int {
            bits / 8
        }

        internal var isFloat: Bool {
            switch self {
            case .float32:
                return true

            case .int16, .int24, .int32:
                return false
            }
        }
    }
}
