import Foundation

struct RequestDefinition: Identifiable, Equatable, Codable, Sendable {
    let id: UUID
    let revision: Int
    let draft: RequestDraft
    let createdAt: Date
    let updatedAt: Date

    init(
        id: UUID = UUID(), revision: Int = 1, draft: RequestDraft,
        createdAt: Date = Date(), updatedAt: Date? = nil
    ) {
        self.id = id
        self.revision = revision
        self.draft = draft
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
    }
}
