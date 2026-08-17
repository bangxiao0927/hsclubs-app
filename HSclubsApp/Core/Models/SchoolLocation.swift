import Foundation

struct SchoolLocation: Codable, Sendable, Equatable {
    let lat: Double
    let lon: Double

    var isValid: Bool {
        (-90...90).contains(lat) && (-180...180).contains(lon)
    }
}
