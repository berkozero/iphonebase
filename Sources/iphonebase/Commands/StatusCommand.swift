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

        var windowInfo: WindowData?
        if let window = try? wm.findWindow() {
            windowInfo = WindowData(
                windowID: window.windowID,
                x: Int(window.bounds.origin.x),
                y: Int(window.bounds.origin.y),
                width: Int(window.bounds.width),
                height: Int(window.bounds.height)
            )
        }

        if json {
            let data = StatusData(
                iphoneMirroring: mirroringAvailable,
                karabinerDriver: karabinerInstalled,
                window: windowInfo
            )
            let result = ActionResult.ok(action: "status", data: data)
            result.printJSON()
        } else {
            print("iPhone Mirroring: \(mirroringAvailable ? "active" : "not found")")
            print("Karabiner Driver: \(karabinerInstalled ? "installed" : "not found")")

            if let info = windowInfo {
                print("Window: \(info.width)x\(info.height) at (\(info.x), \(info.y))")
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

private struct StatusData: Encodable {
    let iphoneMirroring: Bool
    let karabinerDriver: Bool
    let window: WindowData?

    enum CodingKeys: String, CodingKey {
        case iphoneMirroring = "iphone_mirroring"
        case karabinerDriver = "karabiner_driver"
        case window
    }
}

private struct WindowData: Encodable {
    let windowID: UInt32
    let x: Int
    let y: Int
    let width: Int
    let height: Int

    enum CodingKeys: String, CodingKey {
        case windowID = "window_id"
        case x, y, width, height
    }
}
