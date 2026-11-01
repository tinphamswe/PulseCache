import Testing
@testable import PulseCache

@Suite("Request validation with production header policy")
struct RequestValidationIntegrationTests {
    private let validator = RequestValidator()

    @Test("Sensitive headers require secret references", arguments: ["Authorization", "COOKIE", "X-API-Key", "Proxy-Authorization"])
    func plainSecrets(_ name: String) {
        #expect(throws: RequestValidationError.secretHeaderRequired(name)) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test",
                headers: [HeaderField(name: name, value: .plain("secret"))]
            ))
        }
    }

    @Test("Disabled sensitive headers cannot persist plaintext credentials")
    func disabledPlainSecret() async {
        let repository = InMemoryRequestRepository()
        let definition = RequestDefinition(draft: RequestDraft(
            name: "Example", url: "https://example.test",
            headers: [HeaderField(name: "Authorization", value: .plain("private"), isEnabled: false)]
        ))
        await #expect(throws: RequestValidationError.secretHeaderRequired("Authorization")) {
            try await repository.save(definition)
        }
        #expect(await repository.requests().isEmpty)
    }
}
