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
                storage.removeObject(forKey: SchoolSelection.storageKey)
            }
            _schoolSelection = State(initialValue: SchoolSelection(storage: storage))
        }
#endif
    }

    var body: some Scene {
        WindowGroup {
            RootView(model: directoryModel, schoolSelection: schoolSelection)
        }
    }
}
