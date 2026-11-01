import Testing
@testable import PulseCache

@Suite("Header sensitivity and redaction policy")
struct HeaderRedactorTests {
    private let redactor = HeaderRedactor()

    @Test("Known sensitive headers are masked case-insensitively", arguments: [
        "AUTHORIZATION", "Proxy-Authorization", "Cookie", "Set-Cookie",
        "X-Api-Key", "API-Key", "ApiKey", "X-Auth-Token"
    ])
    func sensitiveHeaders(_ name: String) {
        #expect(redactor.isSensitive(name))
        #expect(redactor.redact([HTTPHeader(name: name, value: "private")]) == [
            HTTPHeader(name: name, value: "[REDACTED]")
        ])
    }

    @Test("Ordinary header values and ordering are preserved")
    func ordinaryHeaders() {
        let headers = [
            HTTPHeader(name: "Accept", value: "application/json"),
            HTTPHeader(name: "X-Trace", value: "trace-id")
        ]
        #expect(!redactor.isSensitive("Accept"))
        #expect(redactor.redact(headers) == headers)
    }

    @Test("Additional secret names are masked case-insensitively")
    func additionalNames() {
        let headers = [
            HTTPHeader(name: "X-Service-Key", value: "private"),
            HTTPHeader(name: "Accept", value: "application/json")
        ]
        #expect(redactor.redact(headers, additionalNames: ["x-service-key"]) == [
            HTTPHeader(name: "X-Service-Key", value: "[REDACTED]"),
            HTTPHeader(name: "Accept", value: "application/json")
        ])
    }
}
