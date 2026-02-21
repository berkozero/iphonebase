import ArgumentParser
import IPhoneBaseCore
import Foundation

struct TapCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tap",
        abstract: "Tap at coordinates or on a grid cell."
    )

    @Argument(help: "X coordinate (ignored if --cell is used).")
    var x: Double?

    @Argument(help: "Y coordinate (ignored if --cell is used).")
    var y: Double?

    @Option(name: .long, help: "Tap the center of a grid cell (e.g., B3). Use with 'perceive' grid metadata.")
    var cell: String?

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
        if cell == nil && (x == nil || y == nil) {
            throw ValidationError("Provide X Y coordinates or --cell to specify a tap target.")
        }
    }

    func run() async throws {
        var wm = WindowManager()
        wm.verbose = verbose

        let injector = InputInjector()
        injector.verbose = verbose
        injector.windowManager = wm
        try injector.connect()
        defer { injector.disconnect() }

        // Ensure focus and get fresh bounds before coordinate math
        try injector.ensureFocus()
        let bounds = injector.windowBounds!

        var tapX: Double
        var tapY: Double

        if let cellLabel = cell {
            // Grid-cell-based tap — capture with grid to get cell coordinates
            let capture = ScreenCapture(windowManager: wm)
            let (_, gridInfo) = try await capture.captureWithGrid()

            guard let center = gridInfo.centerForCell(cellLabel) else {
                if json {
                    let result = ActionResult<EmptyData>(
                        success: false,
                        action: "tap",
                        error: "Unknown grid cell '\(cellLabel)'. Valid range: A1 to \(GridInfo.cellLabel(row: gridInfo.rows - 1, col: gridInfo.cols - 1))"
                    )
                    result.printJSON()
                } else {
                    print("Unknown grid cell \"\(cellLabel)\"")
                }
                throw ExitCode.failure
            }

            // Convert image coordinates to screen coordinates (image is 2x retina)
            let image = try await capture.captureWindow()
            let scaleX = bounds.width / Double(image.width)
            let scaleY = bounds.height / Double(image.height)

            tapX = bounds.origin.x + Double(center.x) * scaleX
            tapY = bounds.origin.y + Double(center.y) * scaleY

            if !json {
                print("Cell \(cellLabel.uppercased()) -> screen (\(Int(tapX)), \(Int(tapY)))")
            }
        } else {
            // Direct coordinate tap — coordinates are relative to the mirroring window
            tapX = bounds.origin.x + x!
            tapY = bounds.origin.y + y!
        }

        let actionName: String
        if long {
            try injector.longPress(x: tapX, y: tapY, durationMs: duration)
            actionName = "long_press"
        } else if double {
            try injector.doubleTap(x: tapX, y: tapY)
            actionName = "double_tap"
        } else {
            try injector.tap(x: tapX, y: tapY)
            actionName = "tap"
        }

        if json {
            let data = TapData(
                action: actionName,
                x: Int(tapX),
                y: Int(tapY),
                cell: cell?.uppercased() ?? ""
            )
            let result = ActionResult.ok(action: actionName, data: data)
            result.printJSON()
        } else if cell == nil {
            print("Tapped at (\(Int(tapX)), \(Int(tapY)))")
        }
    }
}

private struct TapData: Encodable {
    let action: String
    let x: Int
    let y: Int
    let cell: String
}
