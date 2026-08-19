import Foundation

enum DirectoryQuery {
    /// Matches only what the user can see on a row: the school name and its host.
    static func search(_ schools: [DirectorySchool], query: String) -> [DirectorySchool] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !term.isEmpty else { return schools }

        return schools.filter { school in
            school.name.lowercased().contains(term)
                || school.host.lowercased().contains(term)
        }
    }

    static func sortedByName(_ schools: [DirectorySchool]) -> [DirectorySchool] {
        schools.enumerated().sorted { lhs, rhs in
            let order = lhs.element.name.localizedCompare(rhs.element.name)
            if order != .orderedSame { return order == .orderedAscending }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }
}
