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

    public var verbose = false

    public init() {}

    /// Find the iPhone Mirroring window.
    /// Drops to user privileges when running under sudo so the user's
    /// Screen Recording TCC permission applies.
    public func findWindow() throws -> MirroringWindow {
        guard let windowList = withUserPrivileges({
            CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
        }) as? [[String: Any]] else {
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

    /// Bring the iPhone Mirroring window to the foreground and establish input focus.
    ///
    /// Three steps, each necessary:
    /// 1. `app.activate()` requests macOS to bring the app to front
    /// 2. Poll until `app.isActive` confirms activation (not a fixed sleep)
    /// 3. CGEvent click on the window establishes the input session that
    ///    routes virtual HID events to the mirrored iPhone
    ///
    /// The CGEvent click position is the window center — safe because
    /// iPhone Mirroring blocks CGEvent from reaching the iPhone.
    public func bringToFront() throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        let window = try findWindow()

        guard let app = NSRunningApplication(processIdentifier: window.ownerPID) else {
            throw WindowManagerError.cannotBringToFront
        }

        // Check what app is currently frontmost
        let frontmost = NSWorkspace.shared.frontmostApplication
        if verbose {
            FileHandle.standardError.write(Data("[wm] bringToFront: app.isActive=\(app.isActive), pid=\(window.ownerPID), bounds=\(window.bounds)\n".utf8))
            FileHandle.standardError.write(Data("[wm] bringToFront: frontmostApp=\(frontmost?.localizedName ?? "nil") (pid=\(frontmost?.processIdentifier ?? 0))\n".utf8))
        }

        let wasActive = app.isActive

        // Step 1: Request activation
        let activateResult = app.activate()
        if verbose {
            FileHandle.standardError.write(Data("[wm] bringToFront: app.activate() returned \(activateResult)\n".utf8))
        }
        if !activateResult {
            throw WindowManagerError.cannotBringToFront
        }

        // Step 2: Poll until macOS actually activates the app (up to 2s)
        // Use RunLoop to process activation events (Thread.sleep won't update isActive in CLI)
        let deadline = Date().addingTimeInterval(2.0)
        var pollCount = 0
        while !app.isActive && Date() < deadline {
            RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
            pollCount += 1
        }

        let frontmostAfter = NSWorkspace.shared.frontmostApplication
        if verbose {
            let pollTime = CFAbsoluteTimeGetCurrent() - startTime
            FileHandle.standardError.write(Data("[wm] bringToFront: wasActive=\(wasActive), nowActive=\(app.isActive), polls=\(pollCount), pollTime=\(String(format: "%.2f", pollTime))s\n".utf8))
            FileHandle.standardError.write(Data("[wm] bringToFront: frontmostAfter=\(frontmostAfter?.localizedName ?? "nil") (pid=\(frontmostAfter?.processIdentifier ?? 0))\n".utf8))
        }

        // Step 3: CGEvent click to establish the input session — ONLY if
        // the app was not previously active.  Sending a CGEvent click when
        // the session is already established can interfere with HID routing.
        if !wasActive {
            let center = CGPoint(x: window.bounds.midX, y: window.bounds.midY)
            if verbose {
                FileHandle.standardError.write(Data("[wm] bringToFront: CGEvent click target=(\(center.x), \(center.y)) [window center]\n".utf8))
            }

            CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
            CGWarpMouseCursorPosition(center)
            usleep(50_000)

            let mouseDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: center, mouseButton: .left)
            let mouseUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: center, mouseButton: .left)

            if let mouseDown = mouseDown, let mouseUp = mouseUp {
                mouseDown.post(tap: .cghidEventTap)
                usleep(50_000)
                mouseUp.post(tap: .cghidEventTap)
                if verbose { FileHandle.standardError.write(Data("[wm] bringToFront: CGEvent mouseDown+mouseUp posted OK\n".utf8)) }
            } else {
                if verbose { FileHandle.standardError.write(Data("[wm] bringToFront: CGEvent creation FAILED (mouseDown=\(mouseDown != nil), mouseUp=\(mouseUp != nil))\n".utf8)) }
            }

            CGAssociateMouseAndMouseCursorPosition(boolean_t(1))

            // Wait for the input session to establish — poll isActive again
            // since the CGEvent click should cause macOS to fully activate the window
            let settleStart = CFAbsoluteTimeGetCurrent()
            let settleDeadline = Date().addingTimeInterval(1.0)
            var settlePolls = 0
            while !app.isActive && Date() < settleDeadline {
                RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 0.05))
                settlePolls += 1
            }

            if verbose {
                let settleTime = CFAbsoluteTimeGetCurrent() - settleStart
                let totalTime = CFAbsoluteTimeGetCurrent() - startTime
                FileHandle.standardError.write(Data("[wm] bringToFront: post-CGEvent settle: active=\(app.isActive), polls=\(settlePolls), settleTime=\(String(format: "%.2f", settleTime))s, totalTime=\(String(format: "%.2f", totalTime))s\n".utf8))
            }
        } else {
            if verbose { FileHandle.standardError.write(Data("[wm] bringToFront: already active, skipping CGEvent\n".utf8)) }
            // Brief pause for window server consistency
            Thread.sleep(forTimeInterval: 0.1)
        }
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
