protocol HeaderSensitivityChecking: Sendable {
    func isSensitive(_ name: String) -> Bool
}
