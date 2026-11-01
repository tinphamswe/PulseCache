import Foundation
import Testing
@testable import PulseCache

@Suite("Request validation")
struct RequestValidationTests {
    private let validator = RequestValidator(headerSensitivity: StubHeaderSensitivityChecker())

    @Test("Rejects plaintext fields identified by the injected policy", arguments: [true, false])
    func injectedSensitiveHeader(isEnabled: Bool) {
        let validator = RequestValidator(headerSensitivity: StubHeaderSensitivityChecker(
            sensitiveNames: ["X-Custom-Private"]
        ))
        #expect(throws: RequestValidationError.secretHeaderRequired("X-Custom-Private")) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test", headers: [
                    HeaderField(name: "X-Custom-Private", value: .plain("private"), isEnabled: isEnabled)
                ]
            ))
        }
    }

    @Test("Uses the injected policy rather than the production sensitive-name list")
    func injectedNonSensitiveHeader() throws {
        try validator.validate(RequestDraft(
            name: "Example", url: "https://example.test",
            headers: [HeaderField(name: "Authorization", value: .plain("fixture-value"))]
        ))
    }

    @Test("Sensitive fields can store secret references")
    func sensitiveSecretReference() throws {
        let validator = RequestValidator(headerSensitivity: StubHeaderSensitivityChecker(
            sensitiveNames: ["X-Custom-Private"]
        ))
        try validator.validate(RequestDraft(
            name: "Example", url: "https://example.test",
            headers: [HeaderField(name: "X-Custom-Private", value: .secret(SecretReference()))]
        ))
    }

    @Test("Invalid URL configurations", arguments: [
        ("not a URL", RequestValidationError.invalidURL),
        ("https://", .invalidURL),
        ("http://example.test", .httpsRequired),
        ("ftp://example.test", .httpsRequired),
        ("https://user:password@example.test", .embeddedCredentials),
        ("https://user@example.test", .embeddedCredentials),
        ("https://example.test/#section", .fragmentNotAllowed),
        ("https://example.test/\npath", .invalidURL)
    ])
    func invalidURLs(url: String, expected: RequestValidationError) {
        #expect(throws: expected) {
            try validator.validate(RequestDraft(name: "Example", url: url))
        }
    }

    @Test("Blank names are rejected", arguments: ["", "  ", "\n\t"])
    func blankNames(_ name: String) {
        #expect(throws: RequestValidationError.nameRequired) {
            try validator.validate(RequestDraft(name: name, url: "https://example.test"))
        }
    }

    @Test("Object and array JSON bodies are valid", arguments: ["{}", "[]", "{\"enabled\":true}", "[1,null]"])
    func validJSON(_ body: String) throws {
        try validator.validate(RequestDraft(
            name: "Example", url: "https://example.test", method: .post, jsonBody: body
        ))
    }

    @Test("Malformed or scalar JSON is rejected", arguments: ["{", "null", "true", "42", "\"text\""])
    func invalidJSON(_ body: String) {
        #expect(throws: RequestValidationError.invalidJSONBody) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test", method: .put, jsonBody: body
            ))
        }
    }

    @Test("GET rejects a body")
    func getBody() {
        #expect(throws: RequestValidationError.bodyNotAllowed) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test", jsonBody: "{}"
            ))
        }
    }

    @Test("Invalid header names", arguments: ["", "X Space", "X:Name", "X\r\nName", "Café"])
    func headerNames(_ name: String) {
        #expect(throws: RequestValidationError.invalidHeaderName(name)) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test",
                headers: [HeaderField(name: name, value: .plain("value"))]
            ))
        }
    }

    @Test("Header values reject control-character injection", arguments: ["value\r\nInjected: yes", "bad\n", "nul\0"])
    func headerValues(_ value: String) {
        #expect(throws: RequestValidationError.invalidHeaderValue("X-Test")) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test",
                headers: [HeaderField(name: "X-Test", value: .plain(value))]
            ))
        }
    }

    @Test("Duplicate header names are case-insensitive")
    func duplicateHeaders() {
        #expect(throws: RequestValidationError.duplicateHeader("accept")) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test", headers: [
                    HeaderField(name: "Accept", value: .plain("application/json")),
                    HeaderField(name: "accept", value: .plain("text/plain"))
                ]
            ))
        }
    }

    @Test("Authentication cannot overwrite an explicit header")
    func authCollision() {
        #expect(throws: RequestValidationError.duplicateHeader("X-Service-Key")) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test",
                headers: [HeaderField(name: "x-service-key", value: .plain("ordinary"))],
                authentication: .apiKey(header: "X-Service-Key", secret: SecretReference())
            ))
        }
    }

    @Test("Disabled invalid rows are ignored")
    func disabledFields() throws {
        try validator.validate(RequestDraft(
            name: "Example", url: "https://example.test",
            headers: [HeaderField(name: "bad name", value: .plain("\n"), isEnabled: false)],
            queryParameters: [QueryParameter(name: "", value: "", isEnabled: false)]
        ))
    }

    @Test("Enabled query rows need a name")
    func emptyQueryName() {
        #expect(throws: RequestValidationError.queryNameRequired) {
            try validator.validate(RequestDraft(
                name: "Example", url: "https://example.test",
                queryParameters: [QueryParameter(name: "", value: "value")]
            ))
        }
    }
}
