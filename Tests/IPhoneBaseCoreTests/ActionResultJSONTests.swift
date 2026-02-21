import Testing
import Foundation
@testable import IPhoneBaseCore

@Suite("ActionResult JSON encoding")
struct ActionResultJSONTests {

    @Test("Success result encodes expected keys")
    func successKeys() throws {
        let result = ActionResult.ok(action: "tap", data: ["x": 100], durationMs: 42)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let data = try encoder.encode(result)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"success\":true"))
        #expect(json.contains("\"action\":\"tap\""))
        #expect(json.contains("\"durationMs\":42"))
    }

    @Test("Error result encodes error field")
    func errorResult() throws {
        let result = ActionResult<EmptyData>(
            success: false,
            action: "tap",
            error: "Element not found"
        )
        let data = try JSONEncoder().encode(result)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("\"success\":false"))
        #expect(json.contains("Element not found"))
    }

    @Test("EmptyData encodes as empty object")
    func emptyData() throws {
        let data = try JSONEncoder().encode(EmptyData())
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json == "{}")
    }

    @Test("OCRElement round-trips through JSON")
    func ocrElementRoundTrip() throws {
        let element = OCRElement(text: "Settings", x: 10, y: 20, width: 100, height: 30, centerX: 60, centerY: 35, confidence: 0.95)
        let data = try JSONEncoder().encode(element)
        let decoded = try JSONDecoder().decode(OCRElement.self, from: data)
        #expect(decoded.text == "Settings")
        #expect(decoded.centerX == 60)
        #expect(decoded.centerY == 35)
        #expect(decoded.confidence == 0.95)
    }

    @Test("GridCell uses snake_case coding keys")
    func gridCellSnakeCase() throws {
        let cell = GridCell(x: 0, y: 0, width: 100, height: 100, centerX: 50, centerY: 50)
        let data = try JSONEncoder().encode(cell)
        let json = try #require(String(data: data, encoding: .utf8))
        #expect(json.contains("center_x"))
        #expect(json.contains("center_y"))
    }
}
