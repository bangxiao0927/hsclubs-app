import Foundation

enum SchoolStatus: Sendable, Equatable {
    case live
    case stale
    case noData
    case unknown(String)
}

extension SchoolStatus: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        switch rawValue {
        case "live":
            self = .live
        case "stale":
            self = .stale
        case "no-data":
            self = .noData
        default:
            self = .unknown(rawValue)
        }
    }
}

extension SchoolStatus: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    private var rawValue: String {
        switch self {
        case .live: return "live"
        case .stale: return "stale"
        case .noData: return "no-data"
        case .unknown(let value): return value
        }
    }
}
