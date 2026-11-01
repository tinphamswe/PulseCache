enum RequestValidationError: Error, Equatable, Sendable {
    case nameRequired
    case invalidURL
    case httpsRequired
    case embeddedCredentials
    case fragmentNotAllowed
    case invalidHeaderName(String)
    case invalidHeaderValue(String)
    case duplicateHeader(String)
    case secretHeaderRequired(String)
    case queryNameRequired
    case bodyNotAllowed
    case invalidJSONBody
}
