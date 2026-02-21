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

        let injector = InputInjector()
        injector.windowManager = wm
        try injector.connect()
        defer { injector.disconnect() }

        let capture = ScreenCapture(windowManager: wm)
        let ocr = OCREngine()

        // Step 1: Go home first — ensure focus and get fresh bounds
        try injector.ensureFocus()
        var bounds = injector.windowBounds!

        let centerX = bounds.origin.x + bounds.width / 2
        let bottomY = bounds.origin.y + bounds.height - 20
        try injector.swipe(
            direction: .up,
            fromX: centerX,
            fromY: bottomY,
            distance: bounds.height * 0.4,
            steps: 15
        )
        usleep(1_000_000)  // Wait for home screen

        // Step 2: Swipe down from center to open Spotlight, verify with OCR
        try injector.ensureFocus()
        bounds = injector.windowBounds!

        let centerY = bounds.origin.y + bounds.height / 2
        let spotlightCenterX = bounds.origin.x + bounds.width / 2
        var spotlightOpened = false
        for attempt in 1...3 {
            try injector.swipe(
                direction: .down,
                fromX: spotlightCenterX,
                fromY: centerY,
                distance: 200,
                steps: 15
            )

            // Wait for Spotlight search field to appear
            if let _ = await ocr.waitForText(
                matching: "Search",
                capture: capture,
                timeout: 2,
                interval: 0.3
            ) {
                spotlightOpened = true
                break
            }

            if !json {
                FileHandle.standardError.write(Data("Spotlight not detected, retrying... (attempt \(attempt)/3)\n".utf8))
            }
        }

        guard spotlightOpened else {
            if json {
                let result = ActionResult<EmptyData>(
                    success: false,
                    action: "launch",
                    error: "Failed to open Spotlight after 3 attempts"
                )
                result.printJSON()
            } else {
                print("Failed to open Spotlight after 3 attempts")
            }
            throw ExitCode.failure
        }

        // Step 3: Type the app name
        try injector.typeText(appName)

        // Step 4: Wait for search results to appear, then tap the app
        try injector.ensureFocus()
        bounds = injector.windowBounds!

        if let match = await ocr.waitForText(
            matching: appName,
            capture: capture,
            timeout: 3,
            interval: 0.3
        ) {
            // Convert image coordinates to screen coordinates
            let image = try await capture.captureWindow()
            let scaleX = bounds.width / Double(image.width)
            let scaleY = bounds.height / Double(image.height)

            let tapX = bounds.origin.x + Double(match.centerX) * scaleX
            let tapY = bounds.origin.y + Double(match.centerY) * scaleY
            try injector.tap(x: tapX, y: tapY)
        } else {
            // Fallback: tap at approximate first-result position
            let resultY = bounds.origin.y + bounds.height * 0.35
            let fallbackCenterX = bounds.origin.x + bounds.width / 2
            try injector.tap(x: fallbackCenterX, y: resultY)
        }

        if json {
            let data = LaunchData(app: appName)
            let result = ActionResult.ok(action: "launch", data: data)
            result.printJSON()
        } else {
            print("Launched \"\(appName)\"")
        }
    }
}

private struct LaunchData: Encodable {
    let app: String
}
