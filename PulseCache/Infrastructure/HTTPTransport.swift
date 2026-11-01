import Foundation

protocol HTTPTransport: Sendable {
    func execute(_ request: URLRequest) async throws -> ResponseSnapshot
}
