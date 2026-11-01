//
//  MockURLProtocol.swift
//  PulseCacheTests
//
//  Created by Tin Pham on 1/11/26.
//

import Foundation

/// Installed only on an injected test session, never registered globally.
final class MockURLProtocol: URLProtocol, @unchecked Sendable {
    private static let registry = Registry()

    // Serializes delivery with stopLoading, including reentrant client callbacks.
    private let deliveryLock = NSRecursiveLock()
    private var scenario: Scenario?
    private var isTerminal = false
    private var hasResponse = false

    static func makeScenario() -> Scenario {
        let scenario = Scenario()
        registry.insert(scenario)
        return scenario
    }

    // MARK: - URLProtocol

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        deliveryLock.lock()
        defer { deliveryLock.unlock() }
        guard !isTerminal else { return }
        guard let host = request.url?.host, let scenario = Self.registry.find(host: host) else {
            isTerminal = true
            client?.urlProtocol(self, didFailWithError: URLError(.unsupportedURL))
            return
        }
        self.scenario = scenario
        scenario.attach(self, request: request)
    }

    override func stopLoading() {
        deliveryLock.lock()
        defer { deliveryLock.unlock() }
        guard !isTerminal else { return }
        isTerminal = true
        scenario?.recordStop()
    }
}

// MARK: - Private

private extension MockURLProtocol {
    func respond(status: Int, headers: [String: String]) -> Bool {
        deliveryLock.lock()
        defer { deliveryLock.unlock() }
        guard !isTerminal, !hasResponse, let url = request.url,
              let response = HTTPURLResponse(
                url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers
              ) else { return false }
        hasResponse = true
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        return true
    }

    func send(_ data: Data) -> Bool {
        deliveryLock.lock()
        defer { deliveryLock.unlock() }
        guard !isTerminal, hasResponse else { return false }
        client?.urlProtocol(self, didLoad: data)
        return true
    }

    func finish() -> Bool {
        deliveryLock.lock()
        defer { deliveryLock.unlock() }
        guard !isTerminal, hasResponse else { return false }
        isTerminal = true
        client?.urlProtocolDidFinishLoading(self)
        return true
    }

    func fail(_ code: URLError.Code) -> Bool {
        deliveryLock.lock()
        defer { deliveryLock.unlock() }
        guard !isTerminal else { return false }
        isTerminal = true
        client?.urlProtocol(self, didFailWithError: URLError(code))
        return true
    }
}

// MARK: - Scenario

extension MockURLProtocol {
    /// A unique host isolates each test. NSLock protects captured requests and loader access;
    /// AsyncStream continuations safely buffer start/stop events even before tests await them.
    final class Scenario: @unchecked Sendable {
        let url: URL
        private let lock = NSLock()
        private weak var loader: MockURLProtocol?
        private var capturedRequests: [URLRequest] = []
        private var stops = 0
        private let starts: AsyncStream<URLRequest>
        private let startContinuation: AsyncStream<URLRequest>.Continuation
        private let stopEvents: AsyncStream<Void>
        private let stopContinuation: AsyncStream<Void>.Continuation

        fileprivate init() {
            url = URL(string: "https://\(UUID().uuidString.lowercased()).example.test/resource")!
            var start: AsyncStream<URLRequest>.Continuation!
            starts = AsyncStream { start = $0 }
            startContinuation = start
            var stop: AsyncStream<Void>.Continuation!
            stopEvents = AsyncStream { stop = $0 }
            stopContinuation = stop
        }

        var requests: [URLRequest] {
            lock.lock()
            defer { lock.unlock() }
            return capturedRequests
        }

        var stopCount: Int {
            lock.lock()
            defer { lock.unlock() }
            return stops
        }

        func waitUntilStarted() async -> URLRequest? {
            for await request in starts { return request }
            return nil
        }

        func waitUntilStopped() async -> Bool {
            for await _ in stopEvents { return true }
            return false
        }

        func respond(status: Int = 200, headers: [String: String] = [:]) -> Bool {
            activeLoader()?.respond(status: status, headers: headers) ?? false
        }

        func send(_ data: Data) -> Bool { activeLoader()?.send(data) ?? false }
        func finish() -> Bool { activeLoader()?.finish() ?? false }
        func fail(_ code: URLError.Code) -> Bool { activeLoader()?.fail(code) ?? false }

        func close() {
            registry.remove(self)
            startContinuation.finish()
            stopContinuation.finish()
        }

        fileprivate func attach(_ loader: MockURLProtocol, request: URLRequest) {
            lock.lock()
            self.loader = loader
            capturedRequests.append(request)
            lock.unlock()
            startContinuation.yield(request)
        }

        fileprivate func recordStop() {
            lock.lock()
            stops += 1
            lock.unlock()
            stopContinuation.yield(())
        }
    }
}

// MARK: - Private

private extension MockURLProtocol.Scenario {
    func activeLoader() -> MockURLProtocol? {
        lock.lock()
        defer { lock.unlock() }
        return loader
    }
}

// MARK: - Registry

private extension MockURLProtocol {
    /// All registry access is locked; immutable static ownership is safe across parallel tests.
    final class Registry: @unchecked Sendable {
        private let lock = NSLock()
        private var scenarios: [String: Scenario] = [:]

        func insert(_ scenario: Scenario) {
            lock.lock()
            defer { lock.unlock() }
            scenarios[scenario.url.host!] = scenario
        }

        func find(host: String) -> Scenario? {
            lock.lock()
            defer { lock.unlock() }
            return scenarios[host]
        }

        func remove(_ scenario: Scenario) {
            lock.lock()
            defer { lock.unlock() }
            scenarios[scenario.url.host!] = nil
        }
    }
}
