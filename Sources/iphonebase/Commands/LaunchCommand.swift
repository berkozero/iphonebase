import ArgumentParser
import IPhoneBaseCore
import Foundation

struct LaunchCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "launch",
        abstract: "Launch an app by name using Spotlight search."
    )

    @Argument(help: "App name to search for and launch.")
    var appName: String

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() async throws {
        let wm = WindowManager()
        let window = try wm.findWindow()
        try wm.bringToFront()

        let injector = InputInjector()
        try injector.connect()
        defer { injector.disconnect() }

        // Step 1: Go home first
        let centerX = window.bounds.origin.x + window.bounds.width / 2
        let bottomY = window.bounds.origin.y + window.bounds.height - 20
        try injector.swipe(
            direction: .up,
            fromX: centerX,
            fromY: bottomY,
            distance: window.bounds.height * 0.4,
            steps: 15
        )
        usleep(500_000)  // Wait for home screen

        // Step 2: Swipe down from center to open Spotlight
        let centerY = window.bounds.origin.y + window.bounds.height / 2
        try injector.swipe(
            direction: .down,
            fromX: centerX,
            fromY: centerY,
            distance: 150,
            steps: 10
        )
        usleep(800_000)  // Wait for Spotlight to appear

        // Step 3: Type the app name
        try injector.typeText(appName)
        usleep(1_000_000)  // Wait for search results

        // Step 4: Tap the first result (top of search results area)
        // Spotlight results appear below the search bar, roughly 40% from top
        let resultY = window.bounds.origin.y + window.bounds.height * 0.35
        try injector.tap(x: centerX, y: resultY)

        if json {
            let result: [String: Any] = [
                "action": "launch",
                "app": appName,
            ]
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("Launched \"\(appName)\"")
        }
    }
}
