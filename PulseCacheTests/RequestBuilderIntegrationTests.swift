import Foundation
import Testing
@testable import PulseCache

@Suite("Request builder with production validation")
struct RequestBuilderIntegrationTests {
    private let builder: any RequestBuilding = RequestBuilder()

    @Test("The default builder rejects invalid drafts")
    func invalidDraft() {
        #expect(throws: RequestValidationError.nameRequired) {
            try builder.build(RequestDefinition(draft: RequestDraft()))
        }
    }

    @Test("The real validator rejects injection in resolved credentials")
    func secretInjection() {
        let secret = SecretReference()
        #expect(throws: RequestValidationError.invalidHeaderValue("Authorization")) {
            try builder.build(RequestDefinition(draft: RequestDraft(
                name: "Private", url: "https://example.test", authentication: .bearer(secret)
            )), resolvedSecrets: [secret: "token\r\nInjected: value"])
        }
    }

    @Test("Bearer tokens are sent but never encoded into request snapshots")
    func bearerToken() throws {
        let secret = SecretReference()
        let definition = RequestDefinition(draft: RequestDraft(
            name: "Private", url: "https://example.test",
            headers: [HeaderField(name: "Accept", value: .plain("application/json"))],
            authentication: .bearer(secret)
        ))
        let built = try builder.build(definition, resolvedSecrets: [secret: "unique-private-token"])
        #expect(built.urlRequest.value(forHTTPHeaderField: "Authorization") == "Bearer unique-private-token")
        #expect(built.snapshot.headers == [
            HTTPHeader(name: "Accept", value: "application/json"),
            HTTPHeader(name: "Authorization", value: "[REDACTED]")
        ])
        let snapshotData = try JSONEncoder().encode(built.snapshot)
        let definitionData = try JSONEncoder().encode(definition)
        #expect(!String(decoding: snapshotData, as: UTF8.self).contains("unique-private-token"))
        #expect(!String(decoding: definitionData, as: UTF8.self).contains("unique-private-token"))
        #expect(built.snapshot.requestID == definition.id)
        #expect(built.snapshot.revision == 1)
    }

    @Test("Custom API-key header values are redacted")
    func apiKey() throws {
        let secret = SecretReference()
        let built = try builder.build(RequestDefinition(draft: RequestDraft(
            name: "Private", url: "https://example.test",
            authentication: .apiKey(header: "X-Service-Key", secret: secret)
        )), resolvedSecrets: [secret: "private-key"])
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Service-Key") == "private-key")
        #expect(built.snapshot.headers == [HTTPHeader(name: "X-Service-Key", value: "[REDACTED]")])
    }

    @Test("Explicit secret header rows are resolved and masked")
    func secretHeaders() throws {
        let secret = SecretReference()
        let built = try builder.build(RequestDefinition(draft: RequestDraft(
            name: "Private", url: "https://example.test", headers: [
                HeaderField(name: "X-Custom", value: .secret(secret)),
                HeaderField(name: "X-Disabled", value: .secret(SecretReference()), isEnabled: false)
            ]
        )), resolvedSecrets: [secret: "private"])
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Custom") == "private")
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Disabled") == nil)
        #expect(built.snapshot.headers == [HTTPHeader(name: "X-Custom", value: "[REDACTED]")])
    }
}
