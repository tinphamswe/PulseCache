import Foundation

/// Mutable editor state; making a saved definition captures a value snapshot of it.
struct RequestDraft: Equatable, Codable, Sendable {
    var name = ""
    var url = ""
    var method: HTTPMethod = .get
    var headers: [HeaderField] = []
    var queryParameters: [QueryParameter] = []
    var jsonBody: String? = nil
    var authentication: Authentication = .none

    var bodyData: Data? {
        guard let jsonBody,
              !jsonBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return Data(jsonBody.utf8)
    }

    var secretReferences: Set<SecretReference> {
        var references = Set(headers.filter(\.isEnabled).compactMap { field in
            if case .secret(let reference) = field.value { return reference }
            return nil
        })
        if let reference = authentication.secretReference {
            references.insert(reference)
        }
        return references
    }
}
