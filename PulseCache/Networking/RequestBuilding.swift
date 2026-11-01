protocol RequestBuilding: Sendable {
    func build(
        _ definition: RequestDefinition,
        resolvedSecrets: [SecretReference: String]
    ) throws -> PreparedRequest
}

// MARK: - Convenience

extension RequestBuilding {
    func build(_ definition: RequestDefinition) throws -> PreparedRequest {
        try build(definition, resolvedSecrets: [:])
    }
}
