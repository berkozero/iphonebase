import Testing
import CoreGraphics
import CoreText
@testable import IPhoneBaseCore

// MARK: - Test Image Generator

/// Creates a CGImage with known text drawn at specific positions.
/// Uses CoreText with minimal CF APIs to avoid Foundation dependency.
private func createTestImage(
    width: Int = 750,
    height: Int = 1334,
    texts: [(String, CGPoint, CGFloat)]  // (text, position, fontSize)
) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }

    // White background
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
    ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // Draw each text item
    for (text, position, fontSize) in texts {
        let font = CTFontCreateWithName("Helvetica" as CFString, fontSize, nil)
        let black = CGColor(red: 0, green: 0, blue: 0, alpha: 1)

        let cfStr = text as CFString
        let attrStr = CFAttributedStringCreateMutable(nil, 0)!
        CFAttributedStringReplaceString(attrStr, CFRangeMake(0, 0), cfStr)
        let fullRange = CFRangeMake(0, CFStringGetLength(cfStr))
        CFAttributedStringSetAttribute(attrStr, fullRange, kCTFontAttributeName, font)
        CFAttributedStringSetAttribute(attrStr, fullRange, kCTForegroundColorAttributeName, black)

        let line = CTLineCreateWithAttributedString(attrStr)

        // CoreGraphics origin is bottom-left; position.y is top-left
        let flippedY = CGFloat(height) - position.y - fontSize
        ctx.textPosition = CGPoint(x: position.x, y: flippedY)
        CTLineDraw(line, ctx)
    }

    return ctx.makeImage()
}

// Vision framework deadlocks when multiple VNImageRequestHandler.perform() calls
// run concurrently. All OCR tests must be serialized under one parent suite.
@Suite("OCREngine", .serialized)
struct OCREngineTests {

    // MARK: - Recognition accuracy

    @Test("Recognizes large clear text")
    func recognizesLargeText() throws {
        let image = try #require(createTestImage(texts: [
            ("Settings", CGPoint(x: 100, y: 100), 48),
        ]))

        let ocr = OCREngine()
        let elements = try ocr.recognize(image: image)
        let texts = elements.map { $0.text }

        #expect(texts.contains(where: { $0.lowercased().contains("settings") }),
               "Expected to find 'Settings' in OCR results: \(texts)")
    }

    @Test("Recognizes multiple text elements")
    func recognizesMultipleTexts() throws {
        let image = try #require(createTestImage(texts: [
            ("General", CGPoint(x: 100, y: 100), 40),
            ("Display", CGPoint(x: 100, y: 300), 40),
            ("Privacy", CGPoint(x: 100, y: 500), 40),
        ]))

        let ocr = OCREngine()
        let elements = try ocr.recognize(image: image)
        let texts = elements.map { $0.text.lowercased() }

        #expect(texts.contains(where: { $0.contains("general") }),
               "Expected 'General' in results: \(texts)")
        #expect(texts.contains(where: { $0.contains("display") }),
               "Expected 'Display' in results: \(texts)")
        #expect(texts.contains(where: { $0.contains("privacy") }),
               "Expected 'Privacy' in results: \(texts)")
    }

    @Test("Returns sorted results (top to bottom)")
    func resultsSorted() throws {
        let image = try #require(createTestImage(texts: [
            ("Bottom", CGPoint(x: 100, y: 600), 40),
            ("Top", CGPoint(x: 100, y: 100), 40),
            ("Middle", CGPoint(x: 100, y: 350), 40),
        ]))

        let ocr = OCREngine()
        let elements = try ocr.recognize(image: image)

        let topIdx = elements.firstIndex(where: { $0.text.lowercased().contains("top") })
        let midIdx = elements.firstIndex(where: { $0.text.lowercased().contains("middle") })
        let botIdx = elements.firstIndex(where: { $0.text.lowercased().contains("bottom") })

        if let t = topIdx, let m = midIdx, let b = botIdx {
            #expect(t < m, "Top should come before Middle")
            #expect(m < b, "Middle should come before Bottom")
        }
    }

    @Test("Coordinates are in image pixel space with top-left origin")
    func coordinateSystem() throws {
        let image = try #require(createTestImage(
            width: 800,
            height: 1600,
            texts: [
                ("Hello", CGPoint(x: 300, y: 200), 48),
            ]
        ))

        let ocr = OCREngine()
        let elements = try ocr.recognize(image: image)
        let match = elements.first(where: { $0.text.lowercased().contains("hello") })

        let el = try #require(match, "Expected to find 'Hello'")

        #expect(el.centerX > 200 && el.centerX < 600,
               "centerX \(el.centerX) should be near x=300")
        #expect(el.centerY > 100 && el.centerY < 400,
               "centerY \(el.centerY) should be near y=200")
    }

    @Test("Confidence scores are high for clear text")
    func confidenceScores() throws {
        let image = try #require(createTestImage(texts: [
            ("Settings", CGPoint(x: 100, y: 100), 60),
        ]))

        let ocr = OCREngine()
        let elements = try ocr.recognize(image: image)
        let match = elements.first(where: { $0.text.lowercased().contains("settings") })

        let el = try #require(match, "Expected to find 'Settings'")
        #expect(el.confidence > 0.5, "Expected high confidence, got \(el.confidence)")
    }

    @Test("Returns empty array for blank image")
    func blankImage() throws {
        let image = try #require(createTestImage(texts: []))

        let ocr = OCREngine()
        let elements = try ocr.recognize(image: image)
        #expect(elements.isEmpty, "Expected no elements, got \(elements.count)")
    }

    // MARK: - Performance

    @Test("Single frame OCR completes within 2 seconds")
    func singleFrameTiming() throws {
        let image = try #require(createTestImage(texts: [
            ("Settings", CGPoint(x: 100, y: 100), 40),
            ("General", CGPoint(x: 100, y: 200), 36),
            ("Display", CGPoint(x: 100, y: 300), 36),
            ("Wallpaper", CGPoint(x: 100, y: 400), 36),
            ("Sounds", CGPoint(x: 100, y: 500), 36),
            ("Notifications", CGPoint(x: 100, y: 600), 36),
            ("Focus", CGPoint(x: 100, y: 700), 36),
            ("Screen Time", CGPoint(x: 100, y: 800), 36),
        ]))

        let ocr = OCREngine()

        let start = ContinuousClock.now
        let _ = try ocr.recognize(image: image)
        let elapsed = ContinuousClock.now - start
        let ms = elapsed.components.seconds * 1000 + elapsed.components.attoseconds / 1_000_000_000_000_000

        #expect(ms < 2000, "OCR took \(ms)ms, expected < 2000ms")
    }
}
