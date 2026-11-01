import Foundation

protocol RequestValidating: Sendable {
    func validate(_ draft: RequestDraft) throws
    func urlComponents(for draft: RequestDraft) throws -> URLComponents
    func validateHeaderValue(_ value: String, name: String) throws
}
