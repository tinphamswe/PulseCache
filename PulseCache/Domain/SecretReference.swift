import Foundation

/// Identifies one version of a secret. The resolved value belongs only in memory/Keychain.
struct SecretReference: Hashable, Codable, Sendable {
    let id: UUID
    let version: Int

    init(id: UUID = UUID(), version: Int = 1) {
        self.id = id
        self.version = version
    }
}
