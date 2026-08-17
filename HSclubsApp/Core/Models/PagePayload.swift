import Foundation

struct PagePayload: Codable, Sendable, Equatable {
    let title: String
    let generatedAt: Date
    let totals: Totals
    let schools: [School]
}
