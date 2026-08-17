import Foundation
@testable import HSclubs

actor FakeSchoolsAPI: SchoolsAPI {
    enum Outcome {
        case success(Data)
        case failure(SchoolsAPIError)
    }

    private var outcome: Outcome

    init(outcome: Outcome) {
        self.outcome = outcome
    }

    func setOutcome(_ outcome: Outcome) {
        self.outcome = outcome
    }

    func fetchSchoolsPageData() async throws -> Data {
        switch outcome {
        case .success(let data):
            return data
        case .failure(let error):
            throw error
        }
    }
}
