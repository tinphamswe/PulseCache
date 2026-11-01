import Foundation

protocol RequestRepository: Sendable {
    func requests() async throws -> [RequestDefinition]
    func request(id: UUID) async throws -> RequestDefinition?
    func save(_ request: RequestDefinition) async throws
    func delete(id: UUID) async throws
}
