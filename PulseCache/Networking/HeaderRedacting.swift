protocol HeaderRedacting: Sendable {
    func redact(_ headers: [HTTPHeader], additionalNames: Set<String>) -> [HTTPHeader]
}
