import Dispatch

struct UptimeTimeSource {}

// MARK: - MonotonicTimeSource

extension UptimeTimeSource: MonotonicTimeSource {
    func nowNanoseconds() -> UInt64 { DispatchTime.now().uptimeNanoseconds }
}
