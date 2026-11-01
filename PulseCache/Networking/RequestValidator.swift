import Foundation

struct RequestValidator {
    private let headerSensitivity: any HeaderSensitivityChecking

    init(headerSensitivity: any HeaderSensitivityChecking = HeaderRedactor()) {
        self.headerSensitivity = headerSensitivity
    }
}

// MARK: - RequestValidating

extension RequestValidator: RequestValidating {
    func validate(_ draft: RequestDraft) throws {
        try validateName(draft.name)
        _ = try urlComponents(for: draft)
        try validateHeaders(draft.headers, authentication: draft.authentication)
        try validateQueryParameters(draft.queryParameters)
        try validateBody(draft.bodyData, method: draft.method)
    }

    func urlComponents(for draft: RequestDraft) throws -> URLComponents {
        let components = try parseURL(draft.url)
        try validateURLPolicy(components)
        return components
    }

    func validateHeaderValue(_ value: String, name: String) throws {
        guard !value.unicodeScalars.contains(where: {
            CharacterSet.controlCharacters.contains($0) && $0.value != 9
        }) else { throw RequestValidationError.invalidHeaderValue(name) }
    }
}

// MARK: - Private

private extension RequestValidator {
    func validateName(_ name: String) throws {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RequestValidationError.nameRequired
        }
    }

    func validateHeaders(_ fields: [HeaderField], authentication: Authentication) throws {
        var names: Set<String> = []
        for field in fields {
            try validateCredentialStorage(field)
            guard field.isEnabled else { continue }
            try registerHeaderName(field.name, in: &names)
            if case .plain(let value) = field.value {
                try validateHeaderValue(value, name: field.name)
            }
        }
        if let name = authentication.headerName {
            try registerHeaderName(name, in: &names)
        }
    }

    func validateCredentialStorage(_ field: HeaderField) throws {
        // Disabled rows are still saved, so they must not retain plaintext credentials.
        if case .plain = field.value, headerSensitivity.isSensitive(field.name) {
            throw RequestValidationError.secretHeaderRequired(field.name)
        }
    }

    func registerHeaderName(_ name: String, in names: inout Set<String>) throws {
        try validateHeaderName(name)
        guard names.insert(name.lowercased()).inserted else {
            throw RequestValidationError.duplicateHeader(name)
        }
    }

    func validateQueryParameters(_ parameters: [QueryParameter]) throws {
        for parameter in parameters where parameter.isEnabled {
            guard !parameter.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw RequestValidationError.queryNameRequired
            }
        }
    }

    func validateBody(_ data: Data?, method: HTTPMethod) throws {
        guard let data else { return }
        guard method != .get else { throw RequestValidationError.bodyNotAllowed }
        guard let json = try? JSONSerialization.jsonObject(with: data),
              json is [String: Any] || json is [Any] else {
            throw RequestValidationError.invalidJSONBody
        }
    }

    func parseURL(_ url: String) throws -> URLComponents {
        let input = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }),
              let components = URLComponents(string: input),
              let host = components.host, !host.isEmpty,
              !host.unicodeScalars.contains(where: { CharacterSet.whitespacesAndNewlines.contains($0) }),
              components.url != nil else {
            throw RequestValidationError.invalidURL
        }
        return components
    }

    func validateURLPolicy(_ components: URLComponents) throws {
        guard components.scheme?.lowercased() == "https" else {
            throw RequestValidationError.httpsRequired
        }
        guard components.user == nil, components.password == nil else {
            throw RequestValidationError.embeddedCredentials
        }
        guard components.fragment == nil else { throw RequestValidationError.fragmentNotAllowed }
    }

    func validateHeaderName(_ name: String) throws {
        let punctuation = Set("!#$%&'*+-.^_`|~".utf8)
        guard !name.isEmpty, name.utf8.allSatisfy({ byte in
            (65...90).contains(byte) || (97...122).contains(byte)
                || (48...57).contains(byte) || punctuation.contains(byte)
        }) else { throw RequestValidationError.invalidHeaderName(name) }
    }
}
