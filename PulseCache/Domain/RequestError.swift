/// Error metadata deliberately excludes URLSession's potentially sensitive descriptions.
enum RequestError: Error, Equatable, Codable, Sendable {
    case transport(code: Int)
    case timedOut
    case invalidResponse
    case responseTooLarge(limitBytes: Int)
    case missingSecret(SecretReference)
}
