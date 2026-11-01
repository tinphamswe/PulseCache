import Foundation
import Testing
@testable import PulseCache

@Suite("In-memory request repository with stub validation")
struct InMemoryRequestRepositoryTests {
    @Test("Saves, updates, looks up, and deletes through the repository interface")
    func lifecycle() async throws {
        let repository: any RequestRepository = InMemoryRequestRepository(validator: StubRequestValidator())
        let first = definition(name: "One")
        try await repository.save(first)
        let edited = RequestDefinition(
            id: first.id, revision: 2,
            draft: RequestDraft(name: "Two", url: "https://example.test/v2"),
            createdAt: first.createdAt
        )
        try await repository.save(edited)
        #expect(try await repository.requests() == [edited])
        #expect(try await repository.request(id: first.id) == edited)
        try await repository.delete(id: first.id)
        #expect(try await repository.requests().isEmpty)
        #expect(try await repository.request(id: first.id) == nil)
    }

    @Test("Injected validation errors propagate without storing the request")
    func rejectedSave() async throws {
        let repository: any RequestRepository = InMemoryRequestRepository(
            validator: StubRequestValidator(draftError: .rejectedDraft)
        )
        let request = definition(name: "Valid fixture")
        await #expect(throws: StubValidationError.rejectedDraft) {
            try await repository.save(request)
        }
        #expect(try await repository.requests().isEmpty)
    }

    @Test("The injected validator can accept a draft rejected by production validation")
    func acceptedByStub() async throws {
        let repository: any RequestRepository = InMemoryRequestRepository(validator: StubRequestValidator())
        let request = RequestDefinition(draft: RequestDraft(name: "", url: "not a URL"))
        try await repository.save(request)
        #expect(try await repository.request(id: request.id) == request)
    }

    @Test("Concurrent callers do not lose independently saved requests")
    func concurrentSaves() async throws {
        let repository: any RequestRepository = InMemoryRequestRepository(validator: StubRequestValidator())
        let requests = (0..<32).map { index in
            definition(name: "Request \(index)", createdAt: Date(timeIntervalSince1970: Double(index)))
        }
        try await withThrowingTaskGroup(of: Void.self) { group in
            for request in requests {
                group.addTask { try await repository.save(request) }
            }
            try await group.waitForAll()
        }
        #expect(try await repository.requests() == requests)
    }

    @Test("Requests with equal timestamps have stable UUID ordering")
    func equalTimestampOrdering() async throws {
        let repository: any RequestRepository = InMemoryRequestRepository(validator: StubRequestValidator())
        let lowerID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        let higherID = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        let first = definition(name: "Zulu", id: lowerID)
        let second = definition(name: "Alpha", id: higherID)
        try await repository.save(second)
        try await repository.save(first)
        #expect(try await repository.requests().map(\.id) == [lowerID, higherID])
    }
}

// MARK: - Private

private extension InMemoryRequestRepositoryTests {
    func definition(
        name: String, createdAt: Date = Date(timeIntervalSince1970: 0), id: UUID = UUID()
    ) -> RequestDefinition {
        RequestDefinition(
            id: id, draft: RequestDraft(name: name, url: "https://example.test"), createdAt: createdAt
        )
    }
}
