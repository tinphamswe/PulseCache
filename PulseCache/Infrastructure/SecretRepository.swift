protocol SecretRepository: Sendable {
    func value(for reference: SecretReference) async throws -> String
}
