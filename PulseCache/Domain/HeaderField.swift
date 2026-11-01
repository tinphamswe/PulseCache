import Foundation

struct HeaderField: Identifiable, Equatable, Codable, Sendable {
    var id = UUID()
    var name: String
    var value: HeaderValue
    var isEnabled = true
}
