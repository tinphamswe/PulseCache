import Testing
@testable import PulseCache

@Suite("Request draft credentials")
struct RequestDraftTests {
    @Test("Collects enabled, deduplicated credentials while ignoring plain and disabled headers")
    func enabledSecretReferences() {
        let headerSecret = SecretReference()
        let authenticationSecret = SecretReference(id: headerSecret.id, version: 2)
        let disabledSecret = SecretReference()
        let draft = RequestDraft(headers: [
            HeaderField(name: "Accept", value: .plain("application/json")),
            HeaderField(name: "X-First", value: .secret(headerSecret)),
            HeaderField(name: "X-Second", value: .secret(headerSecret)),
            HeaderField(name: "X-Disabled", value: .secret(disabledSecret), isEnabled: false)
        ], authentication: .apiKey(header: "X-Service-Key", secret: authenticationSecret))
        #expect(draft.secretReferences == [headerSecret, authenticationSecret])
    }

    @Test("An unauthenticated request with plain headers requires no secret lookup")
    func noSecretReferences() {
        let draft = RequestDraft(headers: [HeaderField(name: "Accept", value: .plain("application/json"))])
        #expect(draft.secretReferences.isEmpty)
    }
}
