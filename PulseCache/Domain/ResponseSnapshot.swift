import Foundation

struct ResponseSnapshot: Equatable, Codable, Sendable {
    let statusCode: Int
    let headers: [HTTPHeader]
    let body: Data
    let capturedAt: Date
    let elapsedMilliseconds: Double

    var isSuccessful: Bool { (200..<300).contains(statusCode) }
}
