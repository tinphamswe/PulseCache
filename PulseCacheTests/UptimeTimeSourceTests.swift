import Dispatch
import Testing
@testable import PulseCache

@Suite("Uptime clock adapter")
struct UptimeTimeSourceTests {
    @Test("Returns uptime nanoseconds within the surrounding system-clock readings")
    func uptimeNanoseconds() {
        let source: any MonotonicTimeSource = UptimeTimeSource()
        let before = DispatchTime.now().uptimeNanoseconds
        let observed = source.nowNanoseconds()
        let after = DispatchTime.now().uptimeNanoseconds
        #expect(observed >= before)
        #expect(observed <= after)
    }
}
