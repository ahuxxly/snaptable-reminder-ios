import Foundation
import UIKit
import Vision

protocol OCRServicing {
    func recognizeText(in image: UIImage) async throws -> String
}

enum OCRError: LocalizedError {
    case missingCGImage
    case noRecognizedText

    var errorDescription: String? {
        switch self {
        case .missingCGImage:
            return "The selected image could not be prepared for text recognition."
        case .noRecognizedText:
            return "No text was recognized in the selected image."
        }
    }
}

struct VisionOCRService: OCRServicing {
    func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else { throw OCRError.missingCGImage }

        return try await Task.detached(priority: .userInitiated) {
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "zh-Hans"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            let lines = (request.results ?? [])
                .compactMap { observation in
                    observation.topCandidates(1).first?.string
                }

            guard !lines.isEmpty else { throw OCRError.noRecognizedText }
            return lines.joined(separator: "\n")
        }.value
    }
}
