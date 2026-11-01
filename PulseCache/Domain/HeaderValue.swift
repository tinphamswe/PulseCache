enum HeaderValue: Equatable, Codable, Sendable {
    case plain(String)
    case secret(SecretReference)
}
