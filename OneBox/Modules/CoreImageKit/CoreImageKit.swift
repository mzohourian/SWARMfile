//
//  CoreImageKit.swift
//  OneBox - CoreImageKit Module
//
//  Provides batch image processing: resize, compress, format conversion, EXIF stripping
//

import Foundation
import UIKit
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// MARK: - Image Processor
public actor ImageProcessor {

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

        var outputURLs: [URL] = []

        for (index, imageURL) in imageURLs.enumerated() {
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

        guard let imageSource = CGImageSourceCreateWithURL(imageURL as CFURL, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            throw ImageError.invalidImage(imageURL.lastPathComponent)
        }

        var processedImage = UIImage(cgImage: cgImage)

        // Resize if needed
        if let maxDim = maxDimension {
            processedImage = try resizeImage(processedImage, maxDimension: maxDim)
        } else if let percentage = resizePercentage {
            processedImage = try resizeImage(processedImage, percentage: percentage)
        }

        // Convert and save
        let outputURL = temporaryOutputURL(prefix: "image", format: format)

        guard let data = encodeImage(
            processedImage,
            format: format,
            quality: quality,
            stripEXIF: stripEXIF
        ) else {
            throw ImageError.encodingFailed
        }

        try data.write(to: outputURL)

        return outputURL
    }

    // MARK: - Resize Operations
    private func resizeImage(_ image: UIImage, maxDimension: Int) throws -> UIImage {
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
        let originalSize = image.size
        let newSize = CGSize(
            width: originalSize.width * CGFloat(percentage / 100),
            height: originalSize.height * CGFloat(percentage / 100)
        )

        return try resize(image, to: newSize)
    }

    private func resize(_ image: UIImage, to newSize: CGSize) throws -> UIImage {
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
}

// MARK: - Supporting Types
public enum ImageFormat: String, Codable {
    case jpeg
    case png
    case heic

    var fileExtension: String {
        switch self {
        case .jpeg: return "jpg"
        case .png: return "png"
        case .heic: return "heic"
        }
    }

    var displayName: String {
        switch self {
        case .jpeg: return "JPEG"
        case .png: return "PNG"
        case .heic: return "HEIC"
        }
    }
}

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
