//
//  CoreImageKit.swift
//  OneBox - CoreImageKit Module
//
//  Provides batch image processing: resize, compress, format conversion, EXIF stripping
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
import CoreImage
import ImageIO
import UniformTypeIdentifiers
import CommonTypes

// MARK: - Image Processor
public actor ImageProcessor {

    public init() {}

    private let context = CIContext(options: [
        .useSoftwareRenderer: false,
        .priorityRequestLow: false
    ])

    // MARK: - Batch Resize & Compress
    public func processImages(
        _ imageURLs: [URL],
        format: ImageFormat,
        quality: Double = 0.8,
        maxDimension: Int? = nil,
        resizePercentage: Double? = nil,
        stripEXIF: Bool = true,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> [URL] {
        // Validate input
        guard !imageURLs.isEmpty else {
            throw ImageError.invalidParameters("No images to process")
        }
        
        // Limit batch size to prevent memory issues
        let maxBatchSize = 100
        guard imageURLs.count <= maxBatchSize else {
            throw ImageError.invalidParameters("Too many images (\(imageURLs.count)). Maximum is \(maxBatchSize) images per batch.")
        }

        var outputURLs: [URL] = []
        var failedURLs: [URL] = []

        // Process images with memory management
        for (index, imageURL) in imageURLs.enumerated() {
            do {
                // Check memory pressure before processing each image
                let memoryPressure = await MainActor.run {
                    MemoryManager.shared.getMemoryPressureLevel()
                }
                if memoryPressure == .critical {
                    throw ImageError.invalidParameters("Device memory is critically low. Please close other apps and try again.")
                }
                
                // Process image (autoreleasepool is handled inside processImage if needed)
                let outputURL = try await processImage(
                    imageURL,
                    format: format,
                    quality: quality,
                    maxDimension: maxDimension,
                    resizePercentage: resizePercentage,
                    stripEXIF: stripEXIF
                )
                outputURLs.append(outputURL)
                progressHandler(Double(index + 1) / Double(imageURLs.count))
            } catch {
                // Log failure but continue with other images
                print("⚠️ CoreImageKit: Failed to process \(imageURL.lastPathComponent): \(error.localizedDescription)")
                failedURLs.append(imageURL)
                // Re-throw only if it's a critical error (storage, etc.)
                if case ImageError.insufficientStorage = error {
                    throw error
                }
            }
            
            // Explicitly release memory after each image
            // This helps prevent memory accumulation in large batches
            if index % 10 == 0 {
                // Periodically give the system a chance to clean up
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }
        
        // If all images failed, throw error
        guard !outputURLs.isEmpty else {
            if failedURLs.count == 1 {
                throw ImageError.invalidImage("Failed to process image: \(failedURLs.first!.lastPathComponent)")
            } else {
                throw ImageError.invalidImage("Failed to process all \(failedURLs.count) images")
            }
        }
        
        // If some images failed, log warning but return successful ones
        if !failedURLs.isEmpty {
            print("⚠️ CoreImageKit: Successfully processed \(outputURLs.count) of \(imageURLs.count) images. \(failedURLs.count) failed.")
        }

        return outputURLs
    }

    // MARK: - Single Image Processing
    public func processImage(
        _ imageURL: URL,
        format: ImageFormat,
        quality: Double = 0.8,
        maxDimension: Int? = nil,
        resizePercentage: Double? = nil,
        stripEXIF: Bool = true
    ) async throws -> URL {
        // Validate file exists and is readable
        guard FileManager.default.fileExists(atPath: imageURL.path) else {
            throw ImageError.invalidImage("File does not exist: \(imageURL.lastPathComponent)")
        }
        
        // Check file is readable
        guard FileManager.default.isReadableFile(atPath: imageURL.path) else {
            throw ImageError.invalidImage("File is not readable: \(imageURL.lastPathComponent)")
        }
        
        // Detect original format
        let originalFormat = detectFormat(from: imageURL)
        let originalFileSize: Int64?
        if let attributes = try? FileManager.default.attributesOfItem(atPath: imageURL.path),
           let size = attributes[.size] as? Int64 {
            originalFileSize = size
            guard size > 0 else {
                throw ImageError.invalidImage("File is empty: \(imageURL.lastPathComponent)")
            }
            // Warn but allow files up to 100MB (very large images)
            if size > 100 * 1024 * 1024 {
                print("⚠️ CoreImageKit: Large image file detected: \(size / 1024 / 1024)MB")
            }
        } else {
            originalFileSize = nil
        }
        
        // Warn if converting from JPEG/HEIC to PNG (will likely increase file size)
        if (originalFormat == .jpeg || originalFormat == .heic) && format == .png {
            print("⚠️ CoreImageKit: Converting from \(originalFormat.rawValue.uppercased()) to PNG. PNG files are typically 3-10x larger than compressed JPEG/HEIC files.")
        }

        // Process image with autoreleasepool for memory management
        let processedImage: UIImage = try autoreleasepool {
            guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
                throw ImageError.invalidImage(imageURL.lastPathComponent)
            }

            var image = UIImage(cgImage: cgImage)
            
            // Resize if needed
            if let maxDim = maxDimension {
                image = try resizeImage(image, maxDimension: maxDim)
            } else if let percentage = resizePercentage {
                image = try resizeImage(image, percentage: percentage)
            }
            
            return image
        }
        
        // Generate output URL outside autoreleasepool
        let finalOutputURL = temporaryOutputURL(prefix: "image", format: format)

        // Encode and save (outside autoreleasepool to keep processedImage)
        guard let data = encodeImage(
            processedImage,
            format: format,
            quality: quality,
            stripEXIF: stripEXIF
        ) else {
            throw ImageError.encodingFailed
        }
        
        // Check available disk space before writing
        let requiredSpace = Int64(data.count)
        if let availableSpace = try? getAvailableDiskSpace(), availableSpace < requiredSpace + (10 * 1024 * 1024) {
            throw ImageError.insufficientStorage(neededMB: Double(requiredSpace) / 1_000_000.0)
        }

        try data.write(to: finalOutputURL)
        
        // Log file size comparison if original format was different
        if let originalSize = originalFileSize {
            let newSize = Int64(data.count)
            let sizeChange = Double(newSize - originalSize) / Double(originalSize) * 100.0
            if abs(sizeChange) > 10 { // Only log if change is significant (>10%)
                if sizeChange > 0 {
                    print("⚠️ CoreImageKit: File size increased by \(String(format: "%.1f", sizeChange))% (\(originalSize / 1024)KB → \(newSize / 1024)KB)")
                } else {
                    print("✅ CoreImageKit: File size reduced by \(String(format: "%.1f", abs(sizeChange)))% (\(originalSize / 1024)KB → \(newSize / 1024)KB)")
                }
            }
        }
        
        return finalOutputURL
    }

    // MARK: - Resize Operations
    private func resizeImage(_ image: UIImage, maxDimension: Int) throws -> UIImage {
        // Validate maxDimension range (100-8192 pixels)
        guard maxDimension >= 100 && maxDimension <= 8192 else {
            throw ImageError.invalidParameters("Max dimension must be between 100 and 8192 pixels. Got: \(maxDimension)")
        }
        
        let originalSize = image.size
        let longerSide = max(originalSize.width, originalSize.height)

        guard longerSide > CGFloat(maxDimension) else {
            return image // No resize needed
        }

        let scale = CGFloat(maxDimension) / longerSide
        let newSize = CGSize(
            width: originalSize.width * scale,
            height: originalSize.height * scale
        )

        return try resize(image, to: newSize)
    }

    private func resizeImage(_ image: UIImage, percentage: Double) throws -> UIImage {
        // Validate percentage range (1-100)
        guard percentage > 0 && percentage <= 100 else {
            throw ImageError.invalidParameters("Resize percentage must be between 1% and 100%. Got: \(percentage)%")
        }
        
        let originalSize = image.size
        let newSize = CGSize(
            width: originalSize.width * CGFloat(percentage / 100),
            height: originalSize.height * CGFloat(percentage / 100)
        )

        return try resize(image, to: newSize)
    }

    private func resize(_ image: UIImage, to newSize: CGSize) throws -> UIImage {
        // Validate newSize is valid (positive, not zero, not too large)
        guard newSize.width > 0 && newSize.height > 0 else {
            throw ImageError.invalidParameters("Resize dimensions must be greater than zero. Got: \(newSize)")
        }
        
        // Prevent extremely large dimensions that would cause memory issues
        let maxDimension: CGFloat = 16384 // 16K max
        guard newSize.width <= maxDimension && newSize.height <= maxDimension else {
            throw ImageError.invalidParameters("Resize dimensions too large (max: \(Int(maxDimension))px). Got: \(Int(newSize.width))x\(Int(newSize.height)))")
        }
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        defer { UIGraphicsEndImageContext() }

        image.draw(in: CGRect(origin: .zero, size: newSize))

        guard let resizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            throw ImageError.resizeFailed
        }

        return resizedImage
    }

    // MARK: - Image Encoding
    private func encodeImage(
        _ image: UIImage,
        format: ImageFormat,
        quality: Double,
        stripEXIF: Bool
    ) -> Data? {

        guard let cgImage = image.cgImage else { return nil }

        let options: [CFString: Any] = stripEXIF ? [:] : [
            kCGImagePropertyOrientation: image.imageOrientation.cgImagePropertyOrientation
        ]

        switch format {
        case .jpeg:
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                data as CFMutableData,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else { return nil }

            let properties: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: quality
            ]

            CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
            CGImageDestinationFinalize(destination)

            return data as Data

        case .png:
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                data as CFMutableData,
                UTType.png.identifier as CFString,
                1,
                nil
            ) else { return nil }

            // Note: iOS automatically applies PNG compression (lossless)
            // PNG compression level is not directly controllable via ImageIO
            // The system optimizes compression automatically
            // Converting from JPEG/HEIC to PNG will typically result in larger files
            // because PNG is lossless while JPEG/HEIC are lossy (compressed)
            CGImageDestinationAddImage(destination, cgImage, options as CFDictionary)
            CGImageDestinationFinalize(destination)

            return data as Data

        case .heic:
            let data = NSMutableData()
            guard let destination = CGImageDestinationCreateWithData(
                data as CFMutableData,
                UTType.heic.identifier as CFString,
                1,
                nil
            ) else { return nil }

            let properties: [CFString: Any] = [
                kCGImageDestinationLossyCompressionQuality: quality
            ]

            CGImageDestinationAddImage(destination, cgImage, properties as CFDictionary)
            CGImageDestinationFinalize(destination)

            return data as Data
        }
    }

    // MARK: - EXIF Operations
    public func stripEXIFData(from imageURL: URL) async throws -> URL {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ImageError.invalidImage(imageURL.lastPathComponent)
        }

        let outputURL = temporaryOutputURL(prefix: "stripped", format: .jpeg)
        let data = NSMutableData()

        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageError.encodingFailed
        }

        // Add image without metadata
        CGImageDestinationAddImage(destination, cgImage, [:] as CFDictionary)
        CGImageDestinationFinalize(destination)

        try data.write(to: outputURL)

        return outputURL
    }

    // MARK: - Format Conversion
    public func convertFormat(
        _ imageURL: URL,
        to format: ImageFormat,
        quality: Double = 0.8,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> URL {

        let outputURL = try await processImage(
            imageURL,
            format: format,
            quality: quality,
            stripEXIF: false
        )

        progressHandler(1.0)

        return outputURL
    }

    // MARK: - Image Info
    public func getImageInfo(_ imageURL: URL) async throws -> ImageInfo {
        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            throw ImageError.invalidImage(imageURL.lastPathComponent)
        }

        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            throw ImageError.metadataReadFailed
        }

        let width = properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0
        let hasEXIF = properties[kCGImagePropertyExifDictionary as String] != nil

        let attributes = try FileManager.default.attributesOfItem(atPath: imageURL.path)
        let fileSize = attributes[.size] as? Int64 ?? 0

        return ImageInfo(
            width: width,
            height: height,
            fileSize: fileSize,
            hasEXIF: hasEXIF,
            format: detectFormat(from: imageURL)
        )
    }

    private func detectFormat(from url: URL) -> ImageFormat {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "heic", "heif": return .heic
        case "png": return .png
        default: return .jpeg
        }
    }

    // MARK: - Helper Methods
    private func temporaryOutputURL(prefix: String, format: ImageFormat) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let ext = format.fileExtension
        let filename = "\(prefix)_\(UUID().uuidString).\(ext)"
        return tempDir.appendingPathComponent(filename)
    }
    
    private func getAvailableDiskSpace() throws -> Int64 {
        let fileURL = URL(fileURLWithPath: NSHomeDirectory() as String)
        let values = try fileURL.resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeAvailableCapacityKey
        ])
        // Prefer important usage capacity, but fall back to regular capacity
        if let importantCapacity = values.volumeAvailableCapacityForImportantUsage, importantCapacity > 0 {
            return importantCapacity
        }
        if let regularCapacity = values.volumeAvailableCapacity {
            return Int64(regularCapacity)
        }
        return Int64(0)
    }
}

// MARK: - Supporting Types
// All enum types are imported from CommonTypes module

public struct ImageInfo {
    public let width: Int
    public let height: Int
    public let fileSize: Int64
    public let hasEXIF: Bool
    public let format: ImageFormat

    var fileSizeMB: Double {
        Double(fileSize) / 1_000_000
    }

    var megapixels: Double {
        Double(width * height) / 1_000_000
    }
}

// MARK: - Image Error
public enum ImageError: LocalizedError {
    case invalidImage(String)
    case resizeFailed
    case encodingFailed
    case metadataReadFailed
    case invalidParameters(String)
    case insufficientStorage(neededMB: Double)

    public var errorDescription: String? {
        switch self {
        case .invalidImage(let name):
            return "Invalid or corrupted image: \(name)"
        case .resizeFailed:
            return "Failed to resize image"
        case .encodingFailed:
            return "Failed to encode image"
        case .metadataReadFailed:
            return "Failed to read image metadata"
        case .invalidParameters(let message):
            return "Invalid parameters: \(message)"
        case .insufficientStorage(let neededMB):
            return "Not enough storage space. Need at least \(String(format: "%.1f", neededMB))MB free space."
        }
    }
}

// MARK: - UIImage Extension
extension UIImage.Orientation {
    var cgImagePropertyOrientation: Int {
        switch self {
        case .up: return 1
        case .down: return 3
        case .left: return 8
        case .right: return 6
        case .upMirrored: return 2
        case .downMirrored: return 4
        case .leftMirrored: return 5
        case .rightMirrored: return 7
        @unknown default: return 1
        }
    }
}
