import ArgumentParser
import IPhoneBaseCore
import Foundation
import CoreGraphics

struct ScrollCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scroll",
        abstract: "Scroll up or down on the iPhone screen."
    )

    @Argument(help: "Scroll direction: up or down.")
    var direction: ScrollDirection

    @Option(name: .long, help: "Number of scroll clicks (default: 3).")
    var clicks: Int = 3

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

        // Move cursor to center of mirroring window for scroll context
        let centerX = bounds.origin.x + bounds.width / 2
        let centerY = bounds.origin.y + bounds.height / 2
        CGWarpMouseCursorPosition(CGPoint(x: centerX, y: centerY))
        usleep(30_000)

        try injector.scroll(direction: direction, clicks: clicks)

        if json {
            let data = ScrollData(direction: direction.rawValue, clicks: clicks)
            let result = ActionResult.ok(action: "scroll", data: data)
            result.printJSON()
        } else {
            print("Scrolled \(direction.rawValue) (\(clicks) clicks)")
        }
    }
}

extension ScrollDirection: ExpressibleByArgument {}

private struct ScrollData: Encodable {
    let direction: String
    let clicks: Int
}
