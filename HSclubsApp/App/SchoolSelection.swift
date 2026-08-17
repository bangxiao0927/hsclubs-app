import Foundation
import Observation

@MainActor
@Observable
final class SchoolSelection {
    static let storageKey = "selected-school-slug"

    private let storage: UserDefaults
    private(set) var selectedSlug: String?

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        selectedSlug = storage.string(forKey: Self.storageKey)
    }

    var isSwitching = false

    func select(_ school: School) {
        selectedSlug = school.slug
        storage.set(school.slug, forKey: Self.storageKey)
        isSwitching = false
    }

    func clear() {
        selectedSlug = nil
        storage.removeObject(forKey: Self.storageKey)
        isSwitching = false
    }

    func requestSwitch() {
        isSwitching = true
    }

    func cancelSwitch() {
        isSwitching = false
    }
}
