import ArgumentParser
import IPhoneBaseCore
import Foundation

struct ScreenshotCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "screenshot",
        abstract: "Capture the iPhone Mirroring window as a PNG image."
    )

    @Option(name: [.short, .long], help: "Output file path (default: screenshot.png).")
    var output: String = "screenshot.png"

    @Flag(name: .long, help: "Output as JSON with base64-encoded image.")
    var json = false

    func run() async throws {
        let capture = ScreenCapture()

        if json {
            let data = try await capture.capturePNGData()
            let base64 = data.base64EncodedString()
            let result: [String: Any] = [
                "format": "png",
                "encoding": "base64",
                "size": data.count,
                "data": base64,
            ]
            if let jsonData = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
               let str = String(data: jsonData, encoding: .utf8) {
                print(str)
            }
        } else {
            try await capture.captureToFile(path: output)
            print("Screenshot saved to \(output)")
        }
    }
}
