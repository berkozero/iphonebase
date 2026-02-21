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
    case menuActionFailed(String)

    public var description: String {
        switch self {
        case .windowNotFound:
            return "iPhone Mirroring window not found. Make sure iPhone Mirroring is running."
        case .cannotBringToFront:
            return "Could not bring iPhone Mirroring window to the foreground."
        case .menuActionFailed(let detail):
            return "Menu action failed: \(detail). Make sure Accessibility permission is granted."
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

    /// Check if the given PID is the frontmost application.
    /// Uses NSWorkspace which works reliably in CLI apps (unlike NSRunningApplication.isActive
    /// which requires an AppKit event loop to update).
    private func isFrontmost(pid: pid_t) -> Bool {
        return NSWorkspace.shared.frontmostApplication?.processIdentifier == pid
    }

    /// Bring the iPhone Mirroring window to the foreground and establish input focus.
    ///
    /// Steps:
    /// 1. If already frontmost, return immediately (fast path)
    /// 2. `app.activate()` to bring window to front
    /// 3. CGEvent click at a **safe zone** inside the iPhone content area to establish
    ///    the HID input session. The safe zone is the iOS status bar (clock/battery area),
    ///    which is safe to click (worst case: scrolls content to top).
    ///
    /// The CGEvent click must land **inside** the iPhone content area — clicking the
    /// macOS title bar focuses the window but does NOT establish the HID input session.
    /// Clicking the status bar is safe; clicking deeper in the content area would interact
    /// with the mirrored iPhone UI.
    ///
    public func bringToFront() throws {
        let window = try findWindow()
        let wasAlreadyFrontmost = isFrontmost(pid: window.ownerPID)

        if verbose {
            let frontName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil"
            FileHandle.standardError.write(Data("[wm] bringToFront: wasAlreadyFrontmost=\(wasAlreadyFrontmost), frontmostApp=\(frontName), bounds=\(window.bounds)\n".utf8))
        }

        if !wasAlreadyFrontmost {
            // Use AppleScript via System Events for cross-Space activation.
            // NSRunningApplication.activate() cannot trigger a macOS Space switch.
            let script = NSAppleScript(source: """
                tell application "System Events"
                    tell process "iPhone Mirroring"
                        set frontmost to true
                    end tell
                end tell
            """)
            var errorInfo: NSDictionary?
            script?.executeAndReturnError(&errorInfo)

            if verbose {
                if let error = errorInfo {
                    FileHandle.standardError.write(Data("[wm] bringToFront: AppleScript error: \(error)\n".utf8))
                } else {
                    FileHandle.standardError.write(Data("[wm] bringToFront: AppleScript set frontmost\n".utf8))
                }
            }

            // Fallback to NSRunningApplication.activate() if AppleScript failed
            if !isFrontmost(pid: window.ownerPID) {
                if let app = NSRunningApplication(processIdentifier: window.ownerPID) {
                    let activated = app.activate()
                    if verbose { FileHandle.standardError.write(Data("[wm] bringToFront: fallback app.activate() returned \(activated)\n".utf8)) }
                }
            }
        }

        // Always wait for HID session to be ready. Even when already frontmost,
        // each CLI invocation creates new Karabiner virtual HID devices that need
        // time to register with iPhone Mirroring's input routing.
        let settleTime: TimeInterval = wasAlreadyFrontmost ? 0.3 : 0.5
        Thread.sleep(forTimeInterval: settleTime)

        if verbose {
            let nowFrontmost = isFrontmost(pid: window.ownerPID)
            FileHandle.standardError.write(Data("[wm] bringToFront: after settle, frontmost=\(nowFrontmost)\n".utf8))
        }
    }

    /// Check if iPhone Mirroring is running
    public func isAvailable() -> Bool {
        return (try? findWindow()) != nil
    }

    // MARK: - AXUIElement Menu Actions

    /// Trigger a menu bar action on the iPhone Mirroring app via Accessibility API.
    /// Navigates: App → MenuBar → Menu (menuName) → MenuItem (itemName) → AXPress.
    /// Requires Accessibility permission for the calling process.
    public func triggerMenuAction(menu menuName: String, item itemName: String) throws {
        let window = try findWindow()
        let appElement = AXUIElementCreateApplication(window.ownerPID)

        // Get the menu bar
        var menuBarValue: CFTypeRef?
        let menuBarResult = AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarValue)
        guard menuBarResult == .success, let menuBar = menuBarValue else {
            throw WindowManagerError.menuActionFailed("Could not access menu bar (AXError: \(menuBarResult.rawValue))")
        }

        // Get menu bar items
        var menuItemsValue: CFTypeRef?
        let menuItemsResult = AXUIElementCopyAttributeValue(menuBar as! AXUIElement, kAXChildrenAttribute as CFString, &menuItemsValue)
        guard menuItemsResult == .success, let menuItems = menuItemsValue as? [AXUIElement] else {
            throw WindowManagerError.menuActionFailed("Could not list menu bar items")
        }

        // Find the target menu (e.g., "View")
        var targetMenu: AXUIElement?
        for item in menuItems {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleValue)
            if let title = titleValue as? String, title == menuName {
                targetMenu = item
                break
            }
        }

        guard let menu = targetMenu else {
            throw WindowManagerError.menuActionFailed("Menu '\(menuName)' not found")
        }

        // Open the menu to reveal its items
        AXUIElementPerformAction(menu, kAXPressAction as CFString)
        usleep(100_000)  // 100ms for menu to open

        // Get submenu items
        var submenuValue: CFTypeRef?
        AXUIElementCopyAttributeValue(menu, kAXChildrenAttribute as CFString, &submenuValue)
        guard let submenus = submenuValue as? [AXUIElement], let firstSubmenu = submenus.first else {
            throw WindowManagerError.menuActionFailed("Menu '\(menuName)' has no submenu")
        }

        var submenuItemsValue: CFTypeRef?
        AXUIElementCopyAttributeValue(firstSubmenu, kAXChildrenAttribute as CFString, &submenuItemsValue)
        guard let submenuItems = submenuItemsValue as? [AXUIElement] else {
            throw WindowManagerError.menuActionFailed("Could not list items in '\(menuName)' menu")
        }

        // Find the target item (e.g., "Spotlight")
        var targetItem: AXUIElement?
        for item in submenuItems {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(item, kAXTitleAttribute as CFString, &titleValue)
            if let title = titleValue as? String {
                if verbose { FileHandle.standardError.write(Data("[wm] Menu item: '\(title)'\n".utf8)) }
                if title == itemName {
                    targetItem = item
                    break
                }
            }
        }

        guard let menuItem = targetItem else {
            // Cancel the open menu
            let escEvent = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: true)
            escEvent?.post(tap: .cghidEventTap)
            usleep(10_000)
            let escUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x35, keyDown: false)
            escUp?.post(tap: .cghidEventTap)
            throw WindowManagerError.menuActionFailed("Item '\(itemName)' not found in '\(menuName)' menu")
        }

        // Press the menu item
        let pressResult = AXUIElementPerformAction(menuItem, kAXPressAction as CFString)
        if pressResult != .success {
            throw WindowManagerError.menuActionFailed("Failed to press '\(itemName)' (AXError: \(pressResult.rawValue))")
        }

        if verbose { FileHandle.standardError.write(Data("[wm] Triggered menu action: \(menuName) > \(itemName)\n".utf8)) }
    }

    /// Open Spotlight search on the mirrored iPhone via View > Spotlight menu.
    public func openSpotlight() throws {
        try bringToFront()
        try triggerMenuAction(menu: "View", item: "Spotlight")
    }

    /// Go to iPhone home screen via View > Home Screen menu.
    public func goHome() throws {
        try bringToFront()
        try triggerMenuAction(menu: "View", item: "Home Screen")
    }

    /// Open App Switcher on the mirrored iPhone via View > App Switcher menu.
    public func openAppSwitcher() throws {
        try bringToFront()
        try triggerMenuAction(menu: "View", item: "App Switcher")
    }

    // MARK: - Driver Check

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
