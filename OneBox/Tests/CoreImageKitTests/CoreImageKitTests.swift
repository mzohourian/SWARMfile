//
//  CoreImageKitTests.swift
//  OneBox - CoreImageKit Module Tests
//

import XCTest
import UIKit
@testable import CoreImageKit
@testable import CommonTypes

final class CoreImageKitTests: XCTestCase {
    
    var processor: ImageProcessor!
    var testImageURLs: [URL]!
    
    override func setUp() async throws {
        processor = ImageProcessor()
        testImageURLs = try createTestImages()
    }
    
    override func tearDown() async throws {
        // Clean up test files
        for url in testImageURLs ?? [] {
            try? FileManager.default.removeItem(at: url)
        }
        testImageURLs = nil
        processor = nil
    }
    
    // MARK: - Test Image Creation
    
    private func createTestImages() throws -> [URL] {
        var urls: [URL] = []
        
        // Create test images of different sizes and formats
        let sizes: [(width: Int, height: Int)] = [
            (100, 100),
            (500, 500),
            (1024, 768),
            (2048, 1536)
        ]
        
        for (index, size) in sizes.enumerated() {
            let image = createTestImage(width: size.width, height: size.height, color: .systemBlue)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_image_\(index).jpg")
            
            if let data = image.jpegData(compressionQuality: 0.9) {
                try data.write(to: url)
                urls.append(url)
            }
        }
        
        return urls
    }
    
    private func createTestImage(width: Int, height: Int, color: UIColor) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        // Draw some text to make it visually distinct
        let text = "\(width)x\(height)" as NSString
        let attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 20)
        ]
        text.draw(at: CGPoint(x: 10, y: 10), withAttributes: attributes)
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    // MARK: - Basic Processing Tests
    
    func testProcessImagesWithResize() async throws {
        // Given
        let maxDimension = 800
        
        // When
        let outputURLs = try await processor.processImages(
            testImageURLs,
            format: .jpeg,
            quality: 0.8,
            maxDimension: maxDimension,
            resizePercentage: nil,
            stripEXIF: true,
            progressHandler: { _ in }
        )
        
        // Then
        XCTAssertEqual(outputURLs.count, testImageURLs.count)
        
        // Verify each output image
        for url in outputURLs {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            
            // Check dimensions
            if let image = UIImage(contentsOfFile: url.path) {
                let maxDim = max(image.size.width, image.size.height)
                XCTAssertLessThanOrEqual(maxDim, CGFloat(maxDimension))
            }
        }
    }
    
    func testProcessImagesWithPercentageResize() async throws {
        // Given
        let percentage = 50.0
        
        // When
        let outputURLs = try await processor.processImages(
            [testImageURLs[2]], // Use 1024x768 image
            format: .jpeg,
            quality: 0.8,
            maxDimension: nil,
            resizePercentage: percentage,
            stripEXIF: true,
            progressHandler: { _ in }
        )
        
        // Then
        XCTAssertEqual(outputURLs.count, 1)
        
        if let originalImage = UIImage(contentsOfFile: testImageURLs[2].path),
           let resizedImage = UIImage(contentsOfFile: outputURLs[0].path) {
            XCTAssertEqual(resizedImage.size.width, originalImage.size.width * 0.5, accuracy: 1.0)
            XCTAssertEqual(resizedImage.size.height, originalImage.size.height * 0.5, accuracy: 1.0)
        }
    }
    
    // MARK: - Format Conversion Tests
    
    func testFormatConversionToJPEG() async throws {
        // Given - create PNG test image
        let pngImage = createTestImage(width: 200, height: 200, color: .systemRed)
        let pngURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.png")
        try pngImage.pngData()?.write(to: pngURL)
        
        // When
        let outputURLs = try await processor.processImages(
            [pngURL],
            format: .jpeg,
            quality: 0.8,
            progressHandler: { _ in }
        )
        
        // Then
        XCTAssertEqual(outputURLs.count, 1)
        XCTAssertEqual(outputURLs[0].pathExtension.lowercased(), "jpg")
        
        // Clean up
        try? FileManager.default.removeItem(at: pngURL)
    }
    
    func testFormatConversionToPNG() async throws {
        // Given
        let jpegURL = testImageURLs[0]
        
        // When
        let outputURLs = try await processor.processImages(
            [jpegURL],
            format: .png,
            quality: 1.0, // PNG is lossless, quality doesn't matter
            progressHandler: { _ in }
        )
        
        // Then
        XCTAssertEqual(outputURLs.count, 1)
        XCTAssertEqual(outputURLs[0].pathExtension.lowercased(), "png")
    }
    
    // MARK: - Quality Tests
    
    func testQualitySettings() async throws {
        // Given
        let qualities: [Double] = [0.1, 0.5, 1.0]
        var fileSizes: [Int] = []
        
        // When - process same image with different qualities
        for quality in qualities {
            let outputURLs = try await processor.processImages(
                [testImageURLs[2]], // Use larger image
                format: .jpeg,
                quality: quality,
                progressHandler: { _ in }
            )
            
            let fileSize = try FileManager.default.attributesOfItem(atPath: outputURLs[0].path)[.size] as! Int
            fileSizes.append(fileSize)
        }
        
        // Then - higher quality should result in larger file size
        XCTAssertLessThan(fileSizes[0], fileSizes[1])
        XCTAssertLessThan(fileSizes[1], fileSizes[2])
    }
    
    // MARK: - Error Handling Tests
    
    func testEmptyInputArray() async throws {
        // Given
        let emptyArray: [URL] = []
        
        // When/Then
        do {
            _ = try await processor.processImages(
                emptyArray,
                format: .jpeg,
                quality: 0.8,
                progressHandler: { _ in }
            )
            XCTFail("Should throw error for empty input")
        } catch {
            XCTAssertTrue(error is ImageError)
            if case ImageError.invalidParameters(let message) = error {
                XCTAssertTrue(message.contains("No images"))
            }
        }
    }
    
    func testTooManyImages() async throws {
        // Given - create array with more than 100 URLs
        var tooManyURLs: [URL] = []
        for i in 0..<101 {
            tooManyURLs.append(URL(fileURLWithPath: "/tmp/fake_\(i).jpg"))
        }
        
        // When/Then
        do {
            _ = try await processor.processImages(
                tooManyURLs,
                format: .jpeg,
                quality: 0.8,
                progressHandler: { _ in }
            )
            XCTFail("Should throw error for too many images")
        } catch {
            XCTAssertTrue(error is ImageError)
            if case ImageError.invalidParameters(let message) = error {
                XCTAssertTrue(message.contains("Too many images"))
                XCTAssertTrue(message.contains("100"))
            }
        }
    }
    
    func testInvalidImageFile() async throws {
        // Given - create invalid image file
        let invalidURL = FileManager.default.temporaryDirectory.appendingPathComponent("invalid.jpg")
        try "Not an image".write(to: invalidURL, atomically: true, encoding: .utf8)
        
        // When/Then
        do {
            _ = try await processor.processImages(
                [invalidURL],
                format: .jpeg,
                quality: 0.8,
                progressHandler: { _ in }
            )
            XCTFail("Should throw error for invalid image")
        } catch {
            XCTAssertTrue(error is ImageError)
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: invalidURL)
    }
    
    // MARK: - Progress Reporting Tests
    
    func testProgressReporting() async throws {
        // Given
        var progressValues: [Double] = []
        let expectation = expectation(description: "Progress reported")
        expectation.expectedFulfillmentCount = testImageURLs.count
        
        // When
        _ = try await processor.processImages(
            testImageURLs,
            format: .jpeg,
            quality: 0.8,
            progressHandler: { progress in
                progressValues.append(progress)
                expectation.fulfill()
            }
        )
        
        // Then
        await fulfillment(of: [expectation], timeout: 5.0)
        XCTAssertEqual(progressValues.count, testImageURLs.count)
        XCTAssertTrue(progressValues.allSatisfy { $0 > 0 && $0 <= 1.0 })
    }
    
    // MARK: - EXIF Stripping Tests
    
    func testEXIFStripping() async throws {
        // Given - create image with EXIF data
        let imageWithEXIF = createTestImageWithEXIF()
        
        // When
        let outputURLs = try await processor.processImages(
            [imageWithEXIF],
            format: .jpeg,
            quality: 0.8,
            stripEXIF: true,
            progressHandler: { _ in }
        )
        
        // Then - verify EXIF is stripped
        let hasEXIF = checkForEXIFData(at: outputURLs[0])
        XCTAssertFalse(hasEXIF, "EXIF data should be stripped")
        
        // Clean up
        try? FileManager.default.removeItem(at: imageWithEXIF)
    }
    
    func testEXIFPreservation() async throws {
        // Given
        let imageWithEXIF = createTestImageWithEXIF()
        
        // When
        let outputURLs = try await processor.processImages(
            [imageWithEXIF],
            format: .jpeg,
            quality: 0.8,
            stripEXIF: false,
            progressHandler: { _ in }
        )
        
        // Then - verify EXIF is preserved
        let hasEXIF = checkForEXIFData(at: outputURLs[0])
        XCTAssertTrue(hasEXIF, "EXIF data should be preserved")
        
        // Clean up
        try? FileManager.default.removeItem(at: imageWithEXIF)
    }
    
    // MARK: - Performance Tests
    
    func testBatchProcessingPerformance() throws {
        // Given
        let largeImage = createTestImage(width: 4000, height: 3000, color: .systemGreen)
        var largeImageURLs: [URL] = []
        
        // Create 10 large images
        for i in 0..<10 {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("large_\(i).jpg")
            try largeImage.jpegData(compressionQuality: 0.9)?.write(to: url)
            largeImageURLs.append(url)
        }
        
        // When/Then - measure performance
        measure {
            let expectation = self.expectation(description: "Batch processing completed")
            
            Task {
                do {
                    _ = try await processor.processImages(
                        largeImageURLs,
                        format: .jpeg,
                        quality: 0.7,
                        maxDimension: 2000,
                        progressHandler: { _ in }
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
        
        // Clean up
        for url in largeImageURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }
    
    // MARK: - Helper Methods
    
    private func createTestImageWithEXIF() -> URL {
        let image = createTestImage(width: 300, height: 300, color: .systemOrange)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("exif_test.jpg")
        
        // Create image with EXIF metadata
        if let data = image.jpegData(compressionQuality: 0.9),
           let source = CGImageSourceCreateWithData(data as CFData, nil),
           let uti = CGImageSourceGetType(source) {
            
            let destinationURL = url as CFURL
            if let destination = CGImageDestinationCreateWithURL(destinationURL, uti, 1, nil) {
                
                // Add EXIF metadata
                let exifData: [String: Any] = [
                    kCGImagePropertyExifDictionary as String: [
                        kCGImagePropertyExifUserComment as String: "Test EXIF data",
                        kCGImagePropertyExifDateTimeOriginal as String: "2024:01:01 12:00:00"
                    ]
                ]
                
                CGImageDestinationAddImageFromSource(destination, source, 0, exifData as CFDictionary)
                CGImageDestinationFinalize(destination)
            }
        }
        
        return url
    }
    
    private func checkForEXIFData(at url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return false
        }
        
        return properties[kCGImagePropertyExifDictionary as String] != nil
    }
}