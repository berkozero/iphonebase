import ArgumentParser
import IPhoneBaseCore
import Foundation

struct SwipeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "swipe",
        abstract: "Swipe in a direction on the iPhone screen."
    )

    @Argument(help: "Swipe direction: up, down, left, right.")
    var direction: SwipeDirection

    @Option(name: .long, help: "Start point as x,y (default: center of screen).")
    var from: String?

    @Option(name: .long, help: "Swipe distance in points (default: 300).")
    var distance: Double = 300

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() async throws {
        let wm = WindowManager()

        let injector = InputInjector()
        injector.windowManager = wm
        try injector.connect()
        defer { injector.disconnect() }

        // Ensure focus and get fresh bounds before coordinate math
        try injector.ensureFocus()
        let bounds = injector.windowBounds!

        let startX: Double
        let startY: Double

        if let fromStr = from {
            let parts = fromStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 2 else {
                throw ValidationError("--from must be in format x,y (e.g., --from 200,400)")
            }
            startX = bounds.origin.x + parts[0]
            startY = bounds.origin.y + parts[1]
        } else {
            // Default: center of window
            startX = bounds.origin.x + bounds.width / 2
            startY = bounds.origin.y + bounds.height / 2
        }

        try injector.swipe(direction: direction, fromX: startX, fromY: startY, distance: distance)

        if json {
            let data = SwipeData(
                direction: direction.rawValue,
                fromX: Int(startX),
                fromY: Int(startY),
                distance: Int(distance)
            )
            let result = ActionResult.ok(action: "swipe", data: data)
            result.printJSON()
        } else {
            print("Swiped \(direction.rawValue) from (\(Int(startX)), \(Int(startY))) distance \(Int(distance))")
        }
    }
}

extension SwipeDirection: ExpressibleByArgument {}

private struct SwipeData: Encodable {
    let direction: String
    let fromX: Int
    let fromY: Int
    let distance: Int

    enum CodingKeys: String, CodingKey {
        case direction
        case fromX = "from_x"
        case fromY = "from_y"
        case distance
    }
}
