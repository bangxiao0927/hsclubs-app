import Foundation

struct HistoryPoint: Codable, Sendable, Equatable {
    let at: Date
    let clubCount: Int
}
