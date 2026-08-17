import SwiftUI

struct RootView: View {
    @Bindable var model: DirectoryViewModel
    @Bindable var schoolSelection: SchoolSelection

    var body: some View {
        Group {
            if schoolSelection.isSwitching {
                DirectoryView(model: model, schoolSelection: schoolSelection)
            } else if let selection = selectedSchool {
                SchoolSiteView(
                    school: selection.school,
                    siteURL: selection.siteURL,
                    schoolSelection: schoolSelection
                )
            } else {
                DirectoryView(model: model, schoolSelection: schoolSelection)
            }
        }
        .task {
            await model.loadIfNeeded()
        }
        .onChange(of: schoolSelection.isSwitching) { _, isSwitching in
            if isSwitching {
                model.clearSearch()
            }
        }
        .onChange(of: unresolvableSelection) { _, isUnresolvable in
            if isUnresolvable {
                schoolSelection.clear()
            }
        }
    }

    private var selectedSchool: (school: School, siteURL: URL)? {
        guard
            let selectedSlug = schoolSelection.selectedSlug,
            let school = model.payload?.schools.first(where: { $0.slug == selectedSlug }),
            let siteURL = school.verifiedSiteURL
        else { return nil }
        return (school, siteURL)
    }

    /// A remembered school that the current payload no longer verifies must not silently
    /// reappear later and replace the directory while the user is browsing it.
    private var unresolvableSelection: Bool {
        guard
            let selectedSlug = schoolSelection.selectedSlug,
            let schools = model.payload?.schools
        else { return false }

        return !schools.contains { $0.slug == selectedSlug && $0.verifiedSiteURL != nil }
    }
}
