import Testing
import CoreGraphics
@testable import IPhoneBaseCore

@Suite("WindowManagerError")
struct WindowManagerErrorTests {

    @Test("windowNotFound mentions iPhone Mirroring")
    func windowNotFound() {
        let err = WindowManagerError.windowNotFound
        #expect(err.description.contains("iPhone Mirroring"))
    }

    @Test("cannotBringToFront mentions foreground")
    func cannotBringToFront() {
        let err = WindowManagerError.cannotBringToFront
        #expect(err.description.contains("foreground"))
    }
}

@Suite("ScreenCaptureError")
struct ScreenCaptureErrorTests {

    @Test("windowNotFound mentions iPhone Mirroring")
    func windowNotFound() {
        let err = ScreenCaptureError.windowNotFound
        #expect(err.description.contains("iPhone Mirroring"))
    }

    @Test("captureFailure includes reason")
    func captureFailure() {
        let err = ScreenCaptureError.captureFailure("no permission")
        #expect(err.description.contains("no permission"))
    }

    @Test("saveFailed includes reason")
    func saveFailed() {
        let err = ScreenCaptureError.saveFailed("disk full")
        #expect(err.description.contains("disk full"))
    }
}

@Suite("OCRError")
struct OCRErrorTests {

    @Test("recognitionFailed includes reason")
    func recognitionFailed() {
        let err = OCRError.recognitionFailed("no text found")
        #expect(err.description.contains("no text found"))
    }
}

@Suite("MirroringWindow")
struct MirroringWindowTests {

    @Test("Stores all fields correctly")
    func fieldStorage() {
        let bounds = CGRect(x: 100, y: 200, width: 393, height: 852)
        let window = MirroringWindow(windowID: 42, bounds: bounds, ownerPID: 123, ownerName: "iPhone Mirroring")
        #expect(window.windowID == 42)
        #expect(window.bounds == bounds)
        #expect(window.ownerPID == 123)
        #expect(window.ownerName == "iPhone Mirroring")
    }
}
