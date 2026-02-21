import Foundation
import CoreGraphics

// MARK: - Binary Report Structs

/// Karabiner virtual HID pointing report (8 bytes)
/// Sent via postPointingReport to the Karabiner DriverKit virtual HID device.
struct PointingReport {
    var buttons: UInt32 = 0   // bit 0 = left button
    var x: Int8 = 0           // relative X movement
    var y: Int8 = 0           // relative Y movement
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

    /// Tap at absolute screen coordinates using Karabiner HID pointing.
    /// Uses the same HID mechanism as swipe/drag for reliable iPhone Mirroring input.
    public func tap(x: Double, y: Double) throws {
        guard connected else { throw InputInjectorError.notConnected }
        let tapStart = CFAbsoluteTimeGetCurrent()
        try ensureFocus()
        let afterFocus = CFAbsoluteTimeGetCurrent()
        try validatePoint(x: x, y: y)

        let point = CGPoint(x: x, y: y)
        if verbose {
            FileHandle.standardError.write(Data("[tap] target=(\(Int(x)), \(Int(y))) focusMs=\(String(format: "%.0f", (afterFocus - tapStart) * 1000))\n".utf8))
            FileHandle.standardError.write(Data("[tap] windowBounds=\(windowBounds.map { "(\(Int($0.origin.x)),\(Int($0.origin.y)),\(Int($0.width)),\(Int($0.height)))" } ?? "nil")\n".utf8))
            FileHandle.standardError.write(Data("[tap] sockfd=\(sockfd) connected=\(connected)\n".utf8))
        }

        withMouseIsolated {
            // Step 1: Warp cursor
            CGWarpMouseCursorPosition(point)
            usleep(10_000)
            if verbose {
                let cursorPos = CGEvent(source: nil)?.location ?? .zero
                FileHandle.standardError.write(Data("[tap] after warp: cursorAt=(\(Int(cursorPos.x)),\(Int(cursorPos.y))) target=(\(Int(x)),\(Int(y)))\n".utf8))
            }

            // Step 2: Nudge sync
            if verbose { FileHandle.standardError.write(Data("[tap] nudgeSync start\n".utf8)) }
            nudgeSync()
            if verbose {
                let cursorPos = CGEvent(source: nil)?.location ?? .zero
                FileHandle.standardError.write(Data("[tap] after nudgeSync: cursorAt=(\(Int(cursorPos.x)),\(Int(cursorPos.y)))\n".utf8))
            }

            // Step 3: Button down
            if verbose { FileHandle.standardError.write(Data("[tap] sending HID buttonDown (buttons=0x01)\n".utf8)) }
            var down = PointingReport()
            down.buttons = 0x01
            sendPointingReport(down)
            usleep(30_000)

            // Step 3b: Micro-movement with button held (1px right, 1px back)
            // iPhone Mirroring may ignore stationary HID clicks — needs movement to register as touch
            if verbose { FileHandle.standardError.write(Data("[tap] micro-move +1px (with button held)\n".utf8)) }
            var moveRight = PointingReport()
            moveRight.buttons = 0x01
            moveRight.x = 1
            sendPointingReport(moveRight)
            usleep(15_000)

            var moveBack = PointingReport()
            moveBack.buttons = 0x01
            moveBack.x = -1
            sendPointingReport(moveBack)
            usleep(30_000)

            if verbose {
                let cursorPos = CGEvent(source: nil)?.location ?? .zero
                FileHandle.standardError.write(Data("[tap] after micro-move: cursorAt=(\(Int(cursorPos.x)),\(Int(cursorPos.y)))\n".utf8))
            }

            // Step 4: Button up
            if verbose { FileHandle.standardError.write(Data("[tap] sending HID buttonUp (buttons=0x00)\n".utf8)) }
            var up = PointingReport()
            up.buttons = 0x00
            sendPointingReport(up)
            usleep(50_000)
        }

        if verbose {
            let cursorPos = CGEvent(source: nil)?.location ?? .zero
            let totalMs = (CFAbsoluteTimeGetCurrent() - tapStart) * 1000
            FileHandle.standardError.write(Data("[tap] complete: finalCursor=(\(Int(cursorPos.x)),\(Int(cursorPos.y))) totalMs=\(String(format: "%.0f", totalMs))\n".utf8))
        }
    }

    /// Double-tap at absolute screen coordinates
    public func doubleTap(x: Double, y: Double) throws {
        try tap(x: x, y: y)
        usleep(100_000)
        try tap(x: x, y: y)
    }

    /// Long press at absolute screen coordinates using Karabiner HID pointing.
    public func longPress(x: Double, y: Double, durationMs: UInt32 = 1000) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()
        try validatePoint(x: x, y: y)

        let point = CGPoint(x: x, y: y)

        withMouseIsolated {
            CGWarpMouseCursorPosition(point)
            usleep(10_000)
            nudgeSync()

            // Press and hold via HID
            var down = PointingReport()
            down.buttons = 0x01
            sendPointingReport(down)
            usleep(durationMs * 1000)

            var up = PointingReport()
            up.buttons = 0x00
            sendPointingReport(up)
            usleep(50_000)
        }
    }

    /// Swipe in a direction using Karabiner HID pointing click-drag.
    /// iPhone Mirroring maps virtual mouse click-drag to iOS finger swipe.
    /// Critical: NO initial hold — an initial hold triggers iOS drag/selection mode.
    public func swipe(direction: SwipeDirection, fromX: Double, fromY: Double, distance: Double = 300, steps: Int = 20) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()
        try validatePoint(x: fromX, y: fromY)

        // Calculate end point based on direction
        var toX = fromX
        var toY = fromY
        switch direction {
        case .up:    toY -= distance
        case .down:  toY += distance
        case .left:  toX -= distance
        case .right: toX += distance
        }

        if verbose { FileHandle.standardError.write(Data("[iphonebase] Swipe \(direction) from (\(Int(fromX)), \(Int(fromY))) to (\(Int(toX)), \(Int(toY))) via HID pointing\n".utf8)) }

        let durationMs = 300
        let stepDelayUs = UInt32(max(durationMs, 1) * 1000 / steps)
        let totalDx = toX - fromX
        let totalDy = toY - fromY

        withMouseIsolated {
            // Warp cursor to start and sync virtual device
            CGWarpMouseCursorPosition(CGPoint(x: fromX, y: fromY))
            usleep(10_000)
            nudgeSync()

            // Button down — start immediately, no hold
            var down = PointingReport()
            down.buttons = 0x01
            sendPointingReport(down)

            // Interpolated movement with button held
            for i in 1...steps {
                let progress = Double(i) / Double(steps)
                let targetX = fromX + totalDx * progress
                let targetY = fromY + totalDy * progress

                // Warp system cursor to interpolated position
                CGWarpMouseCursorPosition(CGPoint(x: targetX, y: targetY))

                // Send relative movement via HID pointing (clamped to Int8 range)
                let dx = Int8(clamping: Int(totalDx / Double(steps)))
                let dy = Int8(clamping: Int(totalDy / Double(steps)))
                var move = PointingReport()
                move.buttons = 0x01  // keep button held
                move.x = dx
                move.y = dy
                sendPointingReport(move)
                usleep(stepDelayUs)
            }

            // Release button
            var up = PointingReport()
            up.buttons = 0x00
            sendPointingReport(up)
            usleep(10_000)
        }

        if verbose { FileHandle.standardError.write(Data("[iphonebase] Swipe complete\n".utf8)) }
    }

    /// Drag from one point to another using Karabiner HID pointing.
    /// Includes a 150ms initial hold to trigger iOS drag/selection mode
    /// (this differentiates drag from swipe).
    public func drag(fromX: Double, fromY: Double, toX: Double, toY: Double, steps: Int = 60) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()
        try validatePoint(x: fromX, y: fromY)

        let totalDx = toX - fromX
        let totalDy = toY - fromY
        let durationMs = 1000
        let stepDelayUs = UInt32(max(durationMs, 1) * 1000 / steps)

        if verbose { FileHandle.standardError.write(Data("[iphonebase] Drag from (\(Int(fromX)), \(Int(fromY))) to (\(Int(toX)), \(Int(toY))) via HID pointing\n".utf8)) }

        withMouseIsolated {
            // Warp cursor to start and sync virtual device
            CGWarpMouseCursorPosition(CGPoint(x: fromX, y: fromY))
            usleep(10_000)
            nudgeSync()

            // Button down with initial hold — triggers iOS drag/selection mode
            var down = PointingReport()
            down.buttons = 0x01
            sendPointingReport(down)
            usleep(150_000)  // 150ms hold before moving

            // Interpolated movement with button held
            for i in 1...steps {
                let progress = Double(i) / Double(steps)
                let targetX = fromX + totalDx * progress
                let targetY = fromY + totalDy * progress

                CGWarpMouseCursorPosition(CGPoint(x: targetX, y: targetY))

                let dx = Int8(clamping: Int(totalDx / Double(steps)))
                let dy = Int8(clamping: Int(totalDy / Double(steps)))
                var move = PointingReport()
                move.buttons = 0x01
                move.x = dx
                move.y = dy
                sendPointingReport(move)
                usleep(stepDelayUs)
            }

            // Release button
            var up = PointingReport()
            up.buttons = 0x00
            sendPointingReport(up)
            usleep(10_000)
        }

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

    /// Scroll via HID verticalWheel reports through the Karabiner virtual pointing device.
    /// "scroll down" = content moves up, "scroll up" = content moves down.
    public func scroll(direction: ScrollDirection, clicks: Int = 3) throws {
        guard connected else { throw InputInjectorError.notConnected }
        try ensureFocus()

        guard let bounds = windowBounds else { return }

        // Warp cursor to window center so scroll targets the mirroring window
        withMouseIsolated {
            CGWarpMouseCursorPosition(CGPoint(x: bounds.midX, y: bounds.midY))
            usleep(10_000)
            nudgeSync()
        }

        // HID scroll wheel: positive = scroll up (content down), negative = scroll down (content up)
        let wheelDelta: Int8 = direction == .down ? -1 : 1

        for i in 0..<clicks {
            if verbose { FileHandle.standardError.write(Data("[iphonebase] Scroll \(direction) tick \(i + 1)/\(clicks)\n".utf8)) }
            var report = PointingReport()
            report.verticalWheel = wheelDelta
            sendPointingReport(report)
            usleep(50_000)  // 50ms between scroll ticks
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

        // Pointing device — used for swipe/scroll/drag gestures.
        // iPhone Mirroring requires HID pointing click-drag for swipe gestures;
        // CGEvent scroll wheel events are ignored.
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

    /// Send a pointing input report to the Karabiner virtual HID pointing device.
    private func sendPointingReport(_ report: PointingReport) {
        sendRequest(.postPointingReport, payload: report.toBytes())
    }

    /// Nudge the virtual pointing device 1px right then 1px left to synchronize
    /// it with the system cursor position after a CGWarp.
    private func nudgeSync() {
        var nudgeRight = PointingReport()
        nudgeRight.x = 1
        sendPointingReport(nudgeRight)
        usleep(5_000)

        var nudgeBack = PointingReport()
        nudgeBack.x = -1
        sendPointingReport(nudgeBack)
        usleep(10_000)
    }

    /// Execute a block with the physical mouse disconnected from the cursor.
    /// This prevents physical mouse movement from interfering with programmatic input.
    private func withMouseIsolated(_ body: () -> Void) {
        CGAssociateMouseAndMouseCursorPosition(boolean_t(0))
        body()
        CGAssociateMouseAndMouseCursorPosition(boolean_t(1))
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
        if verbose {
            if sent == data.count {
                FileHandle.standardError.write(Data("[rawSend] OK sent=\(sent) bytes\n".utf8))
            } else {
                FileHandle.standardError.write(Data("[rawSend] FAILED sent=\(sent) expected=\(data.count) errno=\(errno)\n".utf8))
            }
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
