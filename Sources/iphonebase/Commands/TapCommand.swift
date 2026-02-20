import ArgumentParser
import IPhoneBaseCore
import Foundation

struct TapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "Tap at coordinates or on a text element."
    )

    @Argument(help: "X coordinate (ignored if --text is used).")
    var x: Double?

    @Argument(help: "Y coordinate (ignored if --text is used).")
    var y: Double?

    @Option(name: .long, help: "Find element by text (OCR) and tap its center.")
    var text: String?

    @Flag(name: .long, help: "Double-tap instead of single tap.")
    var double = false

    @Flag(name: .long, help: "Long press instead of tap.")
    var long = false

    @Option(name: .long, help: "Long press duration in milliseconds (default: 1000).")
    var duration: UInt32 = 1000

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    @Flag(name: [.short, .long], help: "Verbose debug output.")
    var verbose = false

    func validate() throws {
        if text == nil && (x == nil || y == nil) {
            throw ValidationError("Provide either X Y coordinates or --text to find an element.")
        }
    }

    func run() async throws {
        let wm = WindowManager()
        let window = try wm.findWindow()

        var tapX: Double
        var tapY: Double

        if let searchText = text {
            // OCR-based tap
            let capture = ScreenCapture(windowManager: wm)
            let ocr = OCREngine()
            let image = try await capture.captureWindow()
            let matches = try ocr.findElements(matching: searchText, in: image)

            guard let match = matches.first else {
                if json {
                    print(#"{"error": "No element found matching '\#(searchText)'"}"#)
                } else {
                    print("No element found matching \"\(searchText)\"")
                }
                throw ExitCode.failure
            }

            // Convert image coordinates to screen coordinates
            // Image is at retina resolution (2x), window bounds are in screen points
            let scaleX = window.bounds.width / Double(image.width)
            let scaleY = window.bounds.height / Double(image.height)

            tapX = window.bounds.origin.x + Double(match.centerX) * scaleX
            tapY = window.bounds.origin.y + Double(match.centerY) * scaleY

            if !json {
                print("Found \"\(match.text)\" at screen (\(Int(tapX)), \(Int(tapY)))")
            }
        } else {
            // Direct coordinate tap — coordinates are relative to the mirroring window
            tapX = window.bounds.origin.x + x!
            tapY = window.bounds.origin.y + y!
        }

        // Bring window to front first
        try wm.bringToFront()

        let injector = InputInjector()
        injector.verbose = verbose
        try injector.connect()
        defer { injector.disconnect() }

        if long {
            try injector.longPress(x: tapX, y: tapY, durationMs: duration)
        } else if double {
            try injector.doubleTap(x: tapX, y: tapY)
        } else {
            try injector.tap(x: tapX, y: tapY)
        }

        if json {
            let result: [String: Any] = [
                "action": long ? "long_press" : (double ? "double_tap" : "tap"),
                "x": Int(tapX),
                "y": Int(tapY),
                "text": text ?? "",
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else if text == nil {
            print("Tapped at (\(Int(tapX)), \(Int(tapY)))")
        }
    }
}
