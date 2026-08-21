import Foundation

enum AppEnvironment {
    static let apiBaseURL: URL = {
        guard
            let value = Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String,
            let url = URL(string: value),
            url.scheme == "https"
        else {
            preconditionFailure("APIBaseURL must be a valid HTTPS URL")
        }

        return url
    }()

    /// Mobile auth is fail-closed until the production Apple App ID and Universal Link are ready.
    static let mobileAuthEnabled: Bool = {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "MobileAuthEnabled") as? String else {
            return false
        }
        return ["yes", "true", "1"].contains(value.lowercased())
    }()

    @MainActor
    static func makeDirectoryViewModel() -> DirectoryViewModel {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-empty") {
            let repository = SchoolsRepository(
                api: UITestSchoolsAPI.empty,
                cache: UITestSchoolsCache()
            )
            return DirectoryViewModel(repository: repository)
        }
        if ProcessInfo.processInfo.arguments.contains("--ui-testing-sample") {
            let repository = SchoolsRepository(
                api: UITestSchoolsAPI.sample,
                cache: UITestSchoolsCache()
            )
            return DirectoryViewModel(repository: repository)
        }
#endif

        guard let host = apiBaseURL.host else {
            preconditionFailure("APIBaseURL must include a host")
        }

        let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        )[0].appendingPathComponent("HSclubs", isDirectory: true)
        let repository = SchoolsRepository(
            api: LiveSchoolsAPI(baseURL: apiBaseURL, expectedHost: host),
            cache: FileSchoolsCache(directory: cacheDirectory)
        )
        return DirectoryViewModel(repository: repository)
    }
}
