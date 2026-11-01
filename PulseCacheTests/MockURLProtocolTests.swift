import Foundation
import Testing

@Suite("Controlled URLSession mock")
struct MockURLProtocolTests {
    @Test("Captures the supplied request and delivers response chunks")
    func responseChunks() async throws {
        let scenario = MockURLProtocol.makeScenario()
        let session = session()
        defer { session.invalidateAndCancel(); scenario.close() }
        let request = jsonPostRequest(to: scenario.url)
        let task = Task { try await session.data(for: request) }
        defer { task.cancel() }
        let captured = try #require(await scenario.waitUntilStarted())
        #expect(captured.httpMethod == "POST")
        #expect(captured.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(scenario.respond(status: 201, headers: ["X-Trace": "test-trace"]))
        #expect(scenario.send(Data("{\"ok\":".utf8)))
        #expect(scenario.send(Data("true}".utf8)))
        #expect(scenario.finish())
        let (data, response) = try await task.value
        let http = try #require(response as? HTTPURLResponse)
        #expect(http.statusCode == 201)
        #expect(http.value(forHTTPHeaderField: "X-Trace") == "test-trace")
        #expect(data == Data("{\"ok\":true}".utf8))
        #expect(scenario.requests.count == 1)
        #expect(!scenario.send(Data("late".utf8)))
    }

    @Test("A mocked transport error reaches the caller", arguments: [URLError.Code.timedOut, .notConnectedToInternet])
    func errors(_ code: URLError.Code) async throws {
        let scenario = MockURLProtocol.makeScenario()
        let session = session()
        defer { session.invalidateAndCancel(); scenario.close() }
        let task = Task { try await session.data(from: scenario.url) }
        defer { task.cancel() }
        _ = try #require(await scenario.waitUntilStarted())
        #expect(scenario.fail(code))
        await #expect {
            try await task.value
        } throws: { error in
            (error as? URLError)?.code == code
        }
    }

    @Test("Cancelling stops the protocol and rejects every later delivery")
    func cancellation() async throws {
        let scenario = MockURLProtocol.makeScenario()
        let session = session()
        defer { session.invalidateAndCancel(); scenario.close() }
        let task = Task { try await session.data(from: scenario.url) }
        defer { task.cancel() }
        _ = try #require(await scenario.waitUntilStarted())
        #expect(scenario.respond())
        task.cancel()
        await #expect {
            try await task.value
        } throws: { error in
            (error as? URLError)?.code == .cancelled
        }
        #expect(await scenario.waitUntilStopped())
        #expect(scenario.stopCount == 1)
        #expect(!scenario.respond())
        #expect(!scenario.send(Data("late".utf8)))
        #expect(!scenario.finish())
        #expect(!scenario.fail(.timedOut))
    }

    @Test("Parallel sessions cannot consume each other's fixtures")
    func isolatedScenarios() async throws {
        let first = MockURLProtocol.makeScenario()
        let second = MockURLProtocol.makeScenario()
        let firstSession = session()
        let secondSession = session()
        defer {
            firstSession.invalidateAndCancel()
            secondSession.invalidateAndCancel()
            first.close()
            second.close()
        }
        let firstTask = Task { try await firstSession.data(from: first.url) }
        let secondTask = Task { try await secondSession.data(from: second.url) }
        defer { firstTask.cancel(); secondTask.cancel() }
        _ = try #require(await first.waitUntilStarted())
        _ = try #require(await second.waitUntilStarted())
        #expect(second.respond(status: 503))
        #expect(second.send(Data("second".utf8)))
        #expect(second.finish())
        #expect(first.respond(status: 200))
        #expect(first.send(Data("first".utf8)))
        #expect(first.finish())
        let firstResult = try await firstTask.value
        let secondResult = try await secondTask.value
        #expect(firstResult.0 == Data("first".utf8))
        #expect(secondResult.0 == Data("second".utf8))
        #expect((secondResult.1 as? HTTPURLResponse)?.statusCode == 503)
        #expect(first.requests.map(\.url) == [first.url])
        #expect(second.requests.map(\.url) == [second.url])
    }

    @Test("Unregistered URLs fail closed instead of reaching the network")
    func unregisteredURL() async throws {
        let session = session()
        defer { session.invalidateAndCancel() }
        let url = try #require(URL(string: "https://unregistered.example.test/"))
        await #expect {
            try await session.data(from: url)
        } throws: { error in
            (error as? URLError)?.code == .unsupportedURL
        }
    }

    @Test("Closing an unused scenario releases start and stop waiters")
    func closedScenarioWaiters() async {
        let scenario = MockURLProtocol.makeScenario()
        async let started = scenario.waitUntilStarted()
        async let stopped = scenario.waitUntilStopped()
        scenario.close()
        let outcomes = await (started, stopped)
        #expect(outcomes.0 == nil)
        #expect(!outcomes.1)
    }
}

// MARK: - Private

private extension MockURLProtocolTests {
    func jsonPostRequest(to url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = Data("{}".utf8)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        configuration.urlCache = nil
        return URLSession(configuration: configuration)
    }
}
