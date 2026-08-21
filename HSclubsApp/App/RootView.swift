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
        .onChange(of: model.directory) { _, directory in
            // Reconcile once the directory changes: migrate a legacy slug to an id, or drop a
            // selection that has vanished or turned not-openable. Done here rather than in a
            // computed property so the migration writes through exactly once per load.
            if let directory {
                _ = schoolSelection.reconcile(
                    with: directory,
                    allowDestructiveReset: model.directoryIsAuthoritative
                )
            }
        }
        .onChange(of: model.directoryIsAuthoritative) { _, isAuthoritative in
            // A network payload can equal the cached payload, so directory itself may not emit a
            // second change. Reconcile again when that payload becomes authoritative.
            if isAuthoritative, let directory = model.directory {
                _ = schoolSelection.reconcile(with: directory)
            }
        }
    }

    private var selectedSchool: (school: DirectorySchool, siteURL: URL)? {
        guard
            let selectedSchoolId = schoolSelection.selectedSchoolId,
            let school = model.directory?.schools.first(where: { $0.schoolId == selectedSchoolId }),
            let siteURL = school.enterableURL
        else { return nil }
        return (school, siteURL)
    }
}
