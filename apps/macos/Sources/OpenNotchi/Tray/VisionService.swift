import AppKit
import Foundation
import ImageIO
import PDFKit
import UniformTypeIdentifiers
import Vision

enum ImageFormat: String, CaseIterable, Identifiable {
    case webp = "WebP"
    case png = "PNG"
    case jpeg = "JPEG"

    var id: String { rawValue }

    var utType: UTType {
        switch self {
        case .webp: return .webP
        case .png: return .png
        case .jpeg: return .jpeg
        }
    }

    var fileExtension: String {
        switch self {
        case .webp: return "webp"
        case .png: return "png"
        case .jpeg: return "jpg"
        }
    }
}

final class VisionService: ObservableObject {
    static let shared = VisionService()

    @Published var isProcessing = false
    @Published var statusNotification: String?
    @Published var lastExtractedText: String?

    private var statusTimer: Timer?

    // MARK: - OCR Text Recognition

    func recognizeText(from url: URL, completion: ((String?) -> Void)? = nil) {
        let ext = url.pathExtension.lowercased()

        if ext == "pdf" {
            extractTextFromPDF(url: url, completion: completion)
            return
        }

        guard let image = NSImage(contentsOf: url),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            notify("Could not read image file")
            completion?(nil)
            return
        }

        isProcessing = true
        let request = VNRecognizeTextRequest { [weak self] request, error in
            DispatchQueue.main.async {
                self?.isProcessing = false
                guard let observations = request.results as? [VNRecognizedTextObservation], error == nil else {
                    self?.notify("No text detected")
                    completion?(nil)
                    return
                }

                let text = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: "\n")
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self?.notify("No text found in image")
                    completion?(nil)
                } else {
                    self?.copyToClipboard(text: text)
                    let count = text.split(separator: " ").count
                    self?.notify("Copied \(count) words to clipboard!")
                    completion?(text)
                }
            }
        }

        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.notify("OCR recognition failed")
                    completion?(nil)
                }
            }
        }
    }

    private func extractTextFromPDF(url: URL, completion: ((String?) -> Void)? = nil) {
        guard let doc = PDFDocument(url: url) else {
            notify("Could not open PDF file")
            completion?(nil)
            return
        }

        var fullText = ""
        let maxPages = min(doc.pageCount, 15)
        for i in 0..<maxPages {
            if let page = doc.page(at: i), let pageText = page.string {
                fullText += pageText + "\n"
            }
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            notify("No selectable text in PDF")
            completion?(nil)
        } else {
            copyToClipboard(text: trimmed)
            let count = trimmed.split(separator: " ").count
            notify("Copied \(count) words from PDF!")
            completion?(trimmed)
        }
    }

    // MARK: - Image Conversion & Compression

    func convertImage(from url: URL, to format: ImageFormat, quality: Float = 0.85) -> URL? {
        guard let image = NSImage(contentsOf: url),
              let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let cgImage = bitmap.cgImage else {
            notify("Cannot read image")
            return nil
        }

        let outData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(outData, format.utType.identifier as CFString, 1, nil) else {
            notify("Conversion format unavailable")
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            notify("Conversion failed")
            return nil
        }

        let baseName = url.deletingPathExtension().lastPathComponent
        let targetFileName = "\(baseName).\(format.fileExtension)"
        let newURL = url.deletingLastPathComponent().appendingPathComponent(targetFileName)

        do {
            try (outData as Data).write(to: newURL)
            notify("Converted to \(format.rawValue)!")
            return newURL
        } catch {
            notify("Failed to save converted image")
            return nil
        }
    }

    // MARK: - Helpers

    func isImageOrPDF(_ url: URL) -> Bool {
        let imageExts: Set<String> = ["png", "jpg", "jpeg", "webp", "heic", "tiff", "gif", "bmp", "pdf"]
        return imageExts.contains(url.pathExtension.lowercased())
    }

    private func copyToClipboard(text: String) {
        lastExtractedText = text
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    func notify(_ message: String) {
        statusNotification = message
        statusTimer?.invalidate()
        statusTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: false) { [weak self] _ in
            self?.statusNotification = nil
        }
    }
}
