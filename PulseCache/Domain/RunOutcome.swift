enum RunOutcome: Equatable, Codable, Sendable {
    /// Includes non-2xx HTTP responses, which remain useful monitoring results.
    case response(ResponseSnapshot)
    case failure(RequestError)
    case cancelled
    case interrupted
}
