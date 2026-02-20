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
        let capture = ScreenCapture()
        let ocr = OCREngine()

        let image = try await capture.captureWindow()
        let elements = try ocr.recognize(image: image)

        if json {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(elements)
            if let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            if elements.isEmpty {
                print("No text elements detected on screen.")
            } else {
                print("Detected \(elements.count) element(s):\n")
                for (i, el) in elements.enumerated() {
                    print("  [\(i)] \"\(el.text)\" at (\(el.centerX), \(el.centerY)) [\(el.width)x\(el.height)] conf=\(String(format: "%.2f", el.confidence))")
                }
            }
        }
    }
}
