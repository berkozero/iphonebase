import ArgumentParser
import IPhoneBaseCore
import Foundation

struct DoctorCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "doctor",
        abstract: "Check all prerequisites and report what's working and what's broken."
    )

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    func run() async throws {
        var checks: [CheckResult] = []
        var failCount = 0

        // 1. macOS version
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let osOk = osVersion.majorVersion >= 15
        checks.append(CheckResult(
            check: "macos_version",
            passed: osOk,
            message: osOk
                ? "macOS \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)"
                : "macOS 15.0+ (Sequoia) required, found \(osVersion.majorVersion).\(osVersion.minorVersion)"
        ))
        if !osOk { failCount += 1 }

        // 2. iPhone Mirroring app installed
        let mirroringAppPath = "/System/Applications/iPhone Mirroring.app"
        let appInstalled = FileManager.default.fileExists(atPath: mirroringAppPath)
        checks.append(CheckResult(
            check: "iphone_mirroring_app",
            passed: appInstalled,
            message: appInstalled
                ? "iPhone Mirroring app found"
                : "iPhone Mirroring app not found at \(mirroringAppPath)"
        ))
        if !appInstalled { failCount += 1 }

        // 3. Mirroring window visible
        let wm = WindowManager()
        let windowVisible = wm.isAvailable()
        checks.append(CheckResult(
            check: "mirroring_window",
            passed: windowVisible,
            message: windowVisible
                ? "iPhone Mirroring window is visible"
                : "iPhone Mirroring window not found — open iPhone Mirroring and connect your iPhone"
        ))
        if !windowVisible { failCount += 1 }

        // 4. Karabiner DriverKit installed
        let driverPath = "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice"
        let driverInstalled = FileManager.default.fileExists(atPath: driverPath)
        checks.append(CheckResult(
            check: "karabiner_driver",
            passed: driverInstalled,
            message: driverInstalled
                ? "Karabiner DriverKit VirtualHIDDevice installed"
                : "Karabiner DriverKit not found — install Karabiner-Elements from https://karabiner-elements.pqrs.org/"
        ))
        if !driverInstalled { failCount += 1 }

        // 5. Karabiner daemon socket exists
        let serverDir = "/Library/Application Support/org.pqrs/tmp/rootonly/vhidd_server"
        let sockFiles = (try? FileManager.default.contentsOfDirectory(atPath: serverDir)
            .filter({ $0.hasSuffix(".sock") })) ?? []
        let socketExists = !sockFiles.isEmpty
        checks.append(CheckResult(
            check: "karabiner_socket",
            passed: socketExists,
            message: socketExists
                ? "Karabiner daemon socket found (\(sockFiles.count) socket(s))"
                : "No daemon socket in \(serverDir) — is Karabiner-Elements running?"
        ))
        if !socketExists { failCount += 1 }

        // 6. Can connect to daemon
        var canConnect = false
        if socketExists {
            let injector = InputInjector()
            do {
                try injector.connect()
                injector.disconnect()
                canConnect = true
            } catch {
                // connection failed
            }
        }
        checks.append(CheckResult(
            check: "karabiner_connection",
            passed: canConnect,
            message: canConnect
                ? "Successfully connected to Karabiner daemon"
                : "Cannot connect to Karabiner daemon — try running with sudo"
        ))
        if !canConnect { failCount += 1 }

        // 7. Screen Recording permission
        var captureOk = false
        if windowVisible {
            let capture = ScreenCapture(windowManager: wm)
            do {
                let _ = try await capture.captureWindow()
                captureOk = true
            } catch {
                // capture failed
            }
        }
        checks.append(CheckResult(
            check: "screen_recording",
            passed: captureOk,
            message: captureOk
                ? "Screen capture working"
                : "Screen capture failed — grant Screen Recording permission in System Settings > Privacy & Security"
        ))
        if !captureOk { failCount += 1 }

        // 8. OCR functional
        var ocrOk = false
        if captureOk {
            let capture = ScreenCapture(windowManager: wm)
            let ocr = OCREngine()
            do {
                let image = try await capture.captureWindow()
                let _ = try ocr.recognize(image: image)
                ocrOk = true
            } catch {
                // OCR failed
            }
        }
        checks.append(CheckResult(
            check: "ocr",
            passed: ocrOk,
            message: ocrOk
                ? "OCR (Vision) functional"
                : "OCR recognition failed — this may indicate a system issue"
        ))
        if !ocrOk { failCount += 1 }

        // Output
        if json {
            let result = ActionResult.ok(action: "doctor", data: checks)
            result.printJSON()
        } else {
            for check in checks {
                let indicator = check.passed ? "[ok]" : "[FAIL]"
                print("\(indicator) \(check.message)")
            }
            print("")
            if failCount == 0 {
                print("All checks passed. Ready to go.")
            } else {
                print("\(failCount) check(s) failed.")
            }
        }

        if failCount > 0 {
            throw ExitCode(Int32(failCount))
        }
    }
}

private struct CheckResult: Encodable {
    let check: String
    let passed: Bool
    let message: String
}
