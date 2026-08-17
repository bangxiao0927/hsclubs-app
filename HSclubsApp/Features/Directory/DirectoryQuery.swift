import Foundation

enum DirectoryQuery {
    /// Matches only what the user can see on a row: the school name and its host.
    static func search(_ schools: [School], query: String) -> [School] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return schools }

        return schools.filter { school in
            school.schoolName.lowercased().contains(term)
                || (school.host?.lowercased().contains(term) ?? false)
        }
    }

    static func sortedByName(_ schools: [School]) -> [School] {
        schools.enumerated().sorted { lhs, rhs in
            let order = lhs.element.schoolName.localizedCompare(rhs.element.schoolName)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}
