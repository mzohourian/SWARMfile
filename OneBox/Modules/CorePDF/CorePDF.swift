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
import CommonTypes
import Photos

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
        
        // Input validation
        guard !images.isEmpty else {
            throw PDFError.invalidParameters("No images provided for PDF creation")
        }
        
        guard images.count <= 500 else {
            throw PDFError.invalidParameters("Too many images (\(images.count)). Maximum is 500 images.")
        }
        
        // Estimate memory requirements and validate
        let estimatedMemory = images.count * 10 * 1024 * 1024 // Rough estimate: 10MB per image
        let maxMemory = 500 * 1024 * 1024 // 500MB limit
        guard estimatedMemory < maxMemory else {
            throw PDFError.invalidParameters("PDF creation would require too much memory (\(estimatedMemory / 1024 / 1024)MB). Reduce number of images.")
        }

        let outputURL = temporaryOutputURL(prefix: "images_to_pdf")

        UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, [
            kCGPDFContextTitle as String: title ?? "OneBox Document",
            kCGPDFContextAuthor as String: author ?? "OneBox",
            kCGPDFContextCreator as String: "OneBox"
        ])

        for (index, imageURL) in images.enumerated() {
            // Use autoreleasepool to manage memory for each image
            try autoreleasepool {
                // Handle security-scoped resources
                var startedAccessing = false
                if imageURL.startAccessingSecurityScopedResource() {
                    startedAccessing = true
                }
                
                defer {
                    if startedAccessing {
                        imageURL.stopAccessingSecurityScopedResource()
                    }
                }
                
                // Validate image file and format
                guard imageURL.pathExtension.lowercased().contains(where: { ["jpg", "jpeg", "png", "heic", "heif"].contains(String($0)) }) else {
                    UIGraphicsEndPDFContext()
                    throw PDFError.invalidImage("Unsupported format: \(imageURL.lastPathComponent)")
                }
                
                guard let imageData = try? Data(contentsOf: imageURL),
                      let image = UIImage(data: imageData) else {
                    UIGraphicsEndPDFContext()
                    throw PDFError.invalidImage(imageURL.lastPathComponent)
                }
                
                // Validate image dimensions to prevent memory issues
                let maxDimension: CGFloat = 8192
                guard image.size.width <= maxDimension && image.size.height <= maxDimension else {
                    UIGraphicsEndPDFContext()
                    throw PDFError.invalidImage("Image too large: \(imageURL.lastPathComponent) (\(Int(image.size.width))x\(Int(image.size.height)))")
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
        }

        // Close PDF context
        UIGraphicsEndPDFContext()

        // Verify the PDF was created successfully
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw PDFError.creationFailed
        }
        
        // Validate the created PDF
        guard let createdPDF = PDFDocument(url: outputURL),
              createdPDF.pageCount > 0 else {
            // Clean up failed PDF
            try? FileManager.default.removeItem(at: outputURL)
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
        
        // Validate file size and memory before processing
        if let fileSize = getFileSize(url: pdfURL) {
            let validation = await MainActor.run {
                MemoryManager.shared.validateFileSize(fileSize: fileSize, operationType: .pdfCompress)
            }
            
            if !validation.canProcess {
                throw PDFError.invalidParameters(validation.recommendation)
            }
            
            if validation.warningLevel == .high || validation.warningLevel == .critical {
                print("⚠️ CorePDF: Memory warning for compression: \(validation.recommendation)")
            }
        }

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
        
        // Use chunked processing for large PDFs (> 100 pages)
        let useChunkedProcessing = pageCount > 100
        let chunkSize = useChunkedProcessing ? 50 : pageCount // Process 50 pages at a time for large PDFs

        UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, nil)
        defer { UIGraphicsEndPDFContext() }

        // Process in chunks to manage memory
        var processedPages = 0
        for chunkStart in stride(from: 0, to: pageCount, by: chunkSize) {
            let chunkEnd = min(chunkStart + chunkSize, pageCount)
            
            // Check memory pressure before each chunk
            if useChunkedProcessing {
                let memoryPressure = await MainActor.run {
                    MemoryManager.shared.getMemoryPressureLevel()
                }
                
                if memoryPressure == .critical {
                    throw PDFError.invalidParameters("Memory critically low. Please close other apps and try again.")
                }
            }
            
            for pageIndex in chunkStart..<chunkEnd {
                guard let page = pdf.page(at: pageIndex) else { continue }

                let pageBounds = page.bounds(for: .mediaBox)
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

                guard UIGraphicsGetCurrentContext() != nil else { continue }

                // Use autoreleasepool for each page to manage memory
                autoreleasepool {
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
                }

                processedPages += 1
                progressHandler(Double(processedPages) / Double(pageCount))
            }
            
            // Small delay between chunks to allow memory cleanup
            if useChunkedProcessing && chunkEnd < pageCount {
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s delay
            }
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

        // Last resort: Try one final compression with minimum quality
        // This ensures we always return something instead of crashing
        do {
            let fallbackURL = try await compressPDFWithCustomQuality(
                pdf,
                jpegQuality: 0.1, // Very low quality but still readable
                resolutionScale: 0.5, // Reduced resolution
                progressHandler: { _ in }
            )
            progressHandler(1.0)
            return fallbackURL
        } catch {
            // If even fallback fails, throw error with helpful message
            throw PDFError.targetSizeUnachievable
        }
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

            guard UIGraphicsGetCurrentContext() != nil else { continue }

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
        tileDensity: Double = 0.3,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        // Handle security-scoped resources for file access
        var startedAccessing = false
        if pdfURL.startAccessingSecurityScopedResource() {
            startedAccessing = true
        }
        defer {
            if startedAccessing {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        // Verify file exists and is accessible
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            throw PDFError.invalidPDF("\(pdfURL.lastPathComponent) - File not found")
        }
        
        guard let sourcePDF = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF("\(pdfURL.lastPathComponent) - Unable to load PDF document")
        }

        // Validate watermark content
        guard text != nil || image != nil else {
            throw PDFError.invalidParameters("No watermark text or image provided")
        }

        let outputURL = temporaryOutputURL(prefix: "watermarked")
        let pageCount = sourcePDF.pageCount
        
        // Validate page count
        guard pageCount > 0 else {
            throw PDFError.invalidPDF("\(pdfURL.lastPathComponent) - PDF has no pages")
        }

        UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, nil)
        defer { UIGraphicsEndPDFContext() }

        // Process pages with memory management and debugging
        for pageIndex in 0..<pageCount {
            print("🔄 CorePDF: Processing page \(pageIndex + 1) of \(pageCount) (\(Int(Double(pageIndex + 1) / Double(pageCount) * 100))%)")
            
            autoreleasepool {
                guard let page = sourcePDF.page(at: pageIndex) else { 
                    print("⚠️ CorePDF: Could not load page \(pageIndex)")
                    return
                }

                let pageBounds = page.bounds(for: .mediaBox)
                
                // Validate page bounds
                guard pageBounds.width > 0 && pageBounds.height > 0 else {
                    print("⚠️ CorePDF: Invalid page bounds for page \(pageIndex)")
                    return
                }
                
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

                guard let context = UIGraphicsGetCurrentContext() else { 
                    print("⚠️ CorePDF: Could not get graphics context for page \(pageIndex)")
                    return
                }

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
                    print("🎨 CorePDF: Drawing text watermark on page \(pageIndex)")
                    drawTextWatermark(text, in: pageBounds, position: position, size: size, tileDensity: tileDensity)
                } else if let image = image {
                    print("🎨 CorePDF: Drawing image watermark on page \(pageIndex)")
                    drawImageWatermark(image, in: pageBounds, position: position, size: size, tileDensity: tileDensity)
                }

                context.restoreGState()
                print("✅ CorePDF: Completed page \(pageIndex + 1)")
            }
            
            // Update progress after each page
            progressHandler(Double(pageIndex + 1) / Double(pageCount))
            
            // Add small yield to prevent blocking the main thread
            await Task.yield()
        }

        return outputURL
    }

    private func drawTextWatermark(_ text: String, in bounds: CGRect, position: WatermarkPosition, size: Double, tileDensity: Double) {
        print("🎨 CorePDF: Drawing text watermark '\(text)' at position \(position), size: \(size), density: \(tileDensity)")

        // IMPROVED: Size now dramatically affects font size
        // At size 0.0: 2% of page height (small)
        // At size 1.0: 15% of page height (large)
        let fontSize: CGFloat = bounds.height * CGFloat(0.02 + size * 0.13)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
            .foregroundColor: UIColor.gray
        ]

        let textSize = (text as NSString).size(withAttributes: attributes)
        print("🎨 CorePDF: Text size: \(textSize), fontSize: \(fontSize), bounds: \(bounds)")

        if position == .tiled {
            print("🎨 CorePDF: Drawing tiled watermark with density \(tileDensity)")

            // IMPROVED: Density now has much more dramatic effect
            // At density 1.0: spacing = 0.8x text size (watermarks overlap slightly)
            // At density 0.0: spacing = 6x text size (very sparse)
            let spacingMultiplier = 0.8 + (1.0 - tileDensity) * 5.2
            let horizontalSpacing = textSize.width * CGFloat(spacingMultiplier)
            let verticalSpacing = textSize.height * CGFloat(spacingMultiplier * 1.5)

            // Prevent excessive tiling that could cause memory issues
            guard horizontalSpacing > 0 && verticalSpacing > 0 else {
                print("⚠️ CorePDF: Invalid spacing for tiled text watermark")
                return
            }

            // FIXED: Reduced cap to 15 for consistency with image watermarks
            // 15x15 = 225 max operations per page
            let cols = max(1, min(15, Int(ceil(bounds.width / horizontalSpacing))))
            let rows = max(1, min(15, Int(ceil(bounds.height / verticalSpacing))))

            print("🎨 CorePDF: Tiling \(rows) rows x \(cols) cols")

            for row in 0..<rows {
                // Use autoreleasepool for each row to manage memory
                autoreleasepool {
                    for col in 0..<cols {
                        let x = bounds.minX + CGFloat(col) * horizontalSpacing + textSize.width * 0.5
                        let y = bounds.minY + CGFloat(row) * verticalSpacing + textSize.height * 0.5
                        (text as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: attributes)
                    }
                }
            }

            print("✅ CorePDF: Completed tiled text watermark")
        } else {
            print("🎨 CorePDF: Drawing single position watermark at \(position)")
            let point = positionForWatermark(textSize, in: bounds, position: position)
            (text as NSString).draw(at: point, withAttributes: attributes)
            print("✅ CorePDF: Completed single watermark")
        }
    }

    private func drawImageWatermark(_ image: UIImage, in bounds: CGRect, position: WatermarkPosition, size: Double, tileDensity: Double) {
        // Safety check for image dimensions to prevent division by zero
        guard image.size.width > 0 && image.size.height > 0 else {
            print("⚠️ CorePDF: Invalid image dimensions for watermark")
            return
        }

        print("🎨 CorePDF: Drawing image watermark with size: \(size), density: \(tileDensity)")

        let aspectRatio = image.size.height / image.size.width

        // IMPROVED: Size now has much more dramatic effect
        // At size 0.0: 5% of page width (small logo)
        // At size 1.0: 50% of page width (large watermark)
        let effectiveSize = 0.05 + size * 0.45
        let watermarkSize = CGSize(
            width: bounds.width * CGFloat(effectiveSize),
            height: bounds.width * CGFloat(effectiveSize) * aspectRatio
        )

        print("🎨 CorePDF: Watermark size: \(watermarkSize), effectiveSize: \(effectiveSize)")

        if position == .tiled {
            // IMPROVED: Density now has much more dramatic effect
            // At density 1.0: spacing = 0.6x size (watermarks overlap significantly)
            // At density 0.0: spacing = 5x size (very sparse)
            let spacingMultiplier = 0.6 + (1.0 - tileDensity) * 4.4
            let horizontalSpacing = watermarkSize.width * CGFloat(spacingMultiplier)
            let verticalSpacing = watermarkSize.height * CGFloat(spacingMultiplier)

            // Prevent excessive tiling that could cause memory issues
            guard horizontalSpacing > 0 && verticalSpacing > 0 else {
                print("⚠️ CorePDF: Invalid spacing for tiled watermark")
                return
            }

            // FIXED: Reduced from 50 to 15 to prevent memory issues and freezing
            // 15x15 = 225 max operations per page (vs 2500 before)
            let rows = max(1, min(15, Int(bounds.height / verticalSpacing) + 1))
            let cols = max(1, min(15, Int(bounds.width / horizontalSpacing) + 1))

            print("🎨 CorePDF: Drawing tiled image watermark - \(rows) rows x \(cols) cols")

            for row in 0..<rows {
                // Use autoreleasepool for each row to manage memory
                autoreleasepool {
                    for col in 0..<cols {
                        let x = bounds.minX + CGFloat(col) * horizontalSpacing
                        let y = bounds.minY + CGFloat(row) * verticalSpacing
                        let rect = CGRect(origin: CGPoint(x: x, y: y), size: watermarkSize)
                        image.draw(in: rect)
                    }
                }
            }
            print("✅ CorePDF: Completed tiled image watermark")
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
        customPosition: CGPoint? = nil,
        targetPageIndex: Int = -1, // -1 means last page
        opacity: Double = 1.0,
        size: Double = 0.15,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        
        // Input validation: Must have either text or image signature
        guard text != nil && !text!.isEmpty || image != nil else {
            throw PDFError.invalidParameters("Please provide a signature. Either enter text or draw a signature.")
        }
        
        // Validate PDF before processing
        try validatePDF(url: pdfURL)
        
        // Handle security-scoped resources
        var startedAccessing = false
        if pdfURL.startAccessingSecurityScopedResource() {
            startedAccessing = true
        }
        defer {
            if startedAccessing {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        guard let sourcePDF = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }

        let pageCount = sourcePDF.pageCount
        
        // Validate target page index
        if targetPageIndex >= pageCount {
            throw PDFError.invalidParameters("Page index \(targetPageIndex + 1) is out of range. This PDF has \(pageCount) page\(pageCount == 1 ? "" : "s").")
        }
        
        if targetPageIndex < -1 {
            throw PDFError.invalidParameters("Invalid page index. Use -1 for last page or a valid page number.")
        }
        
        // Validate signature image if provided
        if let signatureImage = image {
            // Check image dimensions to prevent memory issues
            let maxDimension: CGFloat = 4096
            if signatureImage.size.width > maxDimension || signatureImage.size.height > maxDimension {
                throw PDFError.invalidImage("Signature image is too large (\(Int(signatureImage.size.width))x\(Int(signatureImage.size.height))). Maximum size is \(Int(maxDimension))x\(Int(maxDimension)) pixels.")
            }
            
            // Check image file size (estimate from PNG data)
            if let imageData = signatureImage.pngData(), imageData.count > 10 * 1024 * 1024 {
                throw PDFError.invalidImage("Signature image file is too large (\(imageData.count / 1024 / 1024)MB). Please use a smaller signature.")
            }
        }
        
        // Validate text signature if provided
        if let signatureText = text {
            // Limit text length to prevent issues
            if signatureText.count > 200 {
                throw PDFError.invalidParameters("Signature text is too long (\(signatureText.count) characters). Maximum is 200 characters.")
            }
        }
        
        // Validate opacity and size parameters
        guard opacity >= 0.0 && opacity <= 1.0 else {
            throw PDFError.invalidParameters("Opacity must be between 0.0 and 1.0.")
        }
        
        guard size > 0.0 && size <= 1.0 else {
            throw PDFError.invalidParameters("Signature size must be between 0.0 and 1.0.")
        }
        
        // Estimate output size and check disk space
        // Rough estimate: original PDF size + signature overhead (typically < 1MB)
        let estimatedOutputSize = getFileSize(url: pdfURL) ?? 0
        let estimatedOverhead: Int64 = 2 * 1024 * 1024 // 2MB overhead for signature
        try checkDiskSpace(estimatedSize: estimatedOutputSize + estimatedOverhead)

        let outputURL = temporaryOutputURL(prefix: "signed")
        
        // Ensure temporary directory exists and is writable
        let tempDir = FileManager.default.temporaryDirectory
        if !FileManager.default.fileExists(atPath: tempDir.path) {
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        }
        
        // Check if context creation succeeds
        // Ensure the output directory exists
        let outputDir = outputURL.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: outputDir.path) {
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Check available disk space before creating context
        // Use a more lenient check - only fail if we're really out of space
        // The 10MB check was too strict and could fail even when there's plenty of space
        if let availableSpace = try? getAvailableDiskSpace() {
            // Only fail if we have less than 1MB available (very low threshold)
            // This prevents false positives while still catching real storage issues
            if availableSpace < 1 * 1024 * 1024 {
                print("⚠️ CorePDF: Very low storage detected: \(availableSpace / 1024 / 1024)MB")
                throw PDFError.insufficientStorage(neededMB: 10.0)
            }
        } else {
            // If we can't determine available space, proceed anyway
            // Better to try and fail with a better error than block the user
            print("⚠️ CorePDF: Could not determine available disk space, proceeding anyway")
        }
        
        // Check if directory is writable
        if !FileManager.default.isWritableFile(atPath: outputDir.path) {
            throw PDFError.writeFailed // Directory not writable
        }
        
        // Check if file already exists and remove it if necessary
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        // Try to create PDF context
        guard UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, nil) else {
            // Context creation failed - provide more specific error
            print("❌ CorePDF: Failed to create PDF context at path: \(outputURL.path)")
            throw PDFError.contextCreationFailed
        }
        
        var signatureDrawn = false
        
        // Use autoreleasepool for memory management
        autoreleasepool {
            for pageIndex in 0..<pageCount {
                guard let page = sourcePDF.page(at: pageIndex) else {
                    // Skip invalid pages but continue processing
                    progressHandler(Double(pageIndex + 1) / Double(pageCount))
                    continue
                }

                let pageBounds = page.bounds(for: .mediaBox)
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

                guard let context = UIGraphicsGetCurrentContext() else {
                    // If context is nil, skip this page but continue
                    progressHandler(Double(pageIndex + 1) / Double(pageCount))
                    continue
                }

                // Draw original page
                context.saveGState()
                context.translateBy(x: 0, y: pageBounds.size.height)
                context.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: context)
                context.restoreGState()

                // Draw signature on the target page
                let shouldDrawSignature = (targetPageIndex == -1 && pageIndex == pageCount - 1) || 
                                         (targetPageIndex >= 0 && pageIndex == targetPageIndex)
                
                if shouldDrawSignature {
                    context.saveGState()
                    context.setAlpha(CGFloat(opacity))

                    if let text = text, !text.isEmpty {
                        if let customPos = customPosition {
                            drawSignatureText(text, in: pageBounds, customPosition: customPos)
                        } else {
                            drawSignatureText(text, in: pageBounds, position: position)
                        }
                        signatureDrawn = true
                    } else if let image = image {
                        if let customPos = customPosition {
                            drawSignatureImage(image, in: pageBounds, customPosition: customPos, size: size)
                        } else {
                            drawSignatureImage(image, in: pageBounds, position: position, size: size)
                        }
                        signatureDrawn = true
                    }

                    context.restoreGState()
                }

                progressHandler(Double(pageIndex + 1) / Double(pageCount))
            }
        }
        
        // Verify that signature was actually drawn
        guard signatureDrawn else {
            UIGraphicsEndPDFContext() // Clean up context before throwing
            throw PDFError.invalidParameters("Failed to draw signature on the specified page. Please try again.")
        }
        
        // Explicitly end PDF context before verification
        // This ensures the file is fully written before we check for it
        UIGraphicsEndPDFContext()
        
        // Give the file system more time to flush the write
        // Sometimes UIGraphicsEndPDFContext() returns before the file is fully written
        // Use a longer delay and also try to access the file to force a flush
        try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 second delay
        
        // Try to access the file to force file system flush
        _ = try? FileManager.default.contentsOfDirectory(atPath: outputURL.deletingLastPathComponent().path)
        
        // Verify output file was created and is valid
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            print("❌ CorePDF: Output file does not exist at path: \(outputURL.path)")
            // Check if temporary directory is accessible
            let tempDir = FileManager.default.temporaryDirectory
            if !FileManager.default.fileExists(atPath: tempDir.path) {
                print("❌ CorePDF: Temporary directory doesn't exist: \(tempDir.path)")
                throw PDFError.writeFailed // Temporary directory doesn't exist
            }
            // Check if directory is writable
            if !FileManager.default.isWritableFile(atPath: tempDir.path) {
                print("❌ CorePDF: Temporary directory is not writable: \(tempDir.path)")
                throw PDFError.writeFailed // Directory not writable
            }
            // Check available space - only fail if really out of space
            if let availableSpace = try? getAvailableDiskSpace(), availableSpace < 1 * 1024 * 1024 {
                print("⚠️ CorePDF: Very low storage detected: \(availableSpace / 1024 / 1024)MB")
                throw PDFError.insufficientStorage(neededMB: 10.0)
            }
            print("❌ CorePDF: File write failed for unknown reason")
            throw PDFError.writeFailed
        }
        
        // Check file size
        if let fileSize = getFileSize(url: outputURL), fileSize == 0 {
            print("❌ CorePDF: Output file is empty (0 bytes)")
            try? FileManager.default.removeItem(at: outputURL)
            throw PDFError.writeFailed // File is empty
        }
        
        // Verify output is a valid PDF
        guard let createdPDF = PDFDocument(url: outputURL) else {
            print("❌ CorePDF: Created file exists but is not a valid PDF")
            // Try to get file size to see if it was written
            if let fileSize = getFileSize(url: outputURL) {
                print("❌ CorePDF: File size: \(fileSize) bytes")
            }
            // Clean up invalid file
            try? FileManager.default.removeItem(at: outputURL)
            throw PDFError.writeFailed // PDF is corrupted
        }
        
        // Verify PDF has pages
        guard createdPDF.pageCount > 0 else {
            print("❌ CorePDF: Created PDF has no pages")
            try? FileManager.default.removeItem(at: outputURL)
            throw PDFError.writeFailed
        }
        
        print("✅ CorePDF: Successfully created signed PDF at: \(outputURL.path), size: \(getFileSize(url: outputURL) ?? 0) bytes, pages: \(createdPDF.pageCount)")
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
        // Validate image dimensions to prevent division by zero
        guard image.size.width > 0 && image.size.height > 0 else {
            print("Warning: Invalid image dimensions for signature")
            return
        }
        
        // Validate bounds
        guard bounds.width > 0 && bounds.height > 0 else {
            print("Warning: Invalid bounds for signature placement")
            return
        }
        
        let aspectRatio = image.size.height / image.size.width
        let signatureSize = CGSize(
            width: bounds.width * CGFloat(size),
            height: bounds.width * CGFloat(size) * aspectRatio
        )
        
        // Ensure signature doesn't exceed page bounds
        let clampedSize = CGSize(
            width: min(signatureSize.width, bounds.width * 0.9),
            height: min(signatureSize.height, bounds.height * 0.9)
        )

        let origin = positionForWatermark(clampedSize, in: bounds, position: position)
        let rect = CGRect(origin: origin, size: clampedSize)
        image.draw(in: rect)
    }
    
    // Custom position drawing methods
    private func drawSignatureText(_ text: String, in bounds: CGRect, customPosition: CGPoint) {
        // Validate bounds
        guard bounds.width > 0 && bounds.height > 0 else {
            print("Warning: Invalid bounds for signature text placement")
            return
        }
        
        // Validate and clamp custom position to valid range (0.0 to 1.0)
        let clampedX = max(0.0, min(1.0, customPosition.x))
        let clampedY = max(0.0, min(1.0, customPosition.y))
        
        let fontSize: CGFloat = max(8.0, min(bounds.height * 0.04, 72.0)) // Clamp font size
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont(name: "Snell Roundhand", size: fontSize) ?? UIFont.italicSystemFont(ofSize: fontSize),
            .foregroundColor: UIColor.black
        ]
        
        // Custom position is in normalized coordinates (0.0 to 1.0)
        let textSize = (text as NSString).size(withAttributes: attributes)
        let point = CGPoint(
            x: max(bounds.minX, min(bounds.minX + (bounds.width * clampedX), bounds.maxX - textSize.width)),
            y: max(bounds.minY, min(bounds.minY + (bounds.height * (1.0 - clampedY)), bounds.maxY - textSize.height))
        )
        (text as NSString).draw(at: point, withAttributes: attributes)
    }
    
    private func drawSignatureImage(_ image: UIImage, in bounds: CGRect, customPosition: CGPoint, size: Double) {
        // Validate image dimensions to prevent division by zero
        guard image.size.width > 0 && image.size.height > 0 else {
            print("Warning: Invalid image dimensions for signature")
            return
        }
        
        // Validate bounds
        guard bounds.width > 0 && bounds.height > 0 else {
            print("Warning: Invalid bounds for signature placement")
            return
        }
        
        // Validate and clamp custom position to valid range (0.0 to 1.0)
        let clampedX = max(0.0, min(1.0, customPosition.x))
        let clampedY = max(0.0, min(1.0, customPosition.y))
        
        let aspectRatio = image.size.height / image.size.width
        let signatureSize = CGSize(
            width: bounds.width * CGFloat(size),
            height: bounds.width * CGFloat(size) * aspectRatio
        )
        
        // Ensure signature doesn't exceed page bounds
        let clampedSize = CGSize(
            width: min(signatureSize.width, bounds.width * 0.9),
            height: min(signatureSize.height, bounds.height * 0.9)
        )
        
        // Custom position is in normalized coordinates (0.0 to 1.0)
        let origin = CGPoint(
            x: bounds.minX + (bounds.width * clampedX),
            y: bounds.minY + (bounds.height * (1.0 - clampedY)) // Flip Y coordinate
        )
        
        // Ensure signature stays within page bounds
        let finalOrigin = CGPoint(
            x: max(bounds.minX, min(origin.x, bounds.maxX - clampedSize.width)),
            y: max(bounds.minY, min(origin.y, bounds.maxY - clampedSize.height))
        )
        
        let rect = CGRect(origin: finalOrigin, size: clampedSize)
        image.draw(in: rect)
    }

    // MARK: - PDF to Images
    public func pdfToImages(
        _ pdfURL: URL,
        format: String = "jpeg",
        quality: Double = 0.9,
        resolution: CGFloat = 150,
        pageRanges: [[Int]] = [], // Empty array means convert all pages
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [URL] {

        // Handle security-scoped resources
        var startedAccessing = false
        if pdfURL.startAccessingSecurityScopedResource() {
            startedAccessing = true
        }
        
        defer {
            if startedAccessing {
                pdfURL.stopAccessingSecurityScopedResource()
            }
        }

        // Validate PDF
        try validatePDF(url: pdfURL)

        guard let pdf = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }

        let pageCount = pdf.pageCount
        var outputURLs: [URL] = []

        // Determine which pages to process
        let pagesToProcess: [Int]
        if pageRanges.isEmpty {
            // Convert all pages (1-indexed to 0-indexed)
            pagesToProcess = Array(0..<pageCount)
        } else {
            // Convert specified ranges (1-indexed to 0-indexed)
            pagesToProcess = pageRanges.flatMap { $0 }.map { $0 - 1 }.filter { $0 >= 0 && $0 < pageCount }
        }

        // Estimate disk space needed and memory requirements
        let estimatedSize = Int64(resolution * resolution * CGFloat(pagesToProcess.count) * 3)
        try checkDiskSpace(estimatedSize: estimatedSize)
        
        // Check for excessively large output that could cause memory issues
        let maxReasonablePages = 100
        let maxReasonableSize = Int64(200 * 1024 * 1024) // 200MB limit
        if pagesToProcess.count > maxReasonablePages {
            throw PDFError.invalidParameters("Too many pages selected (\(pagesToProcess.count)). Maximum is \(maxReasonablePages) pages.")
        }
        if estimatedSize > maxReasonableSize {
            throw PDFError.invalidParameters("Output would be too large (\(estimatedSize / 1024 / 1024)MB). Reduce resolution or page count.")
        }

        for (index, pageIndex) in pagesToProcess.enumerated() {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let pageBounds = page.bounds(for: .mediaBox)

            // Calculate size based on resolution (DPI)
            let scale = resolution / 72.0  // 72 DPI is default
            let imageSize = CGSize(
                width: pageBounds.width * scale,
                height: pageBounds.height * scale
            )

            // Render page to image with autoreleasepool for memory management
            let pageImage = autoreleasepool { () -> UIImage in
                let renderer = UIGraphicsImageRenderer(size: imageSize)
                return renderer.image { context in
                    UIColor.white.setFill()
                    context.fill(CGRect(origin: .zero, size: imageSize))

                    context.cgContext.scaleBy(x: scale, y: scale)
                    context.cgContext.translateBy(x: 0, y: pageBounds.height)
                    context.cgContext.scaleBy(x: 1.0, y: -1.0)

                    page.draw(with: .mediaBox, to: context.cgContext)
                }
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
            
            // Update progress for file save
            let fileProgress = Double(index + 1) / Double(pagesToProcess.count) * 0.9
            progressHandler(fileProgress)
            
            // Save to photo gallery (async, don't block main process)
            Task {
                try? await saveImageToPhotoLibrary(pageImage)
            }
            
            // Final progress update
            progressHandler(Double(index + 1) / Double(pagesToProcess.count))
        }

        return outputURLs
    }
    
    // MARK: - Photo Library Helper
    private func saveImageToPhotoLibrary(_ image: UIImage) async throws {
        // Request photo library access if needed
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        
        if status == .notDetermined {
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            guard newStatus == .authorized else {
                // Log permission denial but don't fail the entire process
                print("Photo library permission denied - images will not be saved to gallery")
                return
            }
        } else if status != .authorized {
            // Permission denied or restricted - skip saving
            print("Photo library access not authorized - skipping gallery save")
            return
        }
        
        // Save to photo library with retry logic
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            }
        } catch {
            // If saving to photos fails, log but don't crash the entire process
            print("Failed to save image to photo library: \(error.localizedDescription)")
            // Continue processing other images
        }
    }

    // MARK: - PDF Redaction
    public func redactPDF(
        _ pdfURL: URL,
        redactionItems: [String],
        redactionColor: UIColor = .black,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        
        guard let sourcePDF = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }
        
        let outputURL = temporaryOutputURL(prefix: "redacted")
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
            
            // Apply redactions
            if let pageText = page.string {
                for redactionItem in redactionItems {
                    if !redactionItem.isEmpty {
                        drawRedactionBoxes(for: redactionItem, in: pageText, pageBounds: pageBounds, context: context, redactionColor: redactionColor)
                    }
                }
            }
            
            progressHandler(Double(pageIndex + 1) / Double(pageCount))
        }
        
        return outputURL
    }
    
    private func drawRedactionBoxes(for searchText: String, in pageText: String, pageBounds: CGRect, context: CGContext, redactionColor: UIColor) {
        // This is a simplified implementation that draws redaction boxes over text
        // In a production app, you would use more sophisticated text detection
        
        let ranges = findTextRanges(searchText, in: pageText)
        
        for range in ranges {
            // Estimate text position (simplified - in production you'd use proper text layout)
            let relativePosition = Double(range.location) / Double(pageText.count)
            
            // Calculate approximate text bounds (this is a simplified approach)
            let textHeight: CGFloat = 20
            let textWidth: CGFloat = CGFloat(searchText.count) * 10
            
            let x = pageBounds.minX + (pageBounds.width * CGFloat(relativePosition))
            let y = pageBounds.minY + (pageBounds.height * 0.1) // Simplified positioning
            
            let redactionRect = CGRect(x: x, y: y, width: textWidth, height: textHeight)
            
            // Draw redaction box
            context.saveGState()
            context.setFillColor(redactionColor.cgColor)
            context.fill(redactionRect)
            context.restoreGState()
        }
    }
    
    private func findTextRanges(_ searchText: String, in text: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsText = text as NSString
        var searchRange = NSRange(location: 0, length: nsText.length)
        
        while searchRange.location < nsText.length {
            let foundRange = nsText.range(of: searchText, options: [.caseInsensitive], range: searchRange)
            if foundRange.location == NSNotFound {
                break
            }
            
            ranges.append(foundRange)
            searchRange.location = foundRange.location + foundRange.length
            searchRange.length = nsText.length - searchRange.location
        }
        
        return ranges
    }
    
    // MARK: - Form Filling
    public func fillFormFields(
        _ pdfURL: URL,
        formData: [String: String],
        stamps: [String], // Simplified stamp array
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {
        
        guard let sourcePDF = PDFDocument(url: pdfURL) else {
            throw PDFError.invalidPDF(pdfURL.lastPathComponent)
        }
        
        let outputURL = temporaryOutputURL(prefix: "form_filled")
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
            
            // Apply form data and stamps (simplified implementation)
            // In a full implementation, this would use form field coordinates and proper rendering
            
            progressHandler(Double(pageIndex + 1) / Double(pageCount))
        }
        
        return outputURL
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

    // MARK: - Validation Methods

    /// Validates that a PDF file exists and is not corrupted or password-protected
    public func validatePDF(url: URL) throws {
        // Handle security-scoped resources
        var startedAccessing = false
        if url.startAccessingSecurityScopedResource() {
            startedAccessing = true
        }
        
        defer {
            if startedAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
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
            print("⚠️ CorePDF: Could not determine available disk space, proceeding anyway")
            return
        }

        // Require at least 10 MB buffer beyond the estimated size (reduced from 50MB)
        // This is more reasonable for on-device processing
        let requiredSpace = estimatedSize + (10 * 1024 * 1024)
        
        // Only fail if we're really out of space (less than 1MB available)
        // This prevents false positives from conservative storage estimates
        if availableSpace < 1 * 1024 * 1024 {
            let neededMB = Double(requiredSpace - availableSpace) / (1024 * 1024)
            throw PDFError.insufficientStorage(neededMB: max(neededMB, 10.0))
        }
        
        // Warn if we're getting close but don't block
        if availableSpace < requiredSpace {
            print("⚠️ CorePDF: Low storage warning - available: \(availableSpace / 1024 / 1024)MB, required: \(requiredSpace / 1024 / 1024)MB")
            // Don't throw - proceed anyway and let the system handle it
        }
    }

    /// Gets available disk space in bytes
    private func getAvailableDiskSpace() throws -> Int64 {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        // Try to get available capacity - use both keys for better accuracy
        let values = try fileURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        // Prefer important usage capacity, but fall back to regular capacity
        // Important usage capacity is more conservative and may be lower
        if let importantCapacity = values.volumeAvailableCapacityForImportantUsage, importantCapacity > 0 {
            return importantCapacity
        }
        // Fall back to regular available capacity if important usage is not available
        // Explicitly cast to Int64 to match return type
        if let regularCapacity = values.volumeAvailableCapacity {
            return Int64(regularCapacity)
        }
        return Int64(0)
    }

    /// Gets file size in bytes
    public func getFileSize(url: URL) -> Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attributes[.size] as? Int64 else {
            return nil
        }
        return size
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
// All enum types are imported from CommonTypes module

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
    case invalidParameters(String)

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
            return String(format: "Insufficient storage space. Please free up at least %.1f MB and try again.", neededMB)
        case .invalidParameters(let message):
            return message
        }
    }
}
