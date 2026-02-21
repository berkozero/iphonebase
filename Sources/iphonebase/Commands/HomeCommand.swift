import ArgumentParser
import IPhoneBaseCore
import Foundation

struct HomeCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "home",
        abstract: "Press the home button (go to home screen)."
    )

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

        // Swipe up from bottom of the mirroring window (simulates home gesture on Face ID iPhones)
        let centerX = bounds.origin.x + bounds.width / 2
        let bottomY = bounds.origin.y + bounds.height - 20

        try injector.swipe(
            direction: .up,
            fromX: centerX,
            fromY: bottomY,
            distance: bounds.height * 0.4,
            steps: 15
        )

        if json {
            let result = ActionResult.ok(action: "home", data: EmptyData())
            result.printJSON()
        } else {
            print("Home gesture sent")
        }
    }
}
