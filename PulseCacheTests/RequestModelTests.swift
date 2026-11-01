//
//  RequestModelTests.swift
//  PulseCacheTests
//
//  Created by Tin Pham on 1/11/26.
//

import Foundation
import Testing
@testable import PulseCache

@Suite("Request and response model contracts")
struct RequestModelTests {
    @Test("Saved definitions capture drafts by value")
    func immutableDefinition() {
        var draft = RequestDraft(name: "Original", url: "https://example.test")
        let definition = RequestDefinition(draft: draft)
        draft.name = "Edited"
        #expect(definition.draft.name == "Original")
    }

    @Test("Definitions round-trip ordered fields and secret references")
    func codableDefinition() throws {
        let secret = SecretReference()
        let draft = RequestDraft(
            name: "Search", url: "https://example.test", method: .post,
            headers: [HeaderField(name: "X-Private", value: .secret(secret))],
            queryParameters: [
                QueryParameter(name: "tag", value: "swift"),
                QueryParameter(name: "tag", value: "ios")
            ], jsonBody: "{}", authentication: .bearer(secret)
        )
        let definition = RequestDefinition(draft: draft)
        let data = try JSONEncoder().encode(definition)
        #expect(try JSONDecoder().decode(RequestDefinition.self, from: data) == definition)
        #expect(draft.secretReferences == [secret])
    }

    @Test("HTTP success classification", arguments: [
        (200, true), (204, true), (299, true), (300, false), (401, false), (500, false)
    ])
    func successfulResponses(status: Int, expected: Bool) {
        let response = ResponseSnapshot(
            statusCode: status, headers: [], body: Data(),
            capturedAt: Date(timeIntervalSince1970: 0), elapsedMilliseconds: 1
        )
        #expect(response.isSuccessful == expected)
    }

    @Test("HTTP failures remain serializable response outcomes")
    func responseOutcome() throws {
        let response = ResponseSnapshot(
            statusCode: 401, headers: [], body: Data("denied".utf8),
            capturedAt: Date(timeIntervalSince1970: 0), elapsedMilliseconds: 10
        )
        let outcome = RunOutcome.response(response)
        let data = try JSONEncoder().encode(outcome)
        #expect(try JSONDecoder().decode(RunOutcome.self, from: data) == outcome)
    }
}
