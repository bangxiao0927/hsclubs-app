import SwiftUI

@main
struct HSclubsApp: App {
    @State private var directoryModel = AppEnvironment.makeDirectoryViewModel()
    @State private var schoolSelection = SchoolSelection()
    @State private var mobileAuth = MobileAuthController()

    init() {
        let arguments = ProcessInfo.processInfo.arguments
#if DEBUG
        if arguments.contains("--ui-testing-empty") || arguments.contains("--ui-testing-sample") {
            let storage = UserDefaults(suiteName: "net.hsclubs.app.uitests")!
            if arguments.contains("--ui-testing-reset") {
                storage.removeObject(forKey: SchoolSelection.selectionKey)
                storage.removeObject(forKey: SchoolSelection.legacySlugKey)
            }
            _schoolSelection = State(initialValue: SchoolSelection(storage: storage))
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: directoryModel, schoolSelection: schoolSelection, mobileAuth: mobileAuth)
                // Universal Links arrive as a web-browsing activity, on cold start and while
                // running alike. The callback path is the only one the app claims (see the
                // Associated Domains entitlement); anything else is left to the browser.
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    mobileAuth.handle(activity)
                }
        }
    }
}
