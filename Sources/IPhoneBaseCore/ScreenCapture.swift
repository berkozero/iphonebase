import ScreenCaptureKit
import CoreGraphics
import AppKit

public enum ScreenCaptureError: Error, CustomStringConvertible {
    case windowNotFound
    case captureFailure(String)
    case saveFailed(String)

    public var description: String {
        switch self {
        case .windowNotFound:
            return "Could not find iPhone Mirroring window for capture."
        case .captureFailure(let reason):
            return "Screen capture failed: \(reason)"
        case .saveFailed(let reason):
            return "Failed to save screenshot: \(reason)"
        }
    }
}

public struct ScreenCapture {

    private let windowManager: WindowManager

    public init(windowManager: WindowManager = WindowManager()) {
        self.windowManager = windowManager
    }

    /// Capture the iPhone Mirroring window as a CGImage
    public func captureWindow() async throws -> CGImage {
        let mirroringWindow = try windowManager.findWindow()

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        guard let scWindow = content.windows.first(where: { $0.windowID == mirroringWindow.windowID }) else {
            throw ScreenCaptureError.windowNotFound
        }

        let filter = SCContentFilter(desktopIndependentWindow: scWindow)
        let config = SCStreamConfiguration()
        config.width = Int(mirroringWindow.bounds.width) * 2  // Retina
        config.height = Int(mirroringWindow.bounds.height) * 2
        config.captureResolution = .best
        config.showsCursor = false

        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
        return image
    }

    /// Capture and save as PNG
    public func captureToFile(path: String) async throws {
        let image = try await captureWindow()

        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.saveFailed("Could not create PNG data.")
        }

        let url = URL(fileURLWithPath: path)
        do {
            try pngData.write(to: url)
        } catch {
            throw ScreenCaptureError.saveFailed(error.localizedDescription)
        }
    }

    /// Capture and return PNG data (for stdout or piping)
    public func capturePNGData() async throws -> Data {
        let image = try await captureWindow()

        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.saveFailed("Could not create PNG data.")
        }

        return pngData
    }
}
