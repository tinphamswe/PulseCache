enum Authentication: Equatable, Codable, Sendable {
    case none
    case bearer(SecretReference)
    case apiKey(header: String, secret: SecretReference)

    var headerName: String? {
        switch self {
        case .none: nil
        case .bearer: "Authorization"
        case .apiKey(let header, _): header
        }
    }

    var secretReference: SecretReference? {
        switch self {
        case .none: nil
        case .bearer(let reference), .apiKey(_, let reference): reference
        }
    }
}
