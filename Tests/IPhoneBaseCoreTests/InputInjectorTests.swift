import Testing
import CoreGraphics
@testable import IPhoneBaseCore

// MARK: - KeyboardReport

@Suite("KeyboardReport")
struct KeyboardReportTests {

    @Test("Default report is 67 bytes with reportID=1")
    func defaultBytes() {
        let report = KeyboardReport()
        let bytes = report.toBytes()
        #expect(bytes.count == 67)
        #expect(bytes[0] == 1)   // reportID
        #expect(bytes[1] == 0)   // modifiers
        #expect(bytes[2] == 0)   // reserved
        #expect(bytes[3...].allSatisfy { $0 == 0 })
    }

    @Test("insertKey places keycode in first slot")
    func insertSingleKey() {
        var report = KeyboardReport()
        report.insertKey(0x04)  // 'a'
        let bytes = report.toBytes()
        #expect(bytes[3] == 0x04)
        #expect(bytes[4] == 0x00)
    }

    @Test("insertKey fills consecutive slots")
    func insertMultipleKeys() {
        var report = KeyboardReport()
        report.insertKey(0x04)  // 'a'
        report.insertKey(0x05)  // 'b'
        let bytes = report.toBytes()
        #expect(bytes[3] == 0x04)
        #expect(bytes[5] == 0x05)
    }

    @Test("insertKey does not duplicate existing keycode")
    func noDuplicates() {
        var report = KeyboardReport()
        report.insertKey(0x04)
        report.insertKey(0x04)
        let bytes = report.toBytes()
        #expect(bytes[3] == 0x04)
        #expect(bytes[5] == 0x00)  // second slot empty
    }

    @Test("Modifier byte reflects set value")
    func modifierByte() {
        var report = KeyboardReport()
        report.modifiers = 0x02  // leftShift
        let bytes = report.toBytes()
        #expect(bytes[1] == 0x02)
    }

    @Test("Combined modifier and key")
    func modifierAndKey() {
        var report = KeyboardReport()
        report.modifiers = HIDModifier.leftShift.rawValue
        report.insertKey(HIDKeyCode.a)
        let bytes = report.toBytes()
        #expect(bytes[1] == HIDModifier.leftShift.rawValue)
        #expect(bytes[3] == UInt8(HIDKeyCode.a & 0xFF))
    }
}

// MARK: - InputInjectorError

@Suite("InputInjectorError")
struct InputInjectorErrorTests {

    @Test("karabinerNotInstalled mentions Karabiner")
    func karabinerNotInstalled() {
        let err = InputInjectorError.karabinerNotInstalled
        #expect(err.description.contains("Karabiner"))
    }

    @Test("noServerSocket mentions socket")
    func noServerSocket() {
        let err = InputInjectorError.noServerSocket
        #expect(err.description.contains("socket"))
    }

    @Test("connectionFailed includes reason")
    func connectionFailed() {
        let err = InputInjectorError.connectionFailed("timeout")
        #expect(err.description.contains("timeout"))
    }

    @Test("notConnected mentions connect()")
    func notConnected() {
        let err = InputInjectorError.notConnected
        #expect(err.description.contains("connect()"))
    }

    @Test("outOfBounds includes coordinates")
    func outOfBounds() {
        let bounds = CGRect(x: 100, y: 200, width: 300, height: 400)
        let err = InputInjectorError.outOfBounds(x: 500, y: 600, bounds: bounds)
        #expect(err.description.contains("500"))
        #expect(err.description.contains("600"))
    }
}

// MARK: - Connection Guards

@Suite("InputInjector connection guards")
struct InputInjectorConnectionGuardTests {

    @Test("tap throws notConnected")
    func tapGuard() {
        let injector = InputInjector()
        #expect(throws: InputInjectorError.self) {
            try injector.tap(x: 100, y: 100)
        }
    }

    @Test("doubleTap throws notConnected")
    func doubleTapGuard() {
        let injector = InputInjector()
        #expect(throws: InputInjectorError.self) {
            try injector.doubleTap(x: 100, y: 100)
        }
    }

    @Test("longPress throws notConnected")
    func longPressGuard() {
        let injector = InputInjector()
        #expect(throws: InputInjectorError.self) {
            try injector.longPress(x: 100, y: 100)
        }
    }

    @Test("swipe throws notConnected")
    func swipeGuard() {
        let injector = InputInjector()
        #expect(throws: InputInjectorError.self) {
            try injector.swipe(direction: .up, fromX: 0, fromY: 0)
        }
    }

    @Test("drag throws notConnected")
    func dragGuard() {
        let injector = InputInjector()
        #expect(throws: InputInjectorError.self) {
            try injector.drag(fromX: 0, fromY: 0, toX: 100, toY: 100)
        }
    }

    @Test("typeText throws notConnected")
    func typeTextGuard() {
        let injector = InputInjector()
        #expect(throws: InputInjectorError.self) {
            try injector.typeText("hello")
        }
    }

    @Test("pressKey throws notConnected")
    func pressKeyGuard() {
        let injector = InputInjector()
        #expect(throws: InputInjectorError.self) {
            try injector.pressKey(keycode: HIDKeyCode.a)
        }
    }

    @Test("scroll throws notConnected")
    func scrollGuard() {
        let injector = InputInjector()
        #expect(throws: InputInjectorError.self) {
            try injector.scroll(direction: .down)
        }
    }
}

// MARK: - Coordinate Validation

@Suite("Coordinate validation")
struct CoordinateValidationTests {

    @Test("nil bounds passes any point")
    func nilBounds() throws {
        try validatePointInBounds(x: 99999, y: 99999, bounds: nil)
    }

    @Test("Point inside bounds passes")
    func insideBounds() throws {
        let bounds = CGRect(x: 100, y: 200, width: 300, height: 400)
        try validatePointInBounds(x: 200, y: 300, bounds: bounds)
    }

    @Test("Point outside bounds throws")
    func outsideBounds() {
        let bounds = CGRect(x: 100, y: 200, width: 300, height: 400)
        #expect(throws: InputInjectorError.self) {
            try validatePointInBounds(x: 500, y: 700, bounds: bounds)
        }
    }

    @Test("Point on origin edge passes")
    func onOriginEdge() throws {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        try validatePointInBounds(x: 0, y: 0, bounds: bounds)
    }

    @Test("Point at max edge does not pass (CGRect.contains behavior)")
    func atMaxEdge() {
        let bounds = CGRect(x: 0, y: 0, width: 100, height: 100)
        #expect(throws: InputInjectorError.self) {
            try validatePointInBounds(x: 100, y: 100, bounds: bounds)
        }
    }

    @Test("Negative coordinates outside bounds throw")
    func negativeCoordinates() {
        let bounds = CGRect(x: 100, y: 100, width: 200, height: 200)
        #expect(throws: InputInjectorError.self) {
            try validatePointInBounds(x: -10, y: -10, bounds: bounds)
        }
    }
}
