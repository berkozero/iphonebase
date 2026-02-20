import ArgumentParser
import IPhoneBaseCore
import Foundation

struct StatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        abstract: "Check if iPhone Mirroring is available and dependencies are met."
    )

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() throws {
        let wm = WindowManager()

        let mirroringAvailable = wm.isAvailable()
        let karabinerInstalled = wm.isKarabinerDriverLoaded()

        var windowInfo: [String: Any]?
        if let window = try? wm.findWindow() {
            windowInfo = [
                "windowID": window.windowID,
                "x": Int(window.bounds.origin.x),
                "y": Int(window.bounds.origin.y),
                "width": Int(window.bounds.width),
                "height": Int(window.bounds.height),
            ]
        }

        if json {
            var result: [String: Any] = [
                "iphone_mirroring": mirroringAvailable,
                "karabiner_driver": karabinerInstalled,
            ]
            if let info = windowInfo {
                result["window"] = info
            }
            if let data = try? JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys]),
               let str = String(data: data, encoding: .utf8) {
                print(str)
            }
        } else {
            print("iPhone Mirroring: \(mirroringAvailable ? "active" : "not found")")
            print("Karabiner Driver: \(karabinerInstalled ? "installed" : "not found")")

            if let info = windowInfo {
                print("Window: \(info["width"]!)x\(info["height"]!) at (\(info["x"]!), \(info["y"]!))")
            }

            if !mirroringAvailable {
                print("\nOpen iPhone Mirroring on your Mac and connect your iPhone.")
            }
            if !karabinerInstalled {
                print("\nInstall Karabiner-Elements: https://karabiner-elements.pqrs.org/")
            }
            if mirroringAvailable && karabinerInstalled {
                print("\nReady to go.")
            }
        }
    }
}
