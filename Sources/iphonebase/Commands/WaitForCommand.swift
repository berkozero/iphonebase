import ArgumentParser
import IPhoneBaseCore
import Foundation

struct WaitForCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "wait-for",
        abstract: "Wait for text to appear on screen (OCR polling)."
    )

    @Argument(help: "Text to wait for.")
    var text: String

    @Option(name: .long, help: "Timeout in seconds (default: 10).")
    var timeout: Double = 10

    @Option(name: .long, help: "Poll interval in seconds (default: 0.5).")
    var interval: Double = 0.5

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    @Flag(name: [.short, .long], help: "Verbose debug output.")
    var verbose = false

    func run() async throws {
        let capture = ScreenCapture()
        let ocr = OCREngine()

        var match: OCRElement?
        let ms = await measureMs {
            match = await ocr.waitForText(
                matching: text,
                capture: capture,
                timeout: timeout,
                interval: interval,
                verbose: verbose
            )
        }

        if let match = match {
            if json {
                let result = ActionResult.ok(action: "wait-for", data: match, durationMs: ms)
                result.printJSON()
            } else {
                print("Found \"\(match.text)\" at (\(match.centerX), \(match.centerY)) in \(ms)ms")
            }
        } else {
            if json {
                let result = ActionResult<EmptyData>(
                    success: false,
                    action: "wait-for",
                    error: "Timed out after \(timeout)s waiting for \"\(text)\"",
                    durationMs: ms
                )
                result.printJSON()
            } else {
                print("Timed out after \(timeout)s waiting for \"\(text)\"")
            }
            throw ExitCode.failure
        }
    }
}
