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
        let window = try wm.findWindow()
        try wm.bringToFront()

        let injector = InputInjector()
        try injector.connect()
        defer { injector.disconnect() }

        // Swipe up from bottom of the mirroring window (simulates home gesture on Face ID iPhones)
        let centerX = window.bounds.origin.x + window.bounds.width / 2
        let bottomY = window.bounds.origin.y + window.bounds.height - 20

        try injector.swipe(
            direction: .up,
            fromX: centerX,
            fromY: bottomY,
            distance: window.bounds.height * 0.4,
            steps: 15
        )

        if json {
            print(#"{"action": "home"}"#)
        } else {
            print("Home gesture sent")
        }
    }
}
