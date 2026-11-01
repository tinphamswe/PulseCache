import Foundation

/// Persist this representation instead of a URLRequest containing resolved credentials.
struct RedactedRequestSnapshot: Equatable, Codable, Sendable {
    let requestID: UUID
    let revision: Int
    let method: HTTPMethod
    let url: URL
    let headers: [HTTPHeader]
    let body: Data?
}
