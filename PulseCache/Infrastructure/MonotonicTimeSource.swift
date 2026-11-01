protocol MonotonicTimeSource: Sendable {
    func nowNanoseconds() -> UInt64
}
