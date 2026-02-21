import ArgumentParser
import IPhoneBaseCore
import Foundation
import CoreGraphics

struct PerceiveCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "perceive",
        abstract: "Capture screenshot + OCR + grid metadata for AI agent consumption."
    )

    @Option(name: .long, help: "Number of grid rows (default: auto-sized to ~44pt cells).")
    var rows: Int?

    @Option(name: .long, help: "Number of grid columns (default: auto-sized to ~44pt cells).")
    var cols: Int?

    @Flag(name: .long, help: "Output as JSON.")
    var json = false

    @Flag(name: .long, help: "Embed base64 image data in JSON (for OpenClaw). Default: save to file paths.")
    var base64 = false

    func run() async throws {
        guard json else {
            print("perceive requires --json")
            throw ExitCode.failure
        }

        let wm = WindowManager()
        let window = try wm.findWindow()
        let capture = ScreenCapture(windowManager: wm)
        let ocr = OCREngine()

        var payload: PerceiveData?
        let ms = try await measureMs {
            // Capture raw screenshot
            let image = try await capture.captureWindow()

            let imgScaleX = window.bounds.width / Double(image.width)
            let imgScaleY = window.bounds.height / Double(image.height)

            // Run OCR and scale to screen points
            let elements = try ocr.recognize(image: image)
            let screenElements = elements.map { el in
                OCRElement(
                    text: el.text,
                    x: Int(Double(el.x) * imgScaleX),
                    y: Int(Double(el.y) * imgScaleY),
                    width: Int(Double(el.width) * imgScaleX),
                    height: Int(Double(el.height) * imgScaleY),
                    centerX: Int(Double(el.centerX) * imgScaleX),
                    centerY: Int(Double(el.centerY) * imgScaleY),
                    confidence: el.confidence
                )
            }

            // Build grid info with coordinates scaled to screen points
            let gridInfo = buildGridInfo(
                imageWidth: image.width,
                imageHeight: image.height,
                windowWidth: window.bounds.width,
                windowHeight: window.bounds.height,
                rows: rows,
                cols: cols
            )

            // Capture grid-overlay image
            let (gridImage, _) = try await capture.captureWithGrid(rows: rows, cols: cols)

            let windowData = PerceiveWindow(
                x: Int(window.bounds.origin.x),
                y: Int(window.bounds.origin.y),
                width: Int(window.bounds.width),
                height: Int(window.bounds.height)
            )

            if base64 {
                // Inline base64 mode (for OpenClaw)
                let imageData = try capture.imageToData(image)
                let gridImageData = try capture.imageToData(gridImage)
                payload = PerceiveData(
                    imagePath: nil,
                    gridImagePath: nil,
                    image: PerceiveImage(
                        format: "png",
                        encoding: "base64",
                        size: imageData.count,
                        data: imageData.base64EncodedString()
                    ),
                    gridImage: PerceiveImage(
                        format: "png",
                        encoding: "base64",
                        size: gridImageData.count,
                        data: gridImageData.base64EncodedString()
                    ),
                    elements: screenElements,
                    grid: gridInfo,
                    window: windowData
                )
            } else {
                // File path mode (default, for Claude Code)
                let tmpDir = "/tmp/iphonebase"
                try FileManager.default.createDirectory(
                    atPath: tmpDir,
                    withIntermediateDirectories: true
                )

                let imagePath = "\(tmpDir)/screen.png"
                let gridImagePath = "\(tmpDir)/screen-grid.png"

                try capture.saveImage(image, to: imagePath)
                try capture.saveImage(gridImage, to: gridImagePath)

                payload = PerceiveData(
                    imagePath: imagePath,
                    gridImagePath: gridImagePath,
                    image: nil,
                    gridImage: nil,
                    elements: screenElements,
                    grid: gridInfo,
                    window: windowData
                )
            }
        }

        let result = ActionResult.ok(action: "perceive", data: payload!, durationMs: ms)
        result.printJSON()
    }
}

// MARK: - Output types

private struct PerceiveImage: Encodable {
    let format: String
    let encoding: String
    let size: Int
    let data: String
}

private struct PerceiveWindow: Encodable {
    let x: Int
    let y: Int
    let width: Int
    let height: Int
}

private struct PerceiveData: Encodable {
    let imagePath: String?
    let gridImagePath: String?
    let image: PerceiveImage?
    let gridImage: PerceiveImage?
    let elements: [OCRElement]
    let grid: GridInfo
    let window: PerceiveWindow

    enum CodingKeys: String, CodingKey {
        case imagePath, gridImagePath, image, gridImage
        case elements, grid, window
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // Only encode non-nil optional fields to keep JSON clean
        if let imagePath = imagePath {
            try container.encode(imagePath, forKey: .imagePath)
        }
        if let gridImagePath = gridImagePath {
            try container.encode(gridImagePath, forKey: .gridImagePath)
        }
        if let image = image {
            try container.encode(image, forKey: .image)
        }
        if let gridImage = gridImage {
            try container.encode(gridImage, forKey: .gridImage)
        }
        try container.encode(elements, forKey: .elements)
        try container.encode(grid, forKey: .grid)
        try container.encode(window, forKey: .window)
    }
}

// MARK: - Grid builder (coordinates in screen points)

private func buildGridInfo(
    imageWidth: Int, imageHeight: Int,
    windowWidth: Double, windowHeight: Double,
    rows: Int?, cols: Int?
) -> GridInfo {
    let effectiveCols = cols ?? max(1, imageWidth / 88)
    let effectiveRows = rows ?? max(1, imageHeight / 88)

    let cellW = CGFloat(imageWidth) / CGFloat(effectiveCols)
    let cellH = CGFloat(imageHeight) / CGFloat(effectiveRows)

    let scaleX = windowWidth / Double(imageWidth)
    let scaleY = windowHeight / Double(imageHeight)

    var cells: [String: GridCell] = [:]
    for row in 0..<effectiveRows {
        for col in 0..<effectiveCols {
            let label = GridInfo.cellLabel(row: row, col: col)
            let imgCx = Double(col) * Double(cellW) + Double(cellW) / 2
            let imgCy = Double(row) * Double(cellH) + Double(cellH) / 2
            cells[label] = GridCell(
                x: Int(Double(col) * Double(cellW) * scaleX),
                y: Int(Double(row) * Double(cellH) * scaleY),
                width: Int(Double(cellW) * scaleX),
                height: Int(Double(cellH) * scaleY),
                centerX: Int(imgCx * scaleX),
                centerY: Int(imgCy * scaleY)
            )
        }
    }

    return GridInfo(rows: effectiveRows, cols: effectiveCols, cells: cells)
}
