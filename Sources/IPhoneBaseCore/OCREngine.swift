import Vision
import CoreGraphics
import Foundation

public struct OCRElement: Codable {
    public let text: String
    public let x: Int
    public let y: Int
    public let width: Int
    public let height: Int
    public let centerX: Int
    public let centerY: Int
    public let confidence: Float

    public init(text: String, x: Int, y: Int, width: Int, height: Int,
                centerX: Int, centerY: Int, confidence: Float) {
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.centerX = centerX
        self.centerY = centerY
        self.confidence = confidence
    }
}

public enum OCRError: Error, CustomStringConvertible {
    case recognitionFailed(String)

    public var description: String {
        switch self {
        case .recognitionFailed(let reason):
            return "OCR recognition failed: \(reason)"
        }
    }
}

public struct OCREngine {

    public init() {}

    /// Run OCR on a CGImage and return recognized elements with positions
    public func recognize(image: CGImage) throws -> [OCRElement] {
        let imageWidth = image.width
        let imageHeight = image.height

        var results: [OCRElement] = []
        var recognitionError: Error?

        let request = VNRecognizeTextRequest { request, error in
            if let error = error {
                recognitionError = OCRError.recognitionFailed(error.localizedDescription)
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }

                // Vision coordinates are normalized (0-1) with origin at bottom-left
                // Convert to pixel coordinates with origin at top-left
                let boundingBox = observation.boundingBox

                let x = Int(boundingBox.origin.x * CGFloat(imageWidth))
                let y = Int((1.0 - boundingBox.origin.y - boundingBox.height) * CGFloat(imageHeight))
                let width = Int(boundingBox.width * CGFloat(imageWidth))
                let height = Int(boundingBox.height * CGFloat(imageHeight))

                let element = OCRElement(
                    text: candidate.string,
                    x: x,
                    y: y,
                    width: width,
                    height: height,
                    centerX: x + width / 2,
                    centerY: y + height / 2,
                    confidence: candidate.confidence
                )

                results.append(element)
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])

        if let error = recognitionError {
            throw error
        }

        // Sort by vertical position (top to bottom), then horizontal (left to right)
        results.sort { a, b in
            if abs(a.y - b.y) < 10 {
                return a.x < b.x
            }
            return a.y < b.y
        }

        return results
    }

}
