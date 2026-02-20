import AppKit
import CoreGraphics

public struct MirroringWindow {
    public let windowID: CGWindowID
    public let bounds: CGRect
    public let ownerPID: pid_t
    public let ownerName: String
}

public enum WindowManagerError: Error, CustomStringConvertible {
    case windowNotFound
    case cannotBringToFront

    public var description: String {
        switch self {
        case .windowNotFound:
            return "iPhone Mirroring window not found. Make sure iPhone Mirroring is running."
        case .cannotBringToFront:
            return "Could not bring iPhone Mirroring window to the foreground."
        }
    }
}

public struct WindowManager {

    private static let windowTitle = "iPhone Mirroring"
    private static let ownerName = "iPhone Mirroring"

    public init() {}

    /// Find the iPhone Mirroring window
    public func findWindow() throws -> MirroringWindow {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            throw WindowManagerError.windowNotFound
        }

        for window in windowList {
            guard let name = window[kCGWindowOwnerName as String] as? String,
                  name == Self.ownerName,
                  let windowID = window[kCGWindowNumber as String] as? CGWindowID,
                  let boundsDict = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let pid = window[kCGWindowOwnerPID as String] as? pid_t else {
                continue
            }

            let bounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            // Skip tiny windows (menu bar items, etc.)
            guard bounds.width > 100 && bounds.height > 100 else { continue }

            return MirroringWindow(
                windowID: windowID,
                bounds: bounds,
                ownerPID: pid,
                ownerName: name
            )
        }

        throw WindowManagerError.windowNotFound
    }

    /// Bring the iPhone Mirroring window to the foreground
    public func bringToFront() throws {
        let window = try findWindow()

        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            throw WindowManagerError.cannotBringToFront
        }

        let success = app.activate()
        if !success {
            throw WindowManagerError.cannotBringToFront
        }

        // Small delay to let the window come to front
        Thread.sleep(forTimeInterval: 0.3)
    }

    /// Check if iPhone Mirroring is running
    public func isAvailable() -> Bool {
        return (try? findWindow()) != nil
    }

    /// Check if Karabiner DriverKit virtual HID is loaded
    public func isKarabinerDriverLoaded() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/kextstat")
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        // DriverKit extensions won't show in kextstat. Check for the virtual HID device instead.
        let driverCheck = Process()
        driverCheck.executableURL = URL(fileURLWithPath: "/bin/ls")
        driverCheck.arguments = ["/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice"]
        let driverPipe = Pipe()
        driverCheck.standardOutput = driverPipe
        driverCheck.standardError = Pipe()

        do {
            try driverCheck.run()
            driverCheck.waitUntilExit()
            return driverCheck.terminationStatus == 0
        } catch {
            return false
        }
    }
}
