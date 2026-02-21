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

    @Flag(name: [.short, .long], help: "Verbose debug output.")
    var verbose = false

    func run() async throws {
        var wm = WindowManager()
        wm.verbose = verbose

        // Try AXUIElement menu action first (most reliable)
        do {
            if verbose {
                FileHandle.standardError.write(Data("[home] Trying View > Home Screen menu action\n".utf8))
            }
            try wm.goHome()

            if json {
                let result = ActionResult.ok(action: "home", data: EmptyData())
                result.printJSON()
            } else {
                print("Home gesture sent")
            }
            return
        } catch {
            if verbose {
                FileHandle.standardError.write(Data("[home] Menu action failed: \(error), falling back to tap\n".utf8))
            }
        }

        // Fallback: tap the home indicator bar
        let injector = InputInjector()
        injector.verbose = verbose
        injector.windowManager = wm
        try injector.connect()
        defer { injector.disconnect() }

        let capture = ScreenCapture(windowManager: wm)
        let content = try await capture.detectContentArea()

        if verbose {
            FileHandle.standardError.write(Data("[home] content: \(content.rect), homeIndicatorY: \(Int(content.homeIndicatorY))\n".utf8))
        }

        try injector.ensureFocus()
        let bounds = injector.windowBounds!

        let homeX = bounds.origin.x + content.rect.midX
        let homeAbsY = bounds.origin.y + content.homeIndicatorY
        if verbose {
            FileHandle.standardError.write(Data("[home] tapping home indicator at (\(Int(homeX)), \(Int(homeAbsY)))\n".utf8))
        }
        try injector.tap(x: homeX, y: homeAbsY)

        if json {
            let result = ActionResult.ok(action: "home", data: EmptyData())
            result.printJSON()
        } else {
            print("Home gesture sent")
        }
    }
}
