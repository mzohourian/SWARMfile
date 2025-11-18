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

    // MARK: - Validation & Utility Methods

    /// Checks if a PDF is password-protected (encrypted)
    /// - Parameter url: URL to the PDF file
    /// - Returns: True if the PDF is encrypted/password-protected
    public func isPasswordProtected(url: URL) -> Bool {
        guard let pdf = PDFDocument(url: url) else { return false }
        return pdf.isEncrypted
    }

    /// Validates a PDF can be opened and processed
    /// - Parameter url: URL to the PDF file
    /// - Throws: PDFError if the PDF is invalid, encrypted, or corrupted
    public func validatePDF(url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw PDFError.fileNotFound(url.lastPathComponent)
        }

        guard let pdf = PDFDocument(url: url) else {
            throw PDFError.corruptedPDF(url.lastPathComponent)
        }

        if pdf.isEncrypted {
            throw PDFError.passwordProtected(url.lastPathComponent)
        }

        if pdf.pageCount == 0 {
            throw PDFError.emptyPDF(url.lastPathComponent)
        }
    }

    /// Checks if there's enough disk space for an operation
    /// - Parameter estimatedSize: Estimated size in bytes needed for the operation
    /// - Throws: PDFError.insufficientStorage if not enough space
    public func checkDiskSpace(estimatedSize: Int64) throws {
        guard let availableSpace = try? getAvailableDiskSpace() else {
            // If we can't determine space, proceed (better than blocking user)
            return
        }

        // Require at least 50 MB buffer beyond the estimated size
        let requiredSpace = estimatedSize + (50 * 1_000_000)

        if availableSpace < requiredSpace {
            let neededMB = Double(requiredSpace - availableSpace) / 1_000_000.0
            throw PDFError.insufficientStorage(neededMB: neededMB)
        }
    }

    /// Gets available disk space in bytes
    private func getAvailableDiskSpace() throws -> Int64 {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values.volumeAvailableCapacityForImportantUsage ?? 0
    }

    /// Gets file size in bytes
    public func getFileSize(url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
    }

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

        for pageIndex in 0..<pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

            guard let pdfContext = UIGraphicsGetCurrentContext() else { continue }

            // Render page to image first
            let renderer = UIGraphicsImageRenderer(size: pageBounds.size)
            let pageImage = renderer.image { rendererContext in
                UIColor.white.setFill()
                rendererContext.fill(CGRect(origin: .zero, size: pageBounds.size))

                rendererContext.cgContext.translateBy(x: 0, y: pageBounds.size.height)
                rendererContext.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: rendererContext.cgContext)
            }

            // Compress and draw to PDF context
            if let compressedData = pageImage.jpegData(compressionQuality: quality.jpegQuality),
               let compressedImage = UIImage(data: compressedData) {
                compressedImage.draw(in: pageBounds)
            } else {
                pageImage.draw(in: pageBounds)
            }

            progressHandler(Double(pageIndex + 1) / Double(pageCount))
        }

        UIGraphicsEndPDFContext()

        // Verify the PDF was created successfully
        guard FileManager.default.fileExists(atPath: outputURL.path),
              let _ = PDFDocument(url: outputURL) else {
            throw PDFError.creationFailed
        }

        return outputURL
    }

    private func compressPDFToTargetSize(
        _ pdf: PDFDocument,
        targetSizeMB: Double,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let targetBytes = Int(targetSizeMB * 1_000_000)

        // Calculate original PDF size to determine compression ratio needed
        let tempOriginalURL = temporaryOutputURL(prefix: "original_check")
        _ = pdf.write(to: tempOriginalURL)
        let originalSize = (try? FileManager.default.attributesOfItem(atPath: tempOriginalURL.path)[.size] as? Int) ?? targetBytes * 10
        try? FileManager.default.removeItem(at: tempOriginalURL)

        // Determine resolution scale based on target compression ratio
        let compressionRatio = Double(targetBytes) / Double(originalSize)
        let resolutionScale: Double

        if compressionRatio < 0.15 {
            // Very aggressive compression needed (<15% of original) - use lowest resolution
            resolutionScale = 0.5
        } else if compressionRatio < 0.30 {
            // Aggressive compression (15-30%) - use reduced resolution
            resolutionScale = 0.65
        } else if compressionRatio < 0.50 {
            // Moderate compression (30-50%) - use slightly reduced resolution
            resolutionScale = 0.8
        } else {
            // Minimal compression (>50%) - use full resolution
            resolutionScale = 1.0
        }

        // Use binary search to find the right quality level
        var minQuality = 0.05  // Maximum compression (don't go lower to avoid corruption)
        var maxQuality = 0.95  // Minimum compression
        var bestURL: URL?
        var bestSize: Int = Int.max
        let maxAttempts = 10

        for attempt in 0..<maxAttempts {
            let currentQuality = (minQuality + maxQuality) / 2.0

            // Try to compress, but catch errors and continue to next iteration
            do {
                let testURL = try await compressPDFWithCustomQuality(
                    pdf,
                    jpegQuality: currentQuality,
                    resolutionScale: resolutionScale,
                    progressHandler: { progress in
                        let attemptProgress = Double(attempt) / Double(maxAttempts)
                        progressHandler(attemptProgress + (progress / Double(maxAttempts)))
                    }
                )

                if let attributes = try? FileManager.default.attributesOfItem(atPath: testURL.path),
                   let fileSize = attributes[.size] as? Int {

                    if fileSize <= targetBytes {
                        // This compression level works, save it
                        if bestURL != nil {
                            try? FileManager.default.removeItem(at: bestURL!)
                        }
                        bestURL = testURL
                        bestSize = fileSize

                        // Try less compression (higher quality) to get closer to target
                        minQuality = currentQuality

                        // If we're very close to target (within 5%), accept it
                        let percentOfTarget = Double(fileSize) / Double(targetBytes)
                        if percentOfTarget > 0.95 && percentOfTarget <= 1.0 {
                            progressHandler(1.0)
                            return testURL
                        }
                    } else {
                        // File too large, need more compression (lower quality)
                        maxQuality = currentQuality
                        try? FileManager.default.removeItem(at: testURL)
                    }
                }
            } catch {
                // Compression failed at this quality level, try with lower compression (higher quality)
                minQuality = currentQuality
                continue
            }

            // If quality range is very narrow, we've converged
            if maxQuality - minQuality < 0.02 {
                break
            }
        }

        // Return best result if we have one that's under target
        if let finalURL = bestURL, bestSize <= targetBytes {
            progressHandler(1.0)
            return finalURL
        }

        // If we couldn't achieve target, return the smallest we got
        // Better to give user smallest possible than throw error
        if let finalURL = bestURL {
            progressHandler(1.0)
            return finalURL
        }

        throw PDFError.targetSizeUnachievable
    }

    // Helper method to compress with custom quality
    private func compressPDFWithCustomQuality(
        _ pdf: PDFDocument,
        jpegQuality: Double,
        resolutionScale: Double = 1.0,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let outputURL = temporaryOutputURL(prefix: "compressed")
        let pageCount = pdf.pageCount

        UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, nil)

        for pageIndex in 0..<pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)
            UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

            guard let pdfContext = UIGraphicsGetCurrentContext() else { continue }

            // Calculate scaled size for rendering (downsample for compression)
            let scaledSize = CGSize(
                width: pageBounds.width * resolutionScale,
                height: pageBounds.height * resolutionScale
            )

            // Render page to image at scaled resolution
            let renderer = UIGraphicsImageRenderer(size: scaledSize)
            let pageImage = renderer.image { rendererContext in
                UIColor.white.setFill()
                rendererContext.fill(CGRect(origin: .zero, size: scaledSize))

                rendererContext.cgContext.scaleBy(x: resolutionScale, y: resolutionScale)
                rendererContext.cgContext.translateBy(x: 0, y: pageBounds.size.height)
                rendererContext.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: rendererContext.cgContext)
            }

            // Compress and draw to PDF context (at original page size)
            if let compressedData = pageImage.jpegData(compressionQuality: jpegQuality),
               let compressedImage = UIImage(data: compressedData) {
                compressedImage.draw(in: pageBounds)
            } else {
                pageImage.draw(in: pageBounds)
            }

            progressHandler(Double(pageIndex + 1) / Double(pageCount))
        }

        UIGraphicsEndPDFContext()

        // Verify the PDF was created successfully
        guard FileManager.default.fileExists(atPath: outputURL.path),
              let _ = PDFDocument(url: outputURL) else {
            throw PDFError.creationFailed
        }

        return outputURL
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
            // Calculate spacing for tiled watermarks
            let horizontalSpacing = textSize.width * 2.0
            let verticalSpacing = textSize.height * 4.0

            // Calculate how many fit, ensuring at least 1
            let cols = max(1, Int(ceil(bounds.width / horizontalSpacing)))
            let rows = max(1, Int(ceil(bounds.height / verticalSpacing)))

            for row in 0..<rows {
                for col in 0..<cols {
                    let x = bounds.minX + CGFloat(col) * horizontalSpacing + textSize.width * 0.5
                    let y = bounds.minY + CGFloat(row) * verticalSpacing + textSize.height * 0.5
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

    // MARK: - Sign PDF
    public func signPDF(
        _ pdfURL: URL,
        text: String? = nil,
        image: UIImage? = nil,
        position: WatermarkPosition,
        opacity: Double = 1.0,
        size: Double = 0.15,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        guard let sourcePDF = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }

        let outputURL = temporaryOutputURL(prefix: "signed")
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

            // Draw signature only on the last page
            if pageIndex == pageCount - 1 {
                context.saveGState()
                context.setAlpha(CGFloat(opacity))

                if let text = text {
                    drawSignatureText(text, in: pageBounds, position: position)
                } else if let image = image {
                    drawSignatureImage(image, in: pageBounds, position: position, size: size)
                }

                context.restoreGState()
            }

            progressHandler(Double(pageIndex + 1) / Double(pageCount))
        }

        return outputURL
    }

    private func drawSignatureText(_ text: String, in bounds: CGRect, position: WatermarkPosition) {
        let fontSize: CGFloat = bounds.height * 0.04
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Snell Roundhand", size: fontSize) ?? UIFont.italicSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black
        ]

        let textSize = (text as NSString).size(withAttributes: attributes)
        let point = positionForWatermark(textSize, in: bounds, position: position)
        (text as NSString).draw(at: point, withAttributes: attributes)
    }

    private func drawSignatureImage(_ image: UIImage, in bounds: CGRect, position: WatermarkPosition, size: Double) {
        let signatureSize = CGSize(
            width: bounds.width * CGFloat(size),
            height: bounds.width * CGFloat(size) * (image.size.height / image.size.width)
        )

        let origin = positionForWatermark(signatureSize, in: bounds, position: position)
        let rect = CGRect(origin: origin, size: signatureSize)
        image.draw(in: rect)
    }

    // MARK: - PDF to Images

    /// Exports PDF pages as individual images
    /// - Parameters:
    ///   - pdfURL: Source PDF URL
    ///   - format: Output image format (JPEG, PNG)
    ///   - quality: JPEG quality (0.0-1.0, ignored for PNG)
    ///   - resolution: DPI for rendering (72-300)
    ///   - progressHandler: Progress callback
    /// - Returns: Array of image file URLs
    public func pdfToImages(
        _ pdfURL: URL,
        format: String = "jpeg",
        quality: Double = 0.9,
        resolution: CGFloat = 150,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [URL] {

        // Validate PDF
        try validatePDF(url: pdfURL)

        guard let pdf = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }

        let pageCount = pdf.pageCount
        var outputURLs: [URL] = []

        // Estimate disk space needed (rough estimate: resolution * resolution * pageCount * 3 bytes)
        let estimatedSize = Int64(resolution * resolution * CGFloat(pageCount) * 3)
        try checkDiskSpace(estimatedSize: estimatedSize)

        for pageIndex in 0..<pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)

            // Calculate size based on resolution (DPI)
            let scale = resolution / 72.0  // 72 DPI is default
            let imageSize = CGSize(
                width: pageBounds.width * scale,
                height: pageBounds.height * scale
            )

            // Render page to image
            let renderer = UIGraphicsImageRenderer(size: imageSize)
            let pageImage = renderer.image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: imageSize))

                context.cgContext.scaleBy(x: scale, y: scale)
                context.cgContext.translateBy(x: 0, y: pageBounds.height)
                context.cgContext.scaleBy(x: 1.0, y: -1.0)

                page.draw(with: .mediaBox, to: context.cgContext)
            }

            // Save to file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "page_\(pageIndex + 1)_\(UUID().uuidString).\(format)"
            let outputURL = tempDir.appendingPathComponent(fileName)

            let imageData: Data?
            if format.lowercased() == "png" {
                imageData = pageImage.pngData()
            } else {
                imageData = pageImage.jpegData(compressionQuality: quality)
            }

            guard let data = imageData else { continue }
            try data.write(to: outputURL)

            outputURLs.append(outputURL)
            progressHandler(Double(pageIndex + 1) / Double(pageCount))
        }

        return outputURLs
    }

    // MARK: - Page Organization

    /// Reorders pages in a PDF document according to the specified order.
    /// - Parameters:
    ///   - document: The source PDF document
    ///   - newOrder: Array of original page indices (0-based) in desired order
    ///   - progressHandler: Closure called with progress (0.0 to 1.0)
    /// - Returns: URL to the new PDF with reordered pages
    /// - Throws: PDFError if the operation fails
    public func reorderPages(
        in document: PDFDocument,
        newOrder: [Int],
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        guard !newOrder.isEmpty else {
            throw PDFError.invalidPageRange
        }

        let outputURL = temporaryOutputURL(prefix: "reordered")
        let outputDocument = PDFDocument()

        for (index, originalIndex) in newOrder.enumerated() {
            guard originalIndex >= 0 && originalIndex < document.pageCount,
                  let page = document.page(at: originalIndex) else {
                continue
            }

            outputDocument.insert(page, at: outputDocument.pageCount)
            progressHandler(Double(index + 1) / Double(newOrder.count))
        }

        guard outputDocument.write(to: outputURL) else {
            throw PDFError.writeFailed
        }

        return outputURL
    }

    /// Deletes specified pages from a PDF document.
    /// - Parameters:
    ///   - document: The source PDF document
    ///   - indices: Set of page indices (0-based) to delete
    ///   - progressHandler: Closure called with progress (0.0 to 1.0)
    /// - Returns: URL to the new PDF with pages removed
    /// - Throws: PDFError if the operation fails
    public func deletePages(
        in document: PDFDocument,
        indices: Set<Int>,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let totalPages = document.pageCount

        guard !indices.isEmpty else {
            throw PDFError.noPagesToDelete
        }

        guard indices.count < totalPages else {
            throw PDFError.cannotDeleteAllPages
        }

        let outputURL = temporaryOutputURL(prefix: "deleted_pages")
        let outputDocument = PDFDocument()

        let remainingPages = totalPages - indices.count
        var processedPages = 0

        for pageIndex in 0..<totalPages {
            // Skip pages marked for deletion
            if indices.contains(pageIndex) {
                continue
            }

            guard let page = document.page(at: pageIndex) else { continue }
            outputDocument.insert(page, at: outputDocument.pageCount)

            processedPages += 1
            progressHandler(Double(processedPages) / Double(remainingPages))
        }

        guard outputDocument.write(to: outputURL) else {
            throw PDFError.writeFailed
        }

        return outputURL
    }

    /// Rotates specified pages in a PDF document.
    /// - Parameters:
    ///   - document: The source PDF document
    ///   - indices: Set of page indices (0-based) to rotate
    ///   - angle: Rotation angle in degrees (must be multiple of 90: 90, 180, 270, or -90)
    ///   - progressHandler: Closure called with progress (0.0 to 1.0)
    /// - Returns: URL to the new PDF with rotated pages
    /// - Throws: PDFError if the operation fails
    public func rotatePages(
        in document: PDFDocument,
        indices: Set<Int>,
        angle: Int,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        guard angle % 90 == 0 else {
            throw PDFError.invalidRotationAngle
        }

        let outputURL = temporaryOutputURL(prefix: "rotated_pages")
        let outputDocument = PDFDocument()

        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }

            // Rotate page if it's in the indices set
            if indices.contains(pageIndex) {
                let currentRotation = page.rotation
                page.rotation = (currentRotation + angle) % 360
            }

            outputDocument.insert(page, at: outputDocument.pageCount)
            progressHandler(Double(pageIndex + 1) / Double(document.pageCount))
        }

        guard outputDocument.write(to: outputURL) else {
            throw PDFError.writeFailed
        }

        return outputURL
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

public enum WatermarkPosition: String, Codable, CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, center, middleRight
    case bottomLeft, bottomCenter, bottomRight
    case tiled

    public var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Center"
        case .topRight: return "Top Right"
        case .middleLeft: return "Middle Left"
        case .center: return "Center"
        case .middleRight: return "Middle Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        case .tiled: return "Tiled"
        }
    }
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
    case invalidPageRange
    case noPagesToDelete
    case cannotDeleteAllPages
    case invalidRotationAngle
    case passwordProtected(String)
    case corruptedPDF(String)
    case fileNotFound(String)
    case emptyPDF(String)
    case insufficientStorage(neededMB: Double)

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
            return "Unable to save the PDF. You may be running low on storage space."
        case .creationFailed:
            return "Failed to create PDF. Please try again."
        case .targetSizeUnachievable:
            return "Could not compress to target size. Try a larger target or lower quality setting."
        case .invalidPageRange:
            return "Invalid page range provided"
        case .noPagesToDelete:
            return "No pages selected for deletion"
        case .cannotDeleteAllPages:
            return "Cannot delete all pages from a PDF. At least one page must remain."
        case .invalidRotationAngle:
            return "Rotation angle must be a multiple of 90 degrees"
        case .passwordProtected(let name):
            return "This PDF (\(name)) is password-protected. OneBox cannot process encrypted files. Please unlock it first."
        case .corruptedPDF(let name):
            return "This file (\(name)) appears to be corrupted or is not a valid PDF. Try re-downloading it."
        case .fileNotFound(let name):
            return "File not found: \(name). It may have been moved or deleted."
        case .emptyPDF(let name):
            return "This PDF (\(name)) contains no pages and cannot be processed."
        case .insufficientStorage(let neededMB):
            return String(format: "Not enough storage space. Please free up %.1f MB and try again.", neededMB)
        }
    }
}
