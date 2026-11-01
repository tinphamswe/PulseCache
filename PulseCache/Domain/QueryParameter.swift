import Foundation

struct QueryParameter: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    var name: String
    var value: String
    var isEnabled = true
}
