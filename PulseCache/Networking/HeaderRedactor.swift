import Foundation

struct HeaderRedactor {
    private let replacement = "[REDACTED]"
}

// MARK: - HeaderSensitivityChecking

extension HeaderRedactor: HeaderSensitivityChecking {
    func isSensitive(_ name: String) -> Bool {
        ["authorization", "proxy-authorization", "cookie", "set-cookie",
         "x-api-key", "api-key", "apikey", "x-auth-token"].contains(name.lowercased())
    }
}

// MARK: - HeaderRedacting

extension HeaderRedactor: HeaderRedacting {
    func redact(_ headers: [HTTPHeader], additionalNames: Set<String> = []) -> [HTTPHeader] {
        let names = Set(additionalNames.map { $0.lowercased() })
        return headers.map { header in
            HTTPHeader(
                name: header.name,
                value: isSensitive(header.name) || names.contains(header.name.lowercased())
                    ? replacement : header.value
            )
        }
    }
}
