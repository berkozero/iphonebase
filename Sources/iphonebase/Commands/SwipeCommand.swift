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
        let window = try wm.findWindow()

        let startX: Double
        let startY: Double

        if let fromStr = from {
            let parts = fromStr.split(separator: ",").compactMap { Double($0.trimmingCharacters(in: .whitespaces)) }
            guard parts.count == 2 else {
                throw ValidationError("--from must be in format x,y (e.g., --from 200,400)")
            }
            startX = window.bounds.origin.x + parts[0]
            startY = window.bounds.origin.y + parts[1]
        } else {
            // Default: center of window
            startX = window.bounds.origin.x + window.bounds.width / 2
            startY = window.bounds.origin.y + window.bounds.height / 2
        }

        try wm.bringToFront()

        let injector = InputInjector()
        try injector.connect()
        defer { injector.disconnect() }

        try injector.swipe(direction: direction, fromX: startX, fromY: startY, distance: distance)

        if json {
            let result: [String: Any] = [
                "action": "swipe",
                "direction": direction.rawValue,
                "from_x": Int(startX),
                "from_y": Int(startY),
                "distance": Int(distance),
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("Swiped \(direction.rawValue) from (\(Int(startX)), \(Int(startY))) distance \(Int(distance))")
        }
    }
}

extension SwipeDirection: ExpressibleByArgument {}
