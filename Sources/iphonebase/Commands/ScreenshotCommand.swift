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

    @Flag(name: .long, help: "Draw a labeled grid overlay (A1, B2, ...) for vision-model agents.")
    var grid = false

    @Option(name: .long, help: "Number of grid rows (default: auto-sized to ~44pt cells).")
    var rows: Int?

    @Option(name: .long, help: "Number of grid columns (default: auto-sized to ~44pt cells).")
    var cols: Int?

    @Flag(name: .long, help: "Output as JSON with base64-encoded image.")
    var json = false

    func run() async throws {
        let capture = ScreenCapture()

        if grid {
            let (gridImage, gridInfo) = try await capture.captureWithGrid(rows: rows, cols: cols)

            if json {
                let data = try capture.imageToData(gridImage)
                let payload = GridScreenshotData(
                    format: "png",
                    encoding: "base64",
                    size: data.count,
                    data: data.base64EncodedString(),
                    grid: gridInfo
                )
                let result = ActionResult.ok(action: "screenshot", data: payload)
                result.printJSON()
            } else {
                try capture.saveImage(gridImage, to: output)
                print("Screenshot with grid (\(gridInfo.rows)x\(gridInfo.cols)) saved to \(output)")
            }
        } else if json {
            var ms = 0
            var screenshotData: ScreenshotData?
            ms = try await measureMs {
                let data = try await capture.capturePNGData()
                screenshotData = ScreenshotData(
                    format: "png",
                    encoding: "base64",
                    size: data.count,
                    data: data.base64EncodedString()
                )
            }
            let result = ActionResult.ok(action: "screenshot", data: screenshotData!, durationMs: ms)
            result.printJSON()
        } else {
            try await capture.captureToFile(path: output)
            print("Screenshot saved to \(output)")
        }
    }
}

private struct ScreenshotData: Encodable {
    let format: String
    let encoding: String
    let size: Int
    let data: String
}

private struct GridScreenshotData: Encodable {
    let format: String
    let encoding: String
    let size: Int
    let data: String
    let grid: GridInfo
}
