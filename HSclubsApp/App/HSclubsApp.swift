import SwiftUI

@main
struct HSclubsApp: App {
    @State private var directoryModel = AppEnvironment.makeDirectoryViewModel()
    @State private var schoolSelection = SchoolSelection()

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
            // The mobile-auth callback returns through ASWebAuthenticationSession's own https
            // callback (see WebAuthenticating), which is the Universal Link mechanism and keeps the
            // whole flow inside the sign-in the app started. There is deliberately no separate
            // inbound-link handler: a callback that arrived outside a live session would have no
            // web view to spend its code in, so handling it would only produce spurious errors.
            RootView(model: directoryModel, schoolSelection: schoolSelection)
        }
    }
}
