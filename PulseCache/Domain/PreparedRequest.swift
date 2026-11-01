import Foundation

/// Transient transport input. Only `snapshot` is suitable for history storage.
struct PreparedRequest: Sendable {
    let urlRequest: URLRequest
    let snapshot: RedactedRequestSnapshot
}
