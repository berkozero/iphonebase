import Testing
import Darwin
@testable import IPhoneBaseCore

private struct SampleData: Encodable {
    let name: String
    let value: Int
}

@Suite("ActionResult")
struct ActionResultTests {

    @Test("ok() produces success=true with data")
    func okResult() {
        let result = ActionResult.ok(action: "test", data: SampleData(name: "hello", value: 42), durationMs: 100)
        #expect(result.success == true)
        #expect(result.action == "test")
        #expect(result.data?.name == "hello")
        #expect(result.data?.value == 42)
        #expect(result.error == nil)
        #expect(result.durationMs == 100)
    }

    @Test("Error result has success=false")
    func errorResult() {
        let result = ActionResult<EmptyData>(
            success: false,
            action: "tap",
            error: "Element not found"
        )
        #expect(result.success == false)
        #expect(result.action == "tap")
        #expect(result.data == nil)
        #expect(result.error == "Element not found")
    }

    @Test("Default durationMs is 0")
    func defaultDuration() {
        let result = ActionResult<EmptyData>(success: true, action: "test")
        #expect(result.durationMs == 0)
    }

    @Test("ok() with zero durationMs")
    func okZeroDuration() {
        let result = ActionResult.ok(action: "tap", data: SampleData(name: "a", value: 1))
        #expect(result.success == true)
        #expect(result.durationMs == 0)
    }
}

@Suite("measureMs")
struct MeasureMsTests {

    @Test("Measures async throwing block time")
    func asyncThrowingTiming() async throws {
        let ms = try await measureMs {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        #expect(ms >= 40, "Expected at least 40ms, got \(ms)")
        #expect(ms < 500, "Expected less than 500ms, got \(ms)")
    }

    @Test("Measures async non-throwing block time")
    func asyncNonThrowingTiming() async {
        let ms = await measureMs {
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        }
        #expect(ms >= 40, "Expected at least 40ms, got \(ms)")
        #expect(ms < 500, "Expected less than 500ms, got \(ms)")
    }

    @Test("Measures sync block time")
    func syncTiming() {
        let ms = measureMs {
            usleep(50_000) // 50ms
        }
        #expect(ms >= 40, "Expected at least 40ms, got \(ms)")
        #expect(ms < 500, "Expected less than 500ms, got \(ms)")
    }
}
