import Foundation
import Observation

/// The remembered choice of school, keyed on the immutable `schoolId`.
///
/// A slug cannot carry a remembered selection across a rename -- that is the whole reason the
/// registry issues an identity -- so the stored value is the `schoolId`, wrapped in a versioned
/// envelope. A pre-v1 install remembered a slug under the old key; that value is migrated to an
/// id the first time a directory is read that can map it, and dropped if it cannot be resolved
/// uniquely (see `reconcile(with:)`).
@MainActor
@Observable
final class SchoolSelection {
    static let selectionKey = "selected-school@v1"
    static let legacySlugKey = "selected-school-slug"

    private struct StoredSelection: Codable {
        static let currentVersion = 1
        let version: Int
        let schoolId: String
    }

    private let storage: UserDefaults
    private(set) var selectedSchoolId: String?
    /// A slug from a pre-v1 install, held until a directory read can map it to an id.
    private(set) var pendingLegacySlug: String?

    init(storage: UserDefaults = .standard) {
        self.storage = storage
        if
            let data = storage.data(forKey: Self.selectionKey),
            let stored = try? JSONDecoder().decode(StoredSelection.self, from: data),
            stored.version == StoredSelection.currentVersion
        {
            selectedSchoolId = stored.schoolId
        } else {
            pendingLegacySlug = storage.string(forKey: Self.legacySlugKey)
        }
    }

    var isSwitching = false

    func select(_ school: DirectorySchool) {
        persist(schoolId: school.schoolId)
        isSwitching = false
    }

    func clear() {
        selectedSchoolId = nil
        pendingLegacySlug = nil
        storage.removeObject(forKey: Self.selectionKey)
        storage.removeObject(forKey: Self.legacySlugKey)
        isSwitching = false
    }

    /// Reconciles the remembered selection against a freshly loaded directory.
    ///
    /// Three cases, in order: a migrated selection that is still present and openable is kept; a
    /// selection that has vanished or turned not-openable is cleared, so a school that went
    /// incompatible does not strand the user on a dead site; and a legacy slug is migrated to an
    /// id when exactly one school matches it, or dropped when zero or several do. Returns the
    /// school to open now, or nil to show the directory.
    func reconcile(
        with directory: AppDirectory,
        allowDestructiveReset: Bool = true
    ) -> DirectorySchool? {
        if let selectedSchoolId {
            guard
                let school = directory.schools.first(where: { $0.schoolId == selectedSchoolId }),
                school.enterableURL != nil
            else {
                if allowDestructiveReset { clear() }
                return nil
            }
            return school
        }

        guard let slug = pendingLegacySlug else { return nil }
        let matches = directory.schools.filter { $0.slug == slug }
        guard matches.count == 1, let migrated = matches.first, migrated.enterableURL != nil else {
            // Zero matches, several, or a match that cannot be opened: a slug is not enough to
            // resume safely, so forget it and let the user choose again.
            if allowDestructiveReset { clear() }
            return nil
        }
        persist(schoolId: migrated.schoolId)
        return migrated
    }

    func requestSwitch() {
        isSwitching = true
    }

    func cancelSwitch() {
        isSwitching = false
    }

    private func persist(schoolId: String) {
        selectedSchoolId = schoolId
        pendingLegacySlug = nil
        let stored = StoredSelection(version: StoredSelection.currentVersion, schoolId: schoolId)
        if let encoded = try? JSONEncoder().encode(stored) {
            storage.set(encoded, forKey: Self.selectionKey)
        }
        // The legacy key is retired once a versioned selection exists, so a later launch does not
        // try to migrate a slug that has already been resolved.
        storage.removeObject(forKey: Self.legacySlugKey)
    }
}
