import CoreGraphics
import AppKit
import Foundation

/// Run a closure with the effective UID of the original (non-root) user.
/// When running under sudo, macOS TCC permissions (Screen Recording, etc.)
/// are tied to the real user, not root. This drops euid for the duration of
/// the closure so the user's permissions apply, then restores root euid.
public func withUserPrivileges<T>(_ body: () throws -> T) rethrows -> T {
    let originalEUID = geteuid()
    // Only drop if running as root with a known sudo user
    if originalEUID == 0,
       let sudoUID = ProcessInfo.processInfo.environment["SUDO_UID"],
       let uid = uid_t(sudoUID) {
        seteuid(uid)
        defer { seteuid(originalEUID) }
        return try body()
    }
    return try body()
}

/// Async variant of withUserPrivileges
public func withUserPrivilegesAsync<T>(_ body: () async throws -> T) async rethrows -> T {
    let originalEUID = geteuid()
    if originalEUID == 0,
       let sudoUID = ProcessInfo.processInfo.environment["SUDO_UID"],
       let uid = uid_t(sudoUID) {
        seteuid(uid)
        defer { seteuid(originalEUID) }
        return try await body()
    }
    return try await body()
}

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

/// Detected iPhone content area within the mirroring window.
/// All coordinates are in screen points, relative to the window's top-left corner.
public struct ContentArea {
    /// The iPhone screen content rectangle (excludes window chrome, rounded corners, etc.)
    public let rect: CGRect

    /// Y position of the home indicator bar center, relative to window top.
    /// Calculated from the content rect bottom — the indicator is always near
    /// the bottom edge of the iPhone screen (iOS system layout).
    public var homeIndicatorY: CGFloat {
        // The home indicator sits ~8pt from the bottom of the iPhone screen.
        // This is derived from the detected content boundary, not hardcoded pixels.
        rect.maxY - 8
    }
}

public struct ScreenCapture {

    private let windowManager: WindowManager

    public init(windowManager: WindowManager = WindowManager()) {
        self.windowManager = windowManager
    }

    /// Capture the iPhone Mirroring window as a CGImage.
    /// Uses CGWindowListCreateImage which relies on the traditional Screen Recording
    /// permission. Drops to user privileges when running under sudo so the user's
    /// TCC permissions apply (root has a separate TCC database).
    public func captureWindow() async throws -> CGImage {
        let mirroringWindow = try windowManager.findWindow()

        guard let image = withUserPrivileges({
            CGWindowListCreateImage(
                .null,
                .optionIncludingWindow,
                mirroringWindow.windowID,
                [.boundsIgnoreFraming, .bestResolution]
            )
        }) else {
            throw ScreenCaptureError.captureFailure("CGWindowListCreateImage returned nil. Check Screen Recording permission.")
        }

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

    // MARK: - Content Area Detection

    /// Detect the iPhone content area by scanning the captured window image
    /// for non-black pixel boundaries. Works at any window size or iPhone model.
    ///
    /// Algorithm:
    /// 1. Capture the window image
    /// 2. Scan center column/row for brightness transitions to find content edges
    /// 3. Scan bottom of content area for the home indicator bar (bright horizontal line)
    /// 4. Convert pixel coordinates to screen points using dynamic scale
    public func detectContentArea() async throws -> ContentArea {
        let image = try await captureWindow()
        let window = try windowManager.findWindow()

        let imgWidth = image.width
        let imgHeight = image.height

        guard let dataProvider = image.dataProvider,
              let data = dataProvider.data,
              let ptr = CFDataGetBytePtr(data) else {
            throw ScreenCaptureError.captureFailure("Could not access pixel data for content detection.")
        }

        let bytesPerPixel = image.bitsPerPixel / 8
        let bytesPerRow = image.bytesPerRow

        // Pixel brightness (0-255) at image coordinates
        func brightness(x: Int, y: Int) -> UInt8 {
            guard x >= 0, x < imgWidth, y >= 0, y < imgHeight else { return 0 }
            let offset = y * bytesPerRow + x * bytesPerPixel
            let r = UInt16(ptr[offset])
            let g = UInt16(ptr[offset + 1])
            let b = UInt16(ptr[offset + 2])
            return UInt8((r + g + b) / 3)
        }

        let contentThreshold: UInt8 = 30
        let centerX = imgWidth / 2

        // Scan center column top→down: first bright pixel = content top
        var contentTop = 0
        for y in 0..<imgHeight {
            if brightness(x: centerX, y: y) > contentThreshold {
                contentTop = y
                break
            }
        }

        // Scan center column bottom→up: first bright pixel = content bottom
        var contentBottom = imgHeight - 1
        for y in stride(from: imgHeight - 1, through: 0, by: -1) {
            if brightness(x: centerX, y: y) > contentThreshold {
                contentBottom = y
                break
            }
        }

        // Scan at vertical center of content for left/right edges
        let scanY = (contentTop + contentBottom) / 2

        var contentLeft = 0
        for x in 0..<imgWidth {
            if brightness(x: x, y: scanY) > contentThreshold {
                contentLeft = x
                break
            }
        }

        var contentRight = imgWidth - 1
        for x in stride(from: imgWidth - 1, through: 0, by: -1) {
            if brightness(x: x, y: scanY) > contentThreshold {
                contentRight = x
                break
            }
        }

        let cw = contentRight - contentLeft
        let ch = contentBottom - contentTop
        guard cw > 50, ch > 50 else {
            throw ScreenCaptureError.captureFailure(
                "Could not detect content area — screen may be off or all black."
            )
        }

        // Convert from image pixels to screen points using dynamic scale
        let scaleX = CGFloat(imgWidth) / window.bounds.width
        let scaleY = CGFloat(imgHeight) / window.bounds.height

        let rect = CGRect(
            x: CGFloat(contentLeft) / scaleX,
            y: CGFloat(contentTop) / scaleY,
            width: CGFloat(cw) / scaleX,
            height: CGFloat(ch) / scaleY
        )

        return ContentArea(rect: rect)
    }

    // MARK: - Grid Overlay

    /// Capture with a labeled grid overlay drawn on top.
    /// Returns the annotated image and the grid metadata (cell label -> center point in image coords).
    public func captureWithGrid(rows: Int? = nil, cols: Int? = nil) async throws -> (CGImage, GridInfo) {
        let image = try await captureWindow()
        let width = image.width
        let height = image.height

        // Auto-size to ~88px cells (44pt at 2x retina, matching iOS tap target)
        let effectiveCols = cols ?? max(1, width / 88)
        let effectiveRows = rows ?? max(1, height / 88)

        let cellW = CGFloat(width) / CGFloat(effectiveCols)
        let cellH = CGFloat(height) / CGFloat(effectiveRows)

        // Build grid metadata
        var cells: [String: GridCell] = [:]
        for row in 0..<effectiveRows {
            for col in 0..<effectiveCols {
                let label = GridInfo.cellLabel(row: row, col: col)
                let cx = Int(CGFloat(col) * cellW + cellW / 2)
                let cy = Int(CGFloat(row) * cellH + cellH / 2)
                cells[label] = GridCell(
                    x: Int(CGFloat(col) * cellW),
                    y: Int(CGFloat(row) * cellH),
                    width: Int(cellW),
                    height: Int(cellH),
                    centerX: cx,
                    centerY: cy
                )
            }
        }

        let gridInfo = GridInfo(rows: effectiveRows, cols: effectiveCols, cells: cells)

        // Draw grid overlay
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw ScreenCaptureError.captureFailure("Could not create graphics context for grid overlay.")
        }

        // Draw original image
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Draw grid lines (semi-transparent white)
        ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.5))
        ctx.setLineWidth(2)

        for col in 0...effectiveCols {
            let x = CGFloat(col) * cellW
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: CGFloat(height)))
        }
        for row in 0...effectiveRows {
            let y = CGFloat(row) * cellH
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: CGFloat(width), y: y))
        }
        ctx.strokePath()

        // Draw cell labels using CoreText
        for row in 0..<effectiveRows {
            for col in 0..<effectiveCols {
                let label = GridInfo.cellLabel(row: row, col: col)
                let cellX = CGFloat(col) * cellW
                // CoreGraphics y is flipped (origin bottom-left)
                let cellYFlipped = CGFloat(height) - CGFloat(row) * cellH - cellH

                let fontSize: CGFloat = min(cellW, cellH) * 0.25
                let clampedFontSize = max(10, min(fontSize, 24))

                let font = CTFontCreateWithName("Helvetica-Bold" as CFString, clampedFontSize, nil)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: CGColor(red: 1, green: 1, blue: 1, alpha: 0.9),
                ]
                let attrStr = NSAttributedString(string: label, attributes: attrs)
                let line = CTLineCreateWithAttributedString(attrStr)
                let textBounds = CTLineGetBoundsWithOptions(line, [])

                // Position label in top-left of cell (with padding)
                let pad: CGFloat = 4
                let pillW = textBounds.width + pad * 2
                let pillH = textBounds.height + pad * 2
                let pillX = cellX + 4
                let pillY = cellYFlipped + cellH - pillH - 4  // top of cell in flipped coords

                // Draw dark background pill
                ctx.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 0.6))
                ctx.fill(CGRect(x: pillX, y: pillY, width: pillW, height: pillH))

                // Draw text
                ctx.textPosition = CGPoint(x: pillX + pad, y: pillY + pad - textBounds.origin.y)
                CTLineDraw(line, ctx)
            }
        }

        guard let gridImage = ctx.makeImage() else {
            throw ScreenCaptureError.captureFailure("Could not create grid overlay image.")
        }

        return (gridImage, gridInfo)
    }

    /// Save a CGImage as PNG to a file
    public func saveImage(_ image: CGImage, to path: String) throws {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.saveFailed("Could not create PNG data.")
        }
        do {
            try pngData.write(to: URL(fileURLWithPath: path))
        } catch {
            throw ScreenCaptureError.saveFailed(error.localizedDescription)
        }
    }

    /// Convert a CGImage to PNG Data
    public func imageToData(_ image: CGImage) throws -> Data {
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
            throw ScreenCaptureError.saveFailed("Could not create PNG data.")
        }
        return pngData
    }
}

// MARK: - Grid Types

public struct GridCell: Codable {
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let centerX: Int
    public let centerY: Int

    public init(x: Int, y: Int, width: Int, height: Int, centerX: Int, centerY: Int) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.centerX = centerX
        self.centerY = centerY
    }

    enum CodingKeys: String, CodingKey {
        case x, y, width, height
        case centerX = "center_x"
        case centerY = "center_y"
    }
}

public struct GridInfo: Codable {
    public let rows: Int
    public let cols: Int
    public let cells: [String: GridCell]

    public init(rows: Int, cols: Int, cells: [String: GridCell]) {
        self.rows = rows
        self.cols = cols
        self.cells = cells
    }

    /// Convert row/col index to label like "A1", "B3", etc.
    /// Columns: A-Z (left to right), Rows: 1-N (top to bottom)
    public static func cellLabel(row: Int, col: Int) -> String {
        let colChar: String
        if col < 26 {
            colChar = String(UnicodeScalar(UInt8(65 + col)))  // A-Z
        } else {
            colChar = String(UnicodeScalar(UInt8(65 + col / 26 - 1))) + String(UnicodeScalar(UInt8(65 + col % 26)))
        }
        return "\(colChar)\(row + 1)"
    }

    /// Parse a cell label like "B3" into (row, col) indices
    public static func parseCell(_ label: String) -> (row: Int, col: Int)? {
        let upper = label.uppercased()
        var colPart = ""
        var rowPart = ""

        for ch in upper {
            if ch.isLetter {
                colPart.append(ch)
            } else if ch.isNumber {
                rowPart.append(ch)
            } else {
                return nil
            }
        }

        guard !colPart.isEmpty, !rowPart.isEmpty, let rowNum = Int(rowPart), rowNum >= 1 else {
            return nil
        }

        var col = 0
        for ch in colPart {
            col = col * 26 + Int(ch.asciiValue! - 65) + 1
        }
        col -= 1  // 0-indexed

        return (row: rowNum - 1, col: col)
    }

    /// Get the center point (in image coordinates) for a cell label
    public func centerForCell(_ label: String) -> (x: Int, y: Int)? {
        guard let cell = cells[label.uppercased()] else { return nil }
        return (x: cell.centerX, y: cell.centerY)
    }
}
