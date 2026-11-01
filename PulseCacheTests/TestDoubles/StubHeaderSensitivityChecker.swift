@testable import PulseCache

struct StubHeaderSensitivityChecker {
    var sensitiveNames: Set<String> = []
}

// MARK: - HeaderSensitivityChecking

extension StubHeaderSensitivityChecker: HeaderSensitivityChecking {
    func isSensitive(_ name: String) -> Bool { sensitiveNames.contains(name) }
}
