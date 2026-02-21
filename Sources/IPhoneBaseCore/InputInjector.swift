import Foundation
import CoreGraphics

// MARK: - Binary Report Structs

/// Karabiner virtual HID pointing report (8 bytes)
struct PointingReport {
    var buttons: UInt32 = 0
    var x: Int8 = 0
    var y: Int8 = 0
    var verticalWheel: Int8 = 0
    var horizontalWheel: Int8 = 0

    func toBytes() -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: 8)
        buf[0] = UInt8(buttons & 0xFF)
        buf[1] = UInt8((buttons >> 8) & 0xFF)
        buf[2] = UInt8((buttons >> 16) & 0xFF)
        buf[3] = UInt8((buttons >> 24) & 0xFF)
        buf[4] = UInt8(bitPattern: x)
        buf[5] = UInt8(bitPattern: y)
        buf[6] = UInt8(bitPattern: verticalWheel)
        buf[7] = UInt8(bitPattern: horizontalWheel)
        return buf
    }
}

/// Karabiner virtual HID keyboard report (67 bytes)
struct KeyboardReport {
    var reportID: UInt8 = 1
    var modifiers: UInt8 = 0
    var reserved: UInt8 = 0
    var keys: (UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
               UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
               UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16,
               UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16, UInt16) =
        (0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0, 0,0,0,0,0,0,0,0)

    mutating func insertKey(_ keyCode: UInt16) {
        withUnsafeMutableBytes(of: &keys) { buf in
            for i in stride(from: 0, to: buf.count, by: 2) {
                let v = UInt16(buf[i]) | (UInt16(buf[i + 1]) << 8)
                if v == keyCode { return }
            }
            for i in stride(from: 0, to: buf.count, by: 2) {
                let v = UInt16(buf[i]) | (UInt16(buf[i + 1]) << 8)
                if v == 0 {
                    buf[i] = UInt8(keyCode & 0xFF)
                    buf[i + 1] = UInt8(keyCode >> 8)
                    return
                }
            }
        }
    }

    func toBytes() -> [UInt8] {
        var buf = [UInt8](repeating: 0, count: 67)
        buf[0] = reportID
        buf[1] = modifiers
        buf[2] = reserved
        withUnsafeBytes(of: keys) { raw in
            for i in 0..<64 { buf[3 + i] = raw[i] }
        }
        return buf
    }
}

// MARK: - Karabiner Client

public enum InputInjectorError: Error, CustomStringConvertible {
    case karabinerNotInstalled
    case noServerSocket
    case connectionFailed(String)
    case notConnected
    case outOfBounds(x: Double, y: Double, bounds: CGRect)

    public var description: String {
        switch self {
        case .karabinerNotInstalled:
            return "Karabiner DriverKit VirtualHIDDevice not found. Install Karabiner-Elements from https://karabiner-elements.pqrs.org/"
        case .noServerSocket:
            return "No Karabiner daemon socket found. Make sure Karabiner-Elements is running."
        case .connectionFailed(let reason):
            return "Failed to connect to Karabiner daemon: \(reason)"
        case .notConnected:
            return "Not connected to Karabiner daemon. Call connect() first."
        case .outOfBounds(let x, let y, let bounds):
            return "Coordinates (\(Int(x)), \(Int(y))) are outside the mirroring window bounds (\(Int(bounds.origin.x)),\(Int(bounds.origin.y)))-(\(Int(bounds.maxX)),\(Int(bounds.maxY)))"
        }
    }
}

/// Validate that a point falls within bounds. Throws outOfBounds if not.
func validatePointInBounds(x: Double, y: Double, bounds: CGRect?) throws {
    guard let bounds = bounds else { return }
    if !bounds.contains(CGPoint(x: x, y: y)) {
        throw InputInjectorError.outOfBounds(x: x, y: y, bounds: bounds)
    }
}

public final class InputInjector {

    private var sockfd: Int32 = -1
    private var clientSocketPath: String = ""
    private var connected = false
    private var heartbeatSource: DispatchSourceTimer?
    public var verbose = false

    /// When set, InputInjector will re-acquire window bounds and focus before every
    /// input operation. This handles window moves and focus loss automatically.
    public var windowManager: WindowManager?

    /// Current mirroring window bounds (absolute screen coordinates, screen points).
    /// Refreshed automatically before each input operation when windowManager is set.
    /// Can also be set manually to enable coordinate validation without auto-focus.
    public var windowBounds: CGRect?

    /// Timestamp of last ensureFocus() call — used to avoid redundant CGEvent clicks
    /// that can disrupt the input session iPhone Mirroring just established.
    private var lastFocusTime: CFAbsoluteTime = 0
    private static let focusCooldown: CFAbsoluteTime = 5.0

    private static let serverDir = "/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"
    private static let clientDir = "/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_client"
    private static let protocolVersion: UInt16 = 5

    // Request codes matching Karabiner's binary protocol
    private enum Request: UInt8 {
        case keyboardInitialize = 1
        case keyboardTerminate  = 2
        case keyboardReset      = 3
        case pointingInitialize = 4
        case pointingTerminate  = 5
        case pointingReset      = 6
        case postKeyboardReport = 7
        case postConsumerReport = 8
        case postAppleVendorKB  = 9
        case postAppleVendorTC  = 10
        case postGenericDesktop = 11
        case postPointingReport = 12
    }

    public init() {}

    deinit {
        disconnect()
    }

    // MARK: - Connection

    /// Connect to Karabiner DriverKit daemon via Unix domain socket
    public func connect() throws {
        // Verify Karabiner is installed
        let driverPath = "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice"
        guard FileManager.default.fileExists(atPath: driverPath) else {
            throw InputInjectorError.karabinerNotInstalled
        }

        // Find server socket
        let fm = FileManager.default
        guard let sockFiles = try? fm.contentsOfDirectory(atPath: Self.serverDir)
            .filter({ $0.hasSuffix(".sock") })
            .sorted(),
              let serverSock = sockFiles.last else {
            throw InputInjectorError.noServerSocket
        }
        let serverPath = "\(Self.serverDir)/\(serverSock)"

        // Create DGRAM socket
        sockfd = socket(AF_UNIX, SOCK_DGRAM, 0)
        guard sockfd >= 0 else {
            throw InputInjectorError.connectionFailed("Could not create socket")
        }

        // Bind client socket
        clientSocketPath = "\(Self.clientDir)/\(ProcessInfo.processInfo.processIdentifier)_\(UInt64(Date().timeIntervalSince1970 * 1e9)).sock"

        var clientAddr = sockaddr_un()
        clientAddr.sun_family = sa_family_t(AF_UNIX)
        setSocketPath(&clientAddr, clientSocketPath)

        let bindResult = withUnsafePointer(to: &clientAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                bind(sockfd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bindResult == 0 else {
            close(sockfd)
            throw InputInjectorError.connectionFailed("Bind failed (errno \(errno)). Try running with sudo.")
        }

        // Connect to server with retry (daemon socket can be briefly unavailable)
        var serverAddr = sockaddr_un()
        serverAddr.sun_family = sa_family_t(AF_UNIX)
        setSocketPath(&serverAddr, serverPath)

        let maxAttempts = 3
        var lastErrno: Int32 = 0
        for attempt in 1...maxAttempts {
            let connectResult = withUnsafePointer(to: &serverAddr) { ptr in
                ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sa in
                    Foundation.connect(sockfd, sa, socklen_t(MemoryLayout<sockaddr_un>.size))
                }
            }
            if connectResult == 0 { break }

            lastErrno = errno
            if attempt < maxAttempts {
                if verbose { FileHandle.standardError.write(Data("[iphonebase] Connect attempt \(attempt)/\(maxAttempts) failed, retrying...\n".utf8)) }
                usleep(500_000)  // 500ms backoff
            } else {
                close(sockfd)
                unlink(clientSocketPath)
                throw InputInjectorError.connectionFailed("Connect failed after \(maxAttempts) attempts (errno \(lastErrno)). Try running with sudo.")
            }
        }

        connected = true
        if verbose { FileHandle.standardError.write(Data("[iphonebase] Socket connected\n".utf8)) }

        // Initialize virtual devices
        initializeDevices()
        if verbose { FileHandle.standardError.write(Data("[iphonebase] Virtual devices initialized\n".utf8)) }

        // Start heartbeat
        startHeartbeat()

        // Wait for devices to be ready
        usleep(1_000_000) // 1s — give daemon time to register virtual devices
        if verbose { FileHandle.standardError.write(Data("[iphonebase] Ready\n".utf8)) }
    }

    /// Disconnect and clean up
    public func disconnect() {
        heartbeatSource?.cancel()
        heartbeatSource = nil

        if sockfd >= 0 {
            close(sockfd)
            sockfd = -1
        }
        if !clientSocketPath.isEmpty {
            unlink(clientSocketPath)
            clientSocketPath = ""
        }
        connected = false
    }

    // MARK: - High-level Input Operations

    /// Validate that a point falls within the window bounds (if set)
    private func validatePoint(x: Double, y: Double) throws {
        try validatePointInBounds(x: x, y: y, bounds: windowBounds)
    }

    /// Re-acquire window bounds and focus before an input operation.
    /// Called automatically at the start of every HID input method.
    /// If windowManager is nil, this is a no-op (backward compatible).
    ///
    /// Uses a cooldown to avoid sending redundant CGEvent focus clicks that can
    /// disrupt the input session iPhone Mirroring just established. Window bounds
    /// are always refreshed (cheap), but bringToFront() is skipped if called
    /// within the cooldown period.
    public func ensureFocus() throws {
        guard let wm = windowManager else { return }
        let focusStart = CFAbsoluteTimeGetCurrent()
        let window = try wm.findWindow()
        windowBounds = window.bounds

        let now = CFAbsoluteTimeGetCurrent()
        let elapsed = now - lastFocusTime
        if elapsed > Self.focusCooldown {
            if verbose { FileHandle.standardError.write(Data("[iphonebase] ensureFocus: calling bringToFront (elapsed=\(String(format: "%.1f", elapsed))s)\n".utf8)) }
            try wm.bringToFront()
            lastFocusTime = CFAbsoluteTimeGetCurrent()
            if verbose {
                let focusDuration = CFAbsoluteTimeGetCurrent() - focusStart
                FileHandle.standardError.write(Data("[iphonebase] ensureFocus: bringToFront took \(String(format: "%.2f", focusDuration))s\n".utf8))
            }
        } else {
            if verbose { FileHandle.standardError.write(Data("[iphonebase] ensureFocus: cooldown active (elapsed=\(String(format: "%.1f", elapsed))s), bounds refreshed\n".utf8)) }
        }
    }

    /// Tap at absolute screen coordinates
    public func tap(x: Double, y: Double) throws {
        guard connected else { throw InputInjectorError.notConnected }
        let tapStart = CFAbsoluteTimeGetCurrent()
        try ensureFocus()
        let afterFocus = CFAbsoluteTimeGetCurrent()
        try validatePoint(x: x, y: y)

        let point = CGPoint(x: x, y: y)
        if verbose {
            FileHandle.standardError.write(Data("[iphonebase] Tap at (\(x), \(y)) — \(String(format: "%.0f", (afterFocus - tapStart) * 1000))ms after focus\n".utf8))
        }

        // Send heartbeat before action
        sendHeartbeat()
        usleep(50_000)

        if verbose { FileHandle.standardError.write(Data("[iphonebase] CGAssociate(false)\n".utf8)) }
        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))

        if verbose { FileHandle.standardError.write(Data("[iphonebase] CGWarp to (\(x), \(y))\n".utf8)) }
        CGWarpMouseCursorPosition(point)
        usleep(15_000)

        // Nudge-sync: align virtual HID pointer with warped cursor
        if verbose { FileHandle.standardError.write(Data("[iphonebase] Nudge-sync\n".utf8)) }
        var nudge1 = PointingReport()
        nudge1.x = 1
        sendRequest(.postPointingReport, payload: nudge1.toBytes())
        usleep(10_000)
        var nudge2 = PointingReport()
        nudge2.x = -1
        sendRequest(.postPointingReport, payload: nudge2.toBytes())
        usleep(10_000)

        // Click via virtual HID
        let clickTime = CFAbsoluteTimeGetCurrent()
        if verbose {
            let sinceFocus = (clickTime - afterFocus) * 1000
            let sinceStart = (clickTime - tapStart) * 1000
            FileHandle.standardError.write(Data("[iphonebase] HID mouseDown — \(String(format: "%.0f", sinceFocus))ms after focus, \(String(format: "%.0f", sinceStart))ms total\n".utf8))
        }
        var down = PointingReport()
        down.buttons = 0x01
        sendRequest(.postPointingReport, payload: down.toBytes())
        usleep(80_000)

        if verbose { FileHandle.standardError.write(Data("[iphonebase] HID mouseUp\n".utf8)) }
        let up = PointingReport()
        sendRequest(.postPointingReport, payload: up.toBytes())
        usleep(50_000)

        if verbose { FileHandle.standardError.write(Data("[iphonebase] CGAssociate(true)\n".utf8)) }
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))

        if verbose {
            let totalMs = (CFAbsoluteTimeGetCurrent() - tapStart) * 1000
            FileHandle.standardError.write(Data("[iphonebase] Tap complete — \(String(format: "%.0f", totalMs))ms total\n".utf8))
        }
    }

    /// Double-tap at absolute screen coordinates
    public func doubleTap(x: Double, y: Double) throws {
        try tap(x: x, y: y)
        usleep(100_000)
        try tap(x: x, y: y)
    }

    /// Long press at absolute screen coordinates
    public func longPress(x: Double, y: Double, durationMs: UInt32 = 1000) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()
        try validatePoint(x: x, y: y)

        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        CGWarpMouseCursorPosition(CGPoint(x: x, y: y))
        usleep(15_000)

        // Nudge-sync
        var nudge1 = PointingReport()
        nudge1.x = 1
        sendRequest(.postPointingReport, payload: nudge1.toBytes())
        usleep(10_000)
        var nudge2 = PointingReport()
        nudge2.x = -1
        sendRequest(.postPointingReport, payload: nudge2.toBytes())
        usleep(10_000)

        // Press and hold
        var down = PointingReport()
        down.buttons = 0x01
        sendRequest(.postPointingReport, payload: down.toBytes())
        usleep(durationMs * 1000)

        let up = PointingReport()
        sendRequest(.postPointingReport, payload: up.toBytes())
        usleep(50_000)

        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
    }

    /// Swipe in a direction from a starting point
    public func swipe(direction: SwipeDirection, fromX: Double, fromY: Double, distance: Double = 300, steps: Int = 20) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()
        try validatePoint(x: fromX, y: fromY)

        if verbose { FileHandle.standardError.write(Data("[iphonebase] Swipe \(direction) from (\(fromX), \(fromY)) dist \(distance)\n".utf8)) }

        sendHeartbeat()
        usleep(50_000)

        let (dx, dy): (Double, Double) = {
            switch direction {
            case .up:    return (0, -distance)
            case .down:  return (0, distance)
            case .left:  return (-distance, 0)
            case .right: return (distance, 0)
            }
        }()

        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))

        // Warp cursor to start position
        CGWarpMouseCursorPosition(CGPoint(x: fromX, y: fromY))
        usleep(15_000)

        // Nudge-sync
        var nudge1 = PointingReport()
        nudge1.x = 1
        sendRequest(.postPointingReport, payload: nudge1.toBytes())
        usleep(10_000)
        var nudge2 = PointingReport()
        nudge2.x = -1
        sendRequest(.postPointingReport, payload: nudge2.toBytes())
        usleep(10_000)

        // Mouse down
        var down = PointingReport()
        down.buttons = 0x01
        sendRequest(.postPointingReport, payload: down.toBytes())
        usleep(50_000)

        // Drag in steps using relative moves
        let stepDx = dx / Double(steps)
        let stepDy = dy / Double(steps)

        for _ in 0..<steps {
            var move = PointingReport()
            move.buttons = 0x01  // keep button held
            move.x = Int8(clamping: Int(stepDx))
            move.y = Int8(clamping: Int(stepDy))
            sendRequest(.postPointingReport, payload: move.toBytes())
            usleep(10_000)
        }

        // Mouse up
        let up = PointingReport()
        sendRequest(.postPointingReport, payload: up.toBytes())
        usleep(50_000)

        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))

        if verbose { FileHandle.standardError.write(Data("[iphonebase] Swipe complete\n".utf8)) }
    }

    /// Drag from one point to another (arbitrary point-to-point)
    public func drag(fromX: Double, fromY: Double, toX: Double, toY: Double, steps: Int = 20) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()
        try validatePoint(x: fromX, y: fromY)

        let dx = toX - fromX
        let dy = toY - fromY

        if verbose { FileHandle.standardError.write(Data("[iphonebase] Drag from (\(fromX), \(fromY)) to (\(toX), \(toY))\n".utf8)) }

        sendHeartbeat()
        usleep(50_000)

        // Auto-increase steps if distance exceeds Int8 range per step
        let maxPerStep = 127.0
        let requiredSteps = max(steps, Int(ceil(max(abs(dx), abs(dy)) / maxPerStep)))

        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))

        // Warp cursor to start position
        CGWarpMouseCursorPosition(CGPoint(x: fromX, y: fromY))
        usleep(15_000)

        // Nudge-sync
        var nudge1 = PointingReport()
        nudge1.x = 1
        sendRequest(.postPointingReport, payload: nudge1.toBytes())
        usleep(10_000)
        var nudge2 = PointingReport()
        nudge2.x = -1
        sendRequest(.postPointingReport, payload: nudge2.toBytes())
        usleep(10_000)

        // Mouse down
        var down = PointingReport()
        down.buttons = 0x01
        sendRequest(.postPointingReport, payload: down.toBytes())
        usleep(50_000)

        // Drag in steps using relative moves
        let stepDx = dx / Double(requiredSteps)
        let stepDy = dy / Double(requiredSteps)

        for _ in 0..<requiredSteps {
            var move = PointingReport()
            move.buttons = 0x01
            move.x = Int8(clamping: Int(stepDx))
            move.y = Int8(clamping: Int(stepDy))
            sendRequest(.postPointingReport, payload: move.toBytes())
            usleep(10_000)
        }

        // Mouse up
        let up = PointingReport()
        sendRequest(.postPointingReport, payload: up.toBytes())
        usleep(50_000)

        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))

        if verbose { FileHandle.standardError.write(Data("[iphonebase] Drag complete\n".utf8)) }
    }

    /// Type a string character by character
    public func typeText(_ text: String) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()

        for char in text {
            guard let mapping = HIDKeyMap.lookup(char) else {
                // Skip unmappable characters
                continue
            }
            sendKeystroke(keycode: mapping.keycode, modifiers: mapping.modifiers)
            usleep(30_000)  // 30ms between keystrokes
        }
    }

    /// Press a named key with optional modifiers
    public func pressKey(keycode: UInt16, modifiers: HIDModifier = []) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()
        sendKeystroke(keycode: keycode, modifiers: modifiers)
    }

    /// Scroll vertically
    public func scroll(direction: ScrollDirection, clicks: Int = 3) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()

        let wheelValue: Int8 = {
            switch direction {
            case .up: return 1
            case .down: return -1
            }
        }()

        for _ in 0..<clicks {
            var report = PointingReport()
            report.verticalWheel = wheelValue
            sendRequest(.postPointingReport, payload: report.toBytes())
            usleep(50_000)
        }
    }

    // MARK: - Private

    private func initializeDevices() {
        // Keyboard params: vendorID(u64) + productID(u64) + countryCode(u64) = 24 bytes
        // Apple vendor: 0x05ac, product: 0x0250, country: 0 (US)
        var kbParams = [UInt8](repeating: 0, count: 24)
        writeLE64(&kbParams, offset: 0, value: 0x05ac)
        writeLE64(&kbParams, offset: 8, value: 0x0250)
        writeLE64(&kbParams, offset: 16, value: 0)
        sendRequest(.keyboardInitialize, payload: kbParams)

        sendRequest(.pointingInitialize)
    }

    private func startHeartbeat() {
        // Send heartbeat immediately
        sendHeartbeat()

        // Use GCD timer (works without RunLoop in CLI apps)
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + 3.0, repeating: 3.0)
        timer.setEventHandler { [weak self] in
            self?.sendHeartbeat()
        }
        timer.resume()
        heartbeatSource = timer
    }

    private func sendHeartbeat() {
        var msg: [UInt8] = [0x00]  // framing: heartbeat
        let deadline: UInt32 = 5000
        msg.append(UInt8(deadline & 0xFF))
        msg.append(UInt8((deadline >> 8) & 0xFF))
        msg.append(UInt8((deadline >> 16) & 0xFF))
        msg.append(UInt8((deadline >> 24) & 0xFF))
        rawSend(msg)
    }

    private func sendKeystroke(keycode: UInt16, modifiers: HIDModifier) {
        // Key down
        var down = KeyboardReport()
        down.modifiers = modifiers.rawValue
        down.insertKey(keycode)
        sendRequest(.postKeyboardReport, payload: down.toBytes())

        usleep(20_000)

        // Key up (empty report = all keys released)
        let up = KeyboardReport()
        sendRequest(.postKeyboardReport, payload: up.toBytes())

        usleep(15_000)
    }

    private func sendRequest(_ request: Request, payload: [UInt8] = []) {
        var msg = [UInt8]()
        msg.append(0x01)  // framing: user data
        msg.append(0x63)  // 'c'
        msg.append(0x70)  // 'p'
        msg.append(UInt8(Self.protocolVersion & 0xFF))
        msg.append(UInt8(Self.protocolVersion >> 8))
        msg.append(request.rawValue)
        msg.append(contentsOf: payload)
        rawSend(msg)
    }

    private func rawSend(_ data: [UInt8]) {
        let sent = data.withUnsafeBufferPointer { buf in
            send(sockfd, buf.baseAddress, buf.count, 0)
        }
        if verbose && sent != data.count {
            FileHandle.standardError.write(Data("[iphonebase] rawSend FAILED: sent=\(sent), expected=\(data.count), errno=\(errno)\n".utf8))
        }
    }

    private func setSocketPath(_ addr: inout sockaddr_un, _ path: String) {
        withUnsafeMutableBytes(of: &addr.sun_path) { buf in
            let bytes = Array(path.utf8)
            for i in 0..<min(bytes.count, buf.count - 1) {
                buf[i] = bytes[i]
            }
        }
    }

    private func writeLE64(_ buf: inout [UInt8], offset: Int, value: UInt64) {
        for i in 0..<8 {
            buf[offset + i] = UInt8((value >> (i * 8)) & 0xFF)
        }
    }
}

// MARK: - Direction Types

public enum SwipeDirection: String, CaseIterable {
    case up, down, left, right
}

public enum ScrollDirection: String, CaseIterable {
    case up, down
}
