//
//  CoreImageKitPerformanceTests.swift
//  OneBox - Performance Benchmarks for Image Processing
//

import XCTest
@testable import CoreImageKit
@testable import CommonTypes
import UIKit

@MainActor
final class CoreImageKitPerformanceTests: XCTestCase {

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
    
    // MARK: - Test Data Creation
    
    private func createTestImages() throws -> [URL] {
        var urls: [URL] = []
        
        // Create images of various sizes and formats for realistic testing
        let configurations = [
            (width: 640, height: 480, format: "jpg", quality: 0.8, count: 20),     // VGA
            (width: 1920, height: 1080, format: "jpg", quality: 0.9, count: 20),  // Full HD
            (width: 3024, height: 4032, format: "jpg", quality: 0.9, count: 10),  // iPhone 12MP
            (width: 4000, height: 6000, format: "png", quality: 1.0, count: 5),   // High-res PNG
        ]
        
        for (configIndex, config) in configurations.enumerated() {
            for imageIndex in 0..<config.count {
                let image = createTestImage(
                    width: config.width,
                    height: config.height,
                    index: configIndex * 100 + imageIndex
                )
                
                let fileName = "perf_test_\(config.width)x\(config.height)_\(imageIndex).\(config.format)"
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
                
                let imageData: Data?
                if config.format == "png" {
                    imageData = image.pngData()
                } else {
                    imageData = image.jpegData(compressionQuality: config.quality)
                }
                
                if let data = imageData {
                    try data.write(to: url)
                    urls.append(url)
                }
            }
        }
        
        return urls
    }
    
    private func createTestImage(width: Int, height: Int, index: Int) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Create realistic image content
        // Background gradient
        let colors = [
            UIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1.0).cgColor,
            UIColor(red: 0.8, green: 0.2, blue: 0.4, alpha: 1.0).cgColor
        ]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        
        // Add text content
        let fontSize = max(12, CGFloat(width) / 40)
        let text = "Performance Test Image \(index)\nResolution: \(width)x\(height)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: UIColor.white,
            .backgroundColor: UIColor.black.withAlphaComponent(0.7)
        ]
        
        let textRect = CGRect(x: 20, y: 20, width: width - 40, height: Int(fontSize * 3))
        text.draw(in: textRect, withAttributes: attributes)
        
        // Add geometric shapes for visual complexity
        let shapeCount = min(10, width / 200)
        for i in 0..<shapeCount {
            let shapeColor = UIColor(
                hue: CGFloat(i) / CGFloat(shapeCount),
                saturation: 0.8,
                brightness: 0.9,
                alpha: 0.7
            )
            shapeColor.setFill()
            
            let size = CGFloat(width) / 10
            let x = CGFloat.random(in: 0...(CGFloat(width) - size))
            let y = CGFloat.random(in: 0...(CGFloat(height) - size))
            
            if i % 2 == 0 {
                context.fillEllipse(in: CGRect(x: x, y: y, width: size, height: size))
            } else {
                context.fill(CGRect(x: x, y: y, width: size, height: size))
            }
        }
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    // MARK: - Batch Processing Performance Tests
    
    func testBatchResizePerformanceSmall() throws {
        // Process 20 VGA images - should be fast
        let vgaImages = testImageURLs.filter { $0.lastPathComponent.contains("640x480") }
        
        measure {
            let expectation = expectation(description: "Small batch resize")
            
            Task {
                do {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    _ = try await processor.processImages(
                        Array(vgaImages.prefix(20)),
                        format: .jpeg,
                        quality: 0.8,
                        maxDimension: 400,
                        progressHandler: { _ in }
                    )
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    print("📊 20 VGA images resized in \(String(format: "%.2f", duration))s")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Small batch test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    func testBatchResizePerformanceLarge() throws {
        // Process 10 iPhone resolution images
        let iphoneImages = testImageURLs.filter { $0.lastPathComponent.contains("3024x4032") }
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let expectation = expectation(description: "Large batch resize")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            startMeasuring()
            
            Task {
                do {
                    _ = try await processor.processImages(
                        Array(iphoneImages.prefix(10)),
                        format: .jpeg,
                        quality: 0.8,
                        maxDimension: 2048,
                        progressHandler: { progress in
                            if Int(progress * 100) % 20 == 0 {
                                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                                print("📈 Progress: \(Int(progress * 100))% (\(String(format: "%.2f", elapsed))s)")
                            }
                        }
                    )
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    print("📊 10 iPhone-res images processed in \(String(format: "%.2f", duration))s")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Large batch test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 45.0)
            stopMeasuring()
        }
    }
    
    func testBatchProcessingMemoryEfficiency() throws {
        // Test memory usage with many high-resolution images
        let highResImages = testImageURLs.filter { url in
            url.lastPathComponent.contains("4000x6000") || url.lastPathComponent.contains("3024x4032")
        }
        
        measure {
            let expectation = expectation(description: "Memory efficient batch processing")
            
            Task {
                do {
                    let startMemory = getMemoryUsage()
                    
                    _ = try await processor.processImages(
                        Array(highResImages.prefix(15)), // Mix of high-res images
                        format: .jpeg,
                        quality: 0.7,
                        maxDimension: 1024,
                        progressHandler: { [self] progress in
                            if Int(progress * 100) % 10 == 0 {
                                let currentMemory = self.getMemoryUsage()
                                let memoryIncrease = currentMemory - startMemory
                                print("🧠 Memory at \(Int(progress * 100))%: \(currentMemory)MB (+\(memoryIncrease)MB)")
                            }
                        }
                    )
                    
                    let endMemory = getMemoryUsage()
                    print("📊 Memory usage: Start \(startMemory)MB → End \(endMemory)MB")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Memory efficiency test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 60.0)
        }
    }
    
    // MARK: - Format Conversion Performance Tests
    
    func testFormatConversionPerformance() throws {
        // Test conversion between different formats
        let conversionTests = [
            (from: "jpg", to: ImageFormat.png, quality: 1.0),
            (from: "png", to: ImageFormat.jpeg, quality: 0.8),
            (from: "jpg", to: ImageFormat.heic, quality: 0.9)
        ]
        
        for (testIndex, test) in conversionTests.enumerated() {
            let sourceImages = testImageURLs.filter { $0.pathExtension.lowercased() == test.from }
            
            measure {
                let expectation = expectation(description: "Format conversion \(test.from) → \(test.to)")
                
                Task {
                    do {
                        let startTime = CFAbsoluteTimeGetCurrent()
                        
                        _ = try await processor.processImages(
                            Array(sourceImages.prefix(10)),
                            format: test.to,
                            quality: test.quality,
                            progressHandler: { _ in }
                        )
                        
                        let duration = CFAbsoluteTimeGetCurrent() - startTime
                        print("📊 \(test.from.uppercased()) → \(test.to.rawValue.uppercased()) conversion in \(String(format: "%.2f", duration))s")
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("Format conversion test \(testIndex) failed: \(error)")
                    }
                }
                
                wait(for: [expectation], timeout: 30.0)
            }
        }
    }
    
    // MARK: - Quality vs Performance Tests
    
    func testQualityVsPerformanceTradeoff() throws {
        // Test different quality settings and their performance impact
        let qualityLevels: [(quality: Double, label: String)] = [
            (0.3, "low"),
            (0.6, "medium"),
            (0.9, "high"),
            (1.0, "maximum")
        ]
        
        let testImages = Array(testImageURLs.filter { $0.lastPathComponent.contains("1920x1080") }.prefix(10))
        
        for qualityTest in qualityLevels {
            measure {
                let expectation = expectation(description: "Quality \(qualityTest.label)")
                
                Task {
                    do {
                        let startTime = CFAbsoluteTimeGetCurrent()
                        
                        let outputURLs = try await processor.processImages(
                            testImages,
                            format: .jpeg,
                            quality: qualityTest.quality,
                            maxDimension: 1024,
                            progressHandler: { _ in }
                        )
                        
                        let duration = CFAbsoluteTimeGetCurrent() - startTime
                        
                        // Calculate average file size
                        let totalSize = outputURLs.reduce(0) { total, url in
                            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? 0
                            return total + size
                        }
                        let avgSizeKB = totalSize / outputURLs.count / 1024
                        
                        print("📊 Quality \(qualityTest.label) (\(String(format: "%.1f", qualityTest.quality * 100))%): \(String(format: "%.2f", duration))s, avg size: \(avgSizeKB)KB")
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("Quality test failed: \(error)")
                    }
                }
                
                wait(for: [expectation], timeout: 20.0)
            }
        }
    }
    
    // MARK: - Resize Strategy Performance Tests
    
    func testResizeStrategyComparison() throws {
        // Compare percentage vs max dimension resize strategies
        let largeImages = testImageURLs.filter { $0.lastPathComponent.contains("3024x4032") }
        
        let resizeTests: [(type: String, maxDim: Int?, percentage: Double?)] = [
            (type: "maxDimension", maxDim: 1024, percentage: nil),
            (type: "percentage", maxDim: nil, percentage: 50.0),
            (type: "maxDimension", maxDim: 2048, percentage: nil),
            (type: "percentage", maxDim: nil, percentage: 25.0)
        ]
        
        for test in resizeTests {
            measure {
                let expectation = expectation(description: "Resize \(test.type)")
                
                Task {
                    do {
                        let startTime = CFAbsoluteTimeGetCurrent()
                        
                        _ = try await processor.processImages(
                            Array(largeImages.prefix(5)),
                            format: .jpeg,
                            quality: 0.8,
                            maxDimension: test.maxDim,
                            resizePercentage: test.percentage,
                            progressHandler: { _ in }
                        )
                        
                        let duration = CFAbsoluteTimeGetCurrent() - startTime
                        
                        if let maxDim = test.maxDim {
                            print("📊 Max dimension \(maxDim)px: \(String(format: "%.2f", duration))s")
                        } else if let percentage = test.percentage {
                            print("📊 Resize \(String(format: "%.0f", percentage))%: \(String(format: "%.2f", duration))s")
                        }
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("Resize strategy test failed: \(error)")
                    }
                }
                
                wait(for: [expectation], timeout: 25.0)
            }
        }
    }
    
    // MARK: - Concurrent Processing Tests
    
    func testConcurrentProcessingPerformance() throws {
        // Test multiple concurrent image processing operations
        let imageGroups = [
            Array(testImageURLs.filter { $0.lastPathComponent.contains("640x480") }.prefix(5)),
            Array(testImageURLs.filter { $0.lastPathComponent.contains("1920x1080") }.prefix(3)),
            Array(testImageURLs.filter { $0.lastPathComponent.contains("3024x4032") }.prefix(2))
        ]
        
        measure {
            let expectations = imageGroups.enumerated().map { index, _ in
                expectation(description: "Concurrent group \(index)")
            }
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            for (index, imageGroup) in imageGroups.enumerated() {
                Task {
                    do {
                        _ = try await processor.processImages(
                            imageGroup,
                            format: .jpeg,
                            quality: 0.8,
                            maxDimension: 800,
                            progressHandler: { _ in }
                        )
                        expectations[index].fulfill()
                    } catch {
                        XCTFail("Concurrent processing group \(index) failed: \(error)")
                    }
                }
            }
            
            wait(for: expectations, timeout: 30.0)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("📊 Concurrent processing completed in \(String(format: "%.2f", duration))s")
        }
    }
    
    // MARK: - EXIF Processing Performance Tests
    
    func testEXIFStrippingPerformance() throws {
        // Test performance impact of EXIF data stripping
        let testImages = Array(testImageURLs.filter { $0.lastPathComponent.contains("jpg") }.prefix(20))
        
        let exifTests = [
            (stripEXIF: false, label: "with EXIF"),
            (stripEXIF: true, label: "without EXIF")
        ]
        
        for test in exifTests {
            measure {
                let expectation = expectation(description: "EXIF processing \(test.label)")
                
                Task {
                    do {
                        let startTime = CFAbsoluteTimeGetCurrent()
                        
                        _ = try await processor.processImages(
                            testImages,
                            format: .jpeg,
                            quality: 0.8,
                            stripEXIF: test.stripEXIF,
                            progressHandler: { _ in }
                        )
                        
                        let duration = CFAbsoluteTimeGetCurrent() - startTime
                        print("📊 Processing \(test.label): \(String(format: "%.2f", duration))s")
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("EXIF test failed: \(error)")
                    }
                }
                
                wait(for: [expectation], timeout: 20.0)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func getMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) / 1024 / 1024 : 0
    }
}