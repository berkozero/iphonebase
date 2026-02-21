import ArgumentParser
import IPhoneBaseCore
import Foundation

struct DragCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "drag",
        abstract: "Drag from one point to another on the iPhone screen."
    )

    @Argument(help: "Start X coordinate (relative to mirroring window).")
    var fromX: Double

    @Argument(help: "Start Y coordinate (relative to mirroring window).")
    var fromY: Double

    @Argument(help: "End X coordinate (relative to mirroring window).")
    var toX: Double

    @Argument(help: "End Y coordinate (relative to mirroring window).")
    var toY: Double

    @Option(name: .long, help: "Number of intermediate steps (default: 20).")
    var steps: Int = 20

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    @Flag(name: [.short, .long], help: "Verbose debug output.")
    var verbose = false

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

        let absFromX = bounds.origin.x + fromX
        let absFromY = bounds.origin.y + fromY
        let absToX = bounds.origin.x + toX
        let absToY = bounds.origin.y + toY

        try injector.drag(fromX: absFromX, fromY: absFromY, toX: absToX, toY: absToY, steps: steps)

        if json {
            let data = DragData(
                fromX: Int(fromX), fromY: Int(fromY),
                toX: Int(toX), toY: Int(toY),
                steps: steps
            )
            let result = ActionResult.ok(action: "drag", data: data)
            result.printJSON()
        } else {
            print("Dragged from (\(Int(fromX)), \(Int(fromY))) to (\(Int(toX)), \(Int(toY)))")
        }
    }
}

private struct DragData: Encodable {
    let fromX: Int
    let fromY: Int
    let toX: Int
    let toY: Int
    let steps: Int

    enum CodingKeys: String, CodingKey {
        case fromX = "from_x"
        case fromY = "from_y"
        case toX = "to_x"
        case toY = "to_y"
        case steps
    }
}
