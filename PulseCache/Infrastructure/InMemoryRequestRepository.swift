import Foundation

/// Preview/test storage. Disk persistence and revision allocation arrive in Milestone 3.
actor InMemoryRequestRepository {
    private var definitions: [UUID: RequestDefinition] = [:]
    private let validator: any RequestValidating

    init(validator: any RequestValidating = RequestValidator()) {
        self.validator = validator
    }
}

// MARK: - RequestRepository

extension InMemoryRequestRepository: RequestRepository {
    func requests() -> [RequestDefinition] {
        definitions.values.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
            return $0.id.uuidString < $1.id.uuidString
        }
    }

    func request(id: UUID) -> RequestDefinition? { definitions[id] }

    func save(_ request: RequestDefinition) throws {
        try validator.validate(request.draft)
        definitions[request.id] = request
    }

    func delete(id: UUID) { definitions[id] = nil }
}
