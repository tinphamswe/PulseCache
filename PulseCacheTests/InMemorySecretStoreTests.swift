import Testing
@testable import PulseCache

@Suite("Immutable in-memory secret store")
struct InMemorySecretStoreTests {
    @Test("Lookups distinguish versions of the same credential")
    func secretVersions() async throws {
        let first = SecretReference()
        let second = SecretReference(id: first.id, version: 2)
        let store: any SecretRepository = InMemorySecretStore(values: [first: "old", second: "new"])
        #expect(try await store.value(for: first) == "old")
        #expect(try await store.value(for: second) == "new")
    }

    @Test("Missing credentials produce a typed error")
    func missingSecret() async {
        let missing = SecretReference()
        let store: any SecretRepository = InMemorySecretStore()
        await #expect(throws: RequestError.missingSecret(missing)) {
            try await store.value(for: missing)
        }
    }
}
