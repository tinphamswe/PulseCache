import Foundation
@testable import PulseCache

/// Controls validation independently of the production validator. Each test owns its value.
struct StubRequestValidator {
    var draftError: StubValidationError?
    var urlError: StubValidationError?
    var headerValueError: StubValidationError?
    var components: URLComponents?
}

// MARK: - RequestValidating

extension StubRequestValidator: RequestValidating {
    func validate(_ draft: RequestDraft) throws {
        if let draftError { throw draftError }
    }

    func urlComponents(for draft: RequestDraft) throws -> URLComponents {
        if let urlError { throw urlError }
        if let components { return components }
        guard let components = URLComponents(string: draft.url) else {
            throw StubValidationError.invalidFixtureURL
        }
        return components
    }

    func validateHeaderValue(_ value: String, name: String) throws {
        if let headerValueError { throw headerValueError }
    }
}
