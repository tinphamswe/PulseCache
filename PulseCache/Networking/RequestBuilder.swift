import Foundation

struct RequestBuilder {
    private let validator: any RequestValidating
    private let headerRedactor: any HeaderRedacting

    init(
        validator: any RequestValidating = RequestValidator(),
        headerRedactor: any HeaderRedacting = HeaderRedactor()
    ) {
        self.validator = validator
        self.headerRedactor = headerRedactor
    }
}

// MARK: - RequestBuilding

extension RequestBuilder: RequestBuilding {
    func build(
        _ definition: RequestDefinition,
        resolvedSecrets: [SecretReference: String]
    ) throws -> PreparedRequest {
        let draft = definition.draft
        try validator.validate(draft)
        let url = try buildURL(for: draft)
        let headers = try buildHeaders(for: draft, secrets: resolvedSecrets)
        return PreparedRequest(
            urlRequest: makeURLRequest(url: url, draft: draft, headers: headers.values),
            snapshot: makeSnapshot(definition: definition, url: url, headers: headers)
        )
    }
}

// MARK: - Private

private extension RequestBuilder {
    struct ResolvedHeaders {
        let values: [HTTPHeader]
        let secretNames: Set<String>
    }

    func buildURL(for draft: RequestDraft) throws -> URL {
        var components = try validator.urlComponents(for: draft)
        appendQueryParameters(draft.queryParameters, to: &components)
        guard let url = components.url else { throw RequestValidationError.invalidURL }
        return url
    }

    func appendQueryParameters(_ parameters: [QueryParameter], to components: inout URLComponents) {
        let additionalItems = parameters.filter(\.isEnabled).map {
            URLQueryItem(name: $0.name, value: $0.value)
        }
        // Leave the original query untouched when there are no editor rows to append.
        guard !additionalItems.isEmpty else { return }
        var addition = URLComponents()
        addition.queryItems = additionalItems
        // Preserve the original escaping and escape literal '+' for form-style servers.
        let encodedAddition = addition.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components.percentEncodedQuery = [components.percentEncodedQuery, encodedAddition]
            .compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "&")
    }

    func buildHeaders(
        for draft: RequestDraft, secrets: [SecretReference: String]
    ) throws -> ResolvedHeaders {
        var headers: [HTTPHeader] = []
        var secretNames: Set<String> = []
        for field in draft.headers where field.isEnabled {
            headers.append(try resolveHeader(field, secrets: secrets))
            if case .secret = field.value {
                secretNames.insert(field.name)
            }
        }
        if let header = try authenticationHeader(draft.authentication, secrets: secrets) {
            headers.append(header)
            secretNames.insert(header.name)
        }
        appendContentTypeIfNeeded(to: &headers, body: draft.bodyData)
        return ResolvedHeaders(values: headers, secretNames: secretNames)
    }

    func resolveHeader(_ field: HeaderField, secrets: [SecretReference: String]) throws -> HTTPHeader {
        let value: String
        switch field.value {
        case .plain(let plain): value = plain
        case .secret(let reference): value = try resolve(reference, in: secrets)
        }
        try validator.validateHeaderValue(value, name: field.name)
        return HTTPHeader(name: field.name, value: value)
    }

    func appendContentTypeIfNeeded(to headers: inout [HTTPHeader], body: Data?) {
        guard body != nil,
              !headers.contains(where: { $0.name.caseInsensitiveCompare("Content-Type") == .orderedSame }) else {
            return
        }
        headers.append(HTTPHeader(name: "Content-Type", value: "application/json"))
    }

    func makeURLRequest(url: URL, draft: RequestDraft, headers: [HTTPHeader]) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
        request.httpMethod = draft.method.rawValue
        request.httpShouldHandleCookies = false
        request.httpBody = draft.bodyData
        for header in headers { request.setValue(header.value, forHTTPHeaderField: header.name) }

        return request
    }

    func makeSnapshot(
        definition: RequestDefinition, url: URL, headers: ResolvedHeaders
    ) -> RedactedRequestSnapshot {
        RedactedRequestSnapshot(
            requestID: definition.id, revision: definition.revision, method: definition.draft.method,
            url: url, headers: headerRedactor.redact(headers.values, additionalNames: headers.secretNames),
            body: definition.draft.bodyData
        )
    }

    func authenticationHeader(
        _ authentication: Authentication, secrets: [SecretReference: String]
    ) throws -> HTTPHeader? {
        let header: HTTPHeader
        switch authentication {
        case .none: return nil
        case .bearer(let reference):
            header = HTTPHeader(name: "Authorization", value: "Bearer \(try resolve(reference, in: secrets))")
        case .apiKey(let name, let reference):
            header = HTTPHeader(name: name, value: try resolve(reference, in: secrets))
        }
        try validator.validateHeaderValue(header.value, name: header.name)
        return header
    }

    func resolve(
        _ reference: SecretReference, in secrets: [SecretReference: String]
    ) throws -> String {
        guard let value = secrets[reference],
              !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw RequestError.missingSecret(reference)
        }
        return value
    }
}
