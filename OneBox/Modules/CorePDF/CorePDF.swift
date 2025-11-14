//
//  CorePDF.swift
//  OneBox - CorePDF Module
//
//  Provides comprehensive PDF processing: merge, split, compress, watermark, sign
//

import Foundation
import PDFKit
import CoreGraphics
import UIKit
import UniformTypeIdentifiers

// MARK: - PDF Processor
public actor PDFProcessor {

    public init() {}

    // MARK: - Images to PDF
    public func createPDF(
        from images: [URL],
        pageSize: CGSize?,
        orientation: PDFOrientation = .portrait,
        margins: CGFloat = 20,
        backgroundColor: UIColor = .white,
        stripMetadata: Bool = true,
        title: String? = nil,
        author: String? = nil,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let outputURL = temporaryOutputURL(prefix: "images_to_pdf")

        UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, [
            kCGPDFContextTitle as String: title ?? "OneBox Document",
            kCGPDFContextAuthor as String: author ?? "OneBox",
            kCGPDFContextCreator as String: "OneBox"
        ])

        for (index, imageURL) in images.enumerated() {
            guard let imageData = try? Data(contentsOf: imageURL),
                  let image = UIImage(data: imageData) else {
                UIGraphicsEndPDFContext()
                throw PDFError.invalidImage(imageURL.lastPathComponent)
            }

            let imageSize = image.size
            let pageRect: CGRect

            if let size = pageSize {
                // Use specified page size
                let adjustedSize = orientation == .landscape ?
                    CGSize(width: size.height, height: size.width) : size
                pageRect = CGRect(origin: .zero, size: adjustedSize)
            } else {
                // Fit to image size
                pageRect = CGRect(origin: .zero, size: imageSize)
            }

            UIGraphicsBeginPDFPageWithInfo(pageRect, nil)

            guard let context = UIGraphicsGetCurrentContext() else {
                UIGraphicsEndPDFContext()
                throw PDFError.contextCreationFailed
            }

            // Draw background
            context.setFillColor(backgroundColor.cgColor)
            context.fill(pageRect)

            // Calculate image rect with margins
            let contentRect = pageRect.insetBy(dx: margins, dy: margins)
            let imageRect = aspectFitRect(for: imageSize, in: contentRect)

            // Draw image
            image.draw(in: imageRect)

            progressHandler(Double(index + 1) / Double(images.count))
        }

        // Close PDF context
        UIGraphicsEndPDFContext()

        // Verify the PDF was created successfully
        guard FileManager.default.fileExists(atPath: outputURL.path),
              let _ = PDFDocument(url: outputURL) else {
            throw PDFError.creationFailed
        }

        return outputURL
    }

    // MARK: - Merge PDFs
    public func mergePDFs(
        _ pdfURLs: [URL],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        guard !pdfURLs.isEmpty else {
            throw PDFError.noPDFsToMerge
        }

        let outputURL = temporaryOutputURL(prefix: "merged")
        let outputDocument = PDFDocument()

        var totalPages = 0
        var processedPages = 0

        // Calculate total pages
        for url in pdfURLs {
            guard let pdf = PDFDocument(url: url) else {
                throw PDFError.invalidPDF(url.lastPathComponent)
            }
            totalPages += pdf.pageCount
        }

        // Merge PDFs
        for url in pdfURLs {
            guard let pdf = PDFDocument(url: url) else { continue }

            for pageIndex in 0..<pdf.pageCount {
                guard let page = pdf.page(at: pageIndex) else { continue }
                outputDocument.insert(page, at: outputDocument.pageCount)
                processedPages += 1
                progressHandler(Double(processedPages) / Double(totalPages))
            }
        }

        guard outputDocument.write(to: outputURL) else {
            throw PDFError.writeFailed
        }

        return outputURL
    }

    // MARK: - Split PDF
    public func splitPDF(
        _ pdfURL: URL,
        ranges: [ClosedRange<Int>],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [URL] {

        guard let sourcePDF = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }

        var outputURLs: [URL] = []

        for (index, range) in ranges.enumerated() {
            let outputURL = temporaryOutputURL(prefix: "split_\(index + 1)")
            let outputDocument = PDFDocument()

            for pageNumber in range {
                guard pageNumber >= 0 && pageNumber < sourcePDF.pageCount,
                      let page = sourcePDF.page(at: pageNumber) else {
                    continue
                }
                outputDocument.insert(page, at: outputDocument.pageCount)
            }

            guard outputDocument.write(to: outputURL) else {
                throw PDFError.writeFailed
            }

            outputURLs.append(outputURL)
            progressHandler(Double(index + 1) / Double(ranges.count))
        }

        return outputURLs
    }

    // MARK: - Compress PDF
    public func compressPDF(
        _ pdfURL: URL,
        quality: CompressionQuality,
        targetSizeMB: Double? = nil,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        guard let sourcePDF = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }

        if let targetSize = targetSizeMB {
            return try await compressPDFToTargetSize(
                sourcePDF,
                targetSizeMB: targetSize,
                progressHandler: progressHandler
            )
        } else {
            return try await compressPDFWithQuality(
                sourcePDF,
                quality: quality,
                progressHandler: progressHandler
            )
        }
    }

    private func compressPDFWithQuality(
        _ pdf: PDFDocument,
        quality: CompressionQuality,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let outputURL = temporaryOutputURL(prefix: "compressed")
        let pageCount = pdf.pageCount

        UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, nil)
        defer { UIGraphicsEndPDFContext() }

        for pageIndex in 0..<pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

            guard let context = UIGraphicsGetCurrentContext() else { continue }

            // Render page to image
            let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
            let pageImage = renderer.image { rendererContext in
                UIColor.white.setFill()
                rendererContext.fill(pageBounds)
                context.translateBy(x: 0, y: pageBounds.size.height)
                context.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: context)
            }

            // Compress and draw
            if let compressedData = pageImage.jpegData(compressionQuality: quality.jpegQuality),
               let compressedImage = UIImage(data: compressedData) {
                compressedImage.draw(in: pageBounds)
            } else {
                pageImage.draw(in: pageBounds)
            }

            progressHandler(Double(pageIndex + 1) / Double(pageCount))
        }

        return outputURL
    }

    private func compressPDFToTargetSize(
        _ pdf: PDFDocument,
        targetSizeMB: Double,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let targetBytes = Int(targetSizeMB * 1_000_000)
        let qualityLevels: [Double] = [0.9, 0.7, 0.5, 0.3, 0.2, 0.1]

        for (index, _) in qualityLevels.enumerated() {
            let testURL = try await compressPDFWithQuality(
                pdf,
                quality: CompressionQuality.medium,
                progressHandler: { _ in }
            )

            if let attributes = try? FileManager.default.attributesOfItem(atPath: testURL.path),
               let fileSize = attributes[.size] as? Int {
                if fileSize <= targetBytes || index == qualityLevels.count - 1 {
                    progressHandler(1.0)
                    return testURL
                }
            }

            // Clean up test file
            try? FileManager.default.removeItem(at: testURL)
        }

        throw PDFError.targetSizeUnachievable
    }

    // MARK: - Watermark PDF
    public func watermarkPDF(
        _ pdfURL: URL,
        text: String? = nil,
        image: UIImage? = nil,
        position: WatermarkPosition,
        opacity: Double = 0.5,
        size: Double = 0.2,
        tiled: Bool = false,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        guard let sourcePDF = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }

        let outputURL = temporaryOutputURL(prefix: "watermarked")
        let pageCount = sourcePDF.pageCount

        UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, nil)
        defer { UIGraphicsEndPDFContext() }

        for pageIndex in 0..<pageCount {
            guard let page = sourcePDF.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

            guard let context = UIGraphicsGetCurrentContext() else { continue }

            // Draw original page
            context.saveGState()
            context.translateBy(x: 0, y: pageBounds.size.height)
            context.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: context)
            context.restoreGState()

            // Draw watermark
            context.saveGState()
            context.setAlpha(CGFloat(opacity))

            if let text = text {
                drawTextWatermark(text, in: pageBounds, position: position, tiled: tiled)
            } else if let image = image {
                drawImageWatermark(image, in: pageBounds, position: position, size: size, tiled: tiled)
            }

            context.restoreGState()

            progressHandler(Double(pageIndex + 1) / Double(pageCount))
        }

        return outputURL
    }

    private func drawTextWatermark(_ text: String, in bounds: CGRect, position: WatermarkPosition, tiled: Bool) {
        let fontSize: CGFloat = bounds.height * 0.05
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.gray
        ]

        let textSize = (text as NSString).size(withAttributes: attributes)

        if tiled {
            let rows = Int(bounds.height / (textSize.height * 3))
            let cols = Int(bounds.width / (textSize.width * 1.5))

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * textSize.width * 1.5
                    let y = CGFloat(row) * textSize.height * 3
                    (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
                }
            }
        } else {
            let point = positionForWatermark(textSize, in: bounds, position: position)
            (text as NSString).draw(at: point, withAttributes: attributes)
        }
    }

    private func drawImageWatermark(_ image: UIImage, in bounds: CGRect, position: WatermarkPosition, size: Double, tiled: Bool) {
        let watermarkSize = CGSize(
            width: bounds.width * CGFloat(size),
            height: bounds.width * CGFloat(size) * (image.size.height / image.size.width)
        )

        if tiled {
            let rows = Int(bounds.height / watermarkSize.height) + 1
            let cols = Int(bounds.width / watermarkSize.width) + 1

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = CGFloat(col) * watermarkSize.width
                    let y = CGFloat(row) * watermarkSize.height
                    let rect = CGRect(origin: CGPoint(x: x, y: y), size: watermarkSize)
                    image.draw(in: rect)
                }
            }
        } else {
            let origin = positionForWatermark(watermarkSize, in: bounds, position: position)
            let rect = CGRect(origin: origin, size: watermarkSize)
            image.draw(in: rect)
        }
    }

    private func positionForWatermark(_ size: CGSize, in bounds: CGRect, position: WatermarkPosition) -> CGPoint {
        let margin: CGFloat = 20

        switch position {
        case .topLeft:
            return CGPoint(x: margin, y: margin)
        case .topCenter:
            return CGPoint(x: (bounds.width - size.width) / 2, y: margin)
        case .topRight:
            return CGPoint(x: bounds.width - size.width - margin, y: margin)
        case .middleLeft:
            return CGPoint(x: margin, y: (bounds.height - size.height) / 2)
        case .center:
            return CGPoint(x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2)
        case .middleRight:
            return CGPoint(x: bounds.width - size.width - margin, y: (bounds.height - size.height) / 2)
        case .bottomLeft:
            return CGPoint(x: margin, y: bounds.height - size.height - margin)
        case .bottomCenter:
            return CGPoint(x: (bounds.width - size.width) / 2, y: bounds.height - size.height - margin)
        case .bottomRight:
            return CGPoint(x: bounds.width - size.width - margin, y: bounds.height - size.height - margin)
        case .tiled:
            return .zero
        }
    }

    // MARK: - Helper Methods
    private func temporaryOutputURL(prefix: String) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let filename = "\(prefix)_\(UUID().uuidString).pdf"
        return tempDir.appendingPathComponent(filename)
    }

    private func aspectFitRect(for imageSize: CGSize, in containerRect: CGRect) -> CGRect {
        let containerAspect = containerRect.width / containerRect.height
        let imageAspect = imageSize.width / imageSize.height

        var targetSize = containerRect.size

        if imageAspect > containerAspect {
            // Image is wider than container
            targetSize.height = containerRect.width / imageAspect
        } else {
            // Image is taller than container
            targetSize.width = containerRect.height * imageAspect
        }

        let origin = CGPoint(
            x: containerRect.minX + (containerRect.width - targetSize.width) / 2,
            y: containerRect.minY + (containerRect.height - targetSize.height) / 2
        )

        return CGRect(origin: origin, size: targetSize)
    }
}

// MARK: - Supporting Types
public enum PDFOrientation: String, Codable {
    case portrait
    case landscape
}

public enum CompressionQuality: String, Codable, CaseIterable {
    case maximum
    case high
    case medium
    case low

    public var displayName: String {
        rawValue.capitalized
    }

    var jpegQuality: Double {
        switch self {
        case .maximum: return 0.3
        case .high: return 0.5
        case .medium: return 0.7
        case .low: return 0.85
        }
    }
}

public enum WatermarkPosition: String, Codable {
    case topLeft, topCenter, topRight
    case middleLeft, center, middleRight
    case bottomLeft, bottomCenter, bottomRight
    case tiled
}

// MARK: - PDF Error
public enum PDFError: LocalizedError {
    case invalidImage(String)
    case invalidPDF(String)
    case noPDFsToMerge
    case contextCreationFailed
    case writeFailed
    case creationFailed
    case targetSizeUnachievable

    public var errorDescription: String? {
        switch self {
        case .invalidImage(let name):
            return "Invalid image: \(name)"
        case .invalidPDF(let name):
            return "Invalid PDF: \(name)"
        case .noPDFsToMerge:
            return "No PDFs provided to merge"
        case .contextCreationFailed:
            return "Failed to create graphics context"
        case .writeFailed:
            return "Failed to write PDF file"
        case .creationFailed:
            return "Failed to create valid PDF file"
        case .targetSizeUnachievable:
            return "Could not compress to target size. Try a larger size or lower quality."
        }
    }
}
