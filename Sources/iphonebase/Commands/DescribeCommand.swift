import ArgumentParser
import IPhoneBaseCore
import Foundation

struct DescribeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "describe",
        abstract: "Run OCR on the iPhone Mirroring window and list detected elements."
    )

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() async throws {
        let wm = WindowManager()
        let window = try wm.findWindow()
        let capture = ScreenCapture(windowManager: wm)
        let ocr = OCREngine()

        if json {
            var screenElements: [OCRElement] = []
            let ms = try await measureMs {
                let image = try await capture.captureWindow()
                let elements = try ocr.recognize(image: image)
                let scaleX = window.bounds.width / Double(image.width)
                let scaleY = window.bounds.height / Double(image.height)
                screenElements = elements.map { el in
                    OCRElement(
                        text: el.text,
                        x: Int(Double(el.x) * scaleX),
                        y: Int(Double(el.y) * scaleY),
                        width: Int(Double(el.width) * scaleX),
                        height: Int(Double(el.height) * scaleY),
                        centerX: Int(Double(el.centerX) * scaleX),
                        centerY: Int(Double(el.centerY) * scaleY),
                        confidence: el.confidence
                    )
                }
            }
            let result = ActionResult.ok(action: "describe", data: screenElements, durationMs: ms)
            result.printJSON()
        } else {
            let image = try await capture.captureWindow()
            let elements = try ocr.recognize(image: image)

            // Convert image pixels to window-relative screen points
            let scaleX = window.bounds.width / Double(image.width)
            let scaleY = window.bounds.height / Double(image.height)

            if elements.isEmpty {
                print("No text elements detected on screen.")
            } else {
                print("Detected \(elements.count) element(s):\n")
                for (i, el) in elements.enumerated() {
                    let cx = Int(Double(el.centerX) * scaleX)
                    let cy = Int(Double(el.centerY) * scaleY)
                    let w = Int(Double(el.width) * scaleX)
                    let h = Int(Double(el.height) * scaleY)
                    print("  [\(i)] \"\(el.text)\" at (\(cx), \(cy)) [\(w)x\(h)] conf=\(String(format: "%.2f", el.confidence))")
                }
            }
        }
    }
}
