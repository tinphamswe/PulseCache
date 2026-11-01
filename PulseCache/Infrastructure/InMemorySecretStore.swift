/// Immutable fixture storage; production credentials will use Keychain.
struct InMemorySecretStore {
    private let values: [SecretReference: String]

    init(values: [SecretReference: String] = [:]) {
        self.values = values
    }
}

// MARK: - SecretRepository

extension InMemorySecretStore: SecretRepository {
    func value(for reference: SecretReference) async throws -> String {
        guard let value = values[reference] else { throw RequestError.missingSecret(reference) }
        return value
    }
}
