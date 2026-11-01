import Foundation
import Testing
@testable import PulseCache

@Suite("Outgoing requests and redacted history")
struct RequestBuilderTests {
    private let builder: any RequestBuilding = RequestBuilder(
        validator: StubRequestValidator(), headerRedactor: StubHeaderRedactor()
    )

    @Test("Builds each REST method", arguments: [
        (HTTPMethod.get, "GET"), (.post, "POST"), (.put, "PUT"), (.delete, "DELETE")
    ])
    func methods(method: HTTPMethod, expected: String) throws {
        let built = try builder.build(RequestDefinition(draft: RequestDraft(
            name: "Example", url: "https://example.test", method: method
        )))
        #expect(built.urlRequest.httpMethod == expected)
        #expect(built.urlRequest.timeoutInterval == 30)
        #expect(built.urlRequest.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(!built.urlRequest.httpShouldHandleCookies)
    }

    @Test("Preserves existing and duplicate query items, encoding values")
    func queryEncoding() throws {
        let built = try builder.build(RequestDefinition(draft: RequestDraft(
            name: "Search", url: "https://example.test/search?existing=1", queryParameters: [
                QueryParameter(name: "tag", value: "swift"),
                QueryParameter(name: "tag", value: "ios"),
                QueryParameter(name: "q", value: "café & a=b?#"),
                QueryParameter(name: "empty", value: ""),
                QueryParameter(name: "ignored", value: "no", isEnabled: false)
            ]
        )))
        let url = try #require(built.urlRequest.url)
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(items == [
            URLQueryItem(name: "existing", value: "1"),
            URLQueryItem(name: "tag", value: "swift"),
            URLQueryItem(name: "tag", value: "ios"),
            URLQueryItem(name: "q", value: "café & a=b?#"),
            URLQueryItem(name: "empty", value: "")
        ])
        #expect(url.fragment == nil)
    }

    @Test("Does not rewrite a query without additional enabled rows")
    func unchangedQuery() throws {
        let url = "https://example.test/?q=a%2Fb&flag"
        let built = try builder.build(RequestDefinition(draft: RequestDraft(name: "Example", url: url)))
        #expect(built.urlRequest.url?.absoluteString == url)
    }

    @Test("JSON bodies get a default content type", arguments: [HTTPMethod.post, .put, .delete])
    func jsonBodies(_ method: HTTPMethod) throws {
        let built = try builder.build(RequestDefinition(draft: RequestDraft(
            name: "Example", url: "https://example.test", method: method, jsonBody: "{\"ok\":true}"
        )))
        #expect(built.urlRequest.httpBody == Data("{\"ok\":true}".utf8))
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/json")
    }

    @Test("Appending query rows preserves original escaping and literal plus signs")
    func existingEncodedQuery() throws {
        let built = try builder.build(RequestDefinition(draft: RequestDraft(
            name: "Example", url: "https://example.test/?q=a%2Fb%2Bc&flag",
            queryParameters: [QueryParameter(name: "tag", value: "swift+ios")]
        )))
        #expect(built.urlRequest.url?.absoluteString == "https://example.test/?q=a%2Fb%2Bc&flag&tag=swift%2Bios")
    }

    @Test("An explicit content type is preserved regardless of casing")
    func explicitContentType() throws {
        let built = try builder.build(RequestDefinition(draft: RequestDraft(
            name: "Example", url: "https://example.test", method: .post,
            headers: [HeaderField(name: "content-type", value: .plain("application/problem+json"))],
            jsonBody: "{}"
        )))
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == "application/problem+json")
        #expect(built.snapshot.headers.count == 1)
    }

    @Test("A blank optional body sends no payload or content type", arguments: ["", "  \n"])
    func blankBody(_ body: String) throws {
        let built = try builder.build(RequestDefinition(draft: RequestDraft(
            name: "Example", url: "https://example.test", jsonBody: body
        )))
        #expect(built.urlRequest.httpBody == nil)
        #expect(built.urlRequest.value(forHTTPHeaderField: "Content-Type") == nil)
    }

    @Test("Missing or empty secrets fail before execution", arguments: [nil, "", " \n"] as [String?])
    func missingSecret(_ value: String?) {
        let secret = SecretReference()
        let secrets = value.map { [secret: $0] } ?? [:]
        #expect(throws: RequestError.missingSecret(secret)) {
            try builder.build(RequestDefinition(draft: RequestDraft(
                name: "Private", url: "https://example.test", authentication: .bearer(secret)
            )), resolvedSecrets: secrets)
        }
    }

    @Test("Uses the injected validator's accepted draft and URL components")
    func injectedValidation() throws {
        let components = try #require(URLComponents(string: "https://stub.example.test/accepted"))
        let builder = RequestBuilder(
            validator: StubRequestValidator(components: components), headerRedactor: StubHeaderRedactor()
        )
        let definition = RequestDefinition(draft: RequestDraft(name: "", url: "not a URL"))
        let built = try builder.build(definition)
        #expect(built.urlRequest.url?.absoluteString == "https://stub.example.test/accepted")
    }

    @Test("Propagates draft validation failure before attempting URL validation")
    func draftValidationFailure() {
        let builder = RequestBuilder(
            validator: StubRequestValidator(draftError: .rejectedDraft, urlError: .rejectedURL),
            headerRedactor: StubHeaderRedactor()
        )
        #expect(throws: StubValidationError.rejectedDraft) {
            try builder.build(RequestDefinition(draft: RequestDraft()))
        }
    }

    @Test("Propagates URL validation failure from the injected validator")
    func urlValidationFailure() {
        let builder = RequestBuilder(
            validator: StubRequestValidator(urlError: .rejectedURL), headerRedactor: StubHeaderRedactor()
        )
        #expect(throws: StubValidationError.rejectedURL) {
            try builder.build(RequestDefinition(draft: RequestDraft()))
        }
    }

    @Test("Delegates ordinary header value checks to the injected validator")
    func headerValidationFailure() {
        let builder = RequestBuilder(
            validator: StubRequestValidator(headerValueError: .rejectedHeaderValue),
            headerRedactor: StubHeaderRedactor()
        )
        #expect(throws: StubValidationError.rejectedHeaderValue) {
            try builder.build(RequestDefinition(draft: RequestDraft(
                name: "Example", url: "https://example.test",
                headers: [HeaderField(name: "Accept", value: .plain("application/json"))]
            )))
        }
    }

    @Test("Delegates resolved credential checks to the injected validator")
    func credentialValidationFailure() {
        let secret = SecretReference()
        let builder = RequestBuilder(
            validator: StubRequestValidator(headerValueError: .rejectedHeaderValue),
            headerRedactor: StubHeaderRedactor()
        )
        #expect(throws: StubValidationError.rejectedHeaderValue) {
            try builder.build(RequestDefinition(draft: RequestDraft(
                name: "Private", url: "https://example.test", authentication: .bearer(secret)
            )), resolvedSecrets: [secret: "private-token"])
        }
    }

    @Test("Passes resolved headers and secret names to the injected redactor")
    func injectedRedaction() throws {
        let secret = SecretReference()
        let builder = RequestBuilder(
            validator: StubRequestValidator(), headerRedactor: StubHeaderRedactor { headers, names in
                #expect(headers == [
                    HTTPHeader(name: "Accept", value: "application/json"),
                    HTTPHeader(name: "X-Private", value: "fixture-secret"),
                    HTTPHeader(name: "X-Service-Key", value: "fixture-secret")
                ])
                #expect(names == ["X-Private", "X-Service-Key"])
                return [HTTPHeader(name: "X-Stub-Snapshot", value: "sanitized")]
            }
        )
        let definition = RequestDefinition(draft: RequestDraft(
            name: "Private", url: "https://example.test", headers: [
                HeaderField(name: "Accept", value: .plain("application/json")),
                HeaderField(name: "X-Private", value: .secret(secret)),
                HeaderField(name: "X-Disabled", value: .secret(SecretReference()), isEnabled: false)
            ], authentication: .apiKey(header: "X-Service-Key", secret: secret)
        ))
        let built = try builder.build(definition, resolvedSecrets: [secret: "fixture-secret"])
        #expect(built.snapshot.headers == [HTTPHeader(name: "X-Stub-Snapshot", value: "sanitized")])
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Private") == "fixture-secret")
        #expect(built.urlRequest.value(forHTTPHeaderField: "X-Service-Key") == "fixture-secret")
    }
}
