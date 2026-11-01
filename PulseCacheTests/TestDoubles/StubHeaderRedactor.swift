@testable import PulseCache

struct StubHeaderRedactor {
    var result: @Sendable ([HTTPHeader], Set<String>) -> [HTTPHeader] = { headers, _ in headers }
}

// MARK: - HeaderRedacting

extension StubHeaderRedactor: HeaderRedacting {
    func redact(_ headers: [HTTPHeader], additionalNames: Set<String>) -> [HTTPHeader] {
        result(headers, additionalNames)
    }
}
