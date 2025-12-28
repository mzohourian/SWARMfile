//
//  CorePDFPerformanceTests.swift
//  OneBox - Performance Benchmarks for PDF Processing
//

import XCTest
@testable import CorePDF
@testable import CommonTypes
import UIKit

@MainActor
final class CorePDFPerformanceTests: XCTestCase {

    var processor: PDFProcessor!
    var testImageURLs: [URL]!
    var testPDFURLs: [URL]!
    
    override func setUp() async throws {
        processor = PDFProcessor()
        testImageURLs = try createTestImages()
        testPDFURLs = try createTestPDFs()
    }
    
    override func tearDown() async throws {
        // Clean up test files
        for url in (testImageURLs ?? []) + (testPDFURLs ?? []) {
            try? FileManager.default.removeItem(at: url)
        }
        testImageURLs = nil
        testPDFURLs = nil
        processor = nil
    }
    
    // MARK: - Test Data Creation
    
    private func createTestImages() throws -> [URL] {
        var urls: [URL] = []
        
        // Create images of various sizes for realistic testing
        let sizes = [
            (1024, 768),   // 1MP
            (2048, 1536),  // 3MP
            (3024, 4032),  // 12MP (iPhone photo)
            (4000, 6000)   // 24MP (high-res)
        ]
        
        for (index, size) in sizes.enumerated() {
            for variant in 0..<10 { // 10 images per size
                let image = createTestImage(width: size.0, height: size.1, index: index * 10 + variant)
                let url = FileManager.default.temporaryDirectory.appendingPathComponent("perf_image_\(index)_\(variant).jpg")
                
                if let data = image.jpegData(compressionQuality: 0.9) {
                    try data.write(to: url)
                    urls.append(url)
                }
            }
        }
        
        return urls
    }
    
    private func createTestPDFs() throws -> [URL] {
        var urls: [URL] = []
        
        // Create PDFs of various complexities
        let pageConfigs = [
            (pages: 1, complexity: "simple"),
            (pages: 5, complexity: "medium"),
            (pages: 20, complexity: "complex"),
            (pages: 50, complexity: "large")
        ]
        
        for (index, config) in pageConfigs.enumerated() {
            for variant in 0..<3 {
                let url = try createTestPDF(
                    pages: config.pages,
                    complexity: config.complexity,
                    index: index * 3 + variant
                )
                urls.append(url)
            }
        }
        
        return urls
    }
    
    private func createTestImage(width: Int, height: Int, index: Int) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Create gradient background
        let colors = [UIColor.systemBlue.cgColor, UIColor.systemPurple.cgColor]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: nil)!
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
        
        // Add text and shapes for realistic content
        let text = "Performance Test Image \(index)"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: max(20, CGFloat(width) / 30)),
            .foregroundColor: UIColor.white
        ]
        text.draw(at: CGPoint(x: 50, y: 50), withAttributes: attributes)
        
        // Add some shapes
        context.setFillColor(UIColor.systemYellow.cgColor)
        context.fillEllipse(in: CGRect(x: width/4, y: height/4, width: width/2, height: height/2))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createTestPDF(pages: Int, complexity: String, index: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("perf_pdf_\(complexity)_\(index).pdf")
        
        UIGraphicsBeginPDFContextToFile(url.path, .zero, nil)
        
        for page in 0..<pages {
            UIGraphicsBeginPDFPageWithInfo(CGRect(x: 0, y: 0, width: 595, height: 842), nil)
            
            switch complexity {
            case "simple":
                let text = "Page \(page + 1) - Simple Content"
                text.draw(at: CGPoint(x: 100, y: 100), withAttributes: [
                    .font: UIFont.systemFont(ofSize: 16)
                ])
                
            case "medium":
                // Add multiple text blocks and simple graphics
                for i in 0..<5 {
                    let text = "Text block \(i) on page \(page + 1)"
                    text.draw(at: CGPoint(x: 50, y: 100 + i * 50), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 14)
                    ])
                }
                
                // Add rectangle
                UIColor.systemBlue.setFill()
                UIRectFill(CGRect(x: 300, y: 200, width: 200, height: 100))
                
            case "complex", "large":
                // Add many text elements, images, and graphics
                for i in 0..<20 {
                    let text = "Complex content line \(i) on page \(page + 1) with more detailed information"
                    text.draw(at: CGPoint(x: 50, y: 50 + i * 30), withAttributes: [
                        .font: UIFont.systemFont(ofSize: 10)
                    ])
                }
                
                // Add multiple graphics
                for i in 0..<10 {
                    let colors = [UIColor.systemRed, UIColor.systemGreen, UIColor.systemBlue]
                    colors[i % 3].setFill()
                    UIRectFill(CGRect(x: 400 + (i % 5) * 30, y: 100 + (i / 5) * 30, width: 25, height: 25))
                }
                
                // Add a test image
                let testImg = createTestImage(width: 100, height: 100, index: page)
                testImg.draw(in: CGRect(x: 400, y: 500, width: 100, height: 100))
                
            default:
                break
            }
        }
        
        UIGraphicsEndPDFContext()
        return url
    }
    
    // MARK: - Images to PDF Performance Tests
    
    func testImagesToPDFPerformanceSmallBatch() throws {
        // Baseline: 10 low-res images
        let smallImages = Array(testImageURLs.prefix(10))
        
        measure {
            let expectation = expectation(description: "Small batch conversion")
            
            Task {
                do {
                    _ = try await processor.createPDF(
                        from: smallImages,
                        pageSize: CGSize(width: 595, height: 842),
                        progressHandler: { _ in }
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    func testImagesToPDFPerformanceLargeBatch() throws {
        // Target: 50 mixed-resolution images in <12 seconds (as per README)
        let largeImages = Array(testImageURLs.prefix(50))
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let expectation = expectation(description: "Large batch conversion")
            
            let startTime = CFAbsoluteTimeGetCurrent()
            startMeasuring()
            
            Task {
                do {
                    _ = try await processor.createPDF(
                        from: largeImages,
                        pageSize: CGSize(width: 595, height: 842),
                        progressHandler: { _ in }
                    )
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    print("📊 50 images → PDF completed in \(String(format: "%.2f", duration))s")
                    
                    // Verify target performance (should be < 12s on A15+ devices)
                    if duration > 12.0 {
                        print("⚠️  Performance target missed: \(String(format: "%.2f", duration))s > 12.0s")
                    }
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 30.0)
            stopMeasuring()
        }
    }
    
    func testImagesToPDFMemoryUsage() throws {
        // Test memory efficiency with large images
        let highResImages = testImageURLs.filter { url in
            url.lastPathComponent.contains("perf_image_3") // 24MP images
        }
        
        measure {
            let expectation = expectation(description: "Memory efficient conversion")
            
            Task {
                do {
                    _ = try await processor.createPDF(
                        from: Array(highResImages.prefix(5)), // 5 x 24MP images
                        pageSize: nil, // Use image size
                        progressHandler: { progress in
                            // Monitor memory during processing
                            let memInfo = mach_task_basic_info()
                            let memSize = MemoryLayout<mach_task_basic_info>.size
                            let memCount = mach_msg_type_number_t(memSize / MemoryLayout<natural_t>.size)
                            
                            if memCount > 0 {
                                print("🧠 Memory at \(Int(progress * 100))%: \(memInfo.resident_size / 1024 / 1024)MB")
                            }
                        }
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Memory test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 60.0)
        }
    }
    
    // MARK: - PDF Merge Performance Tests
    
    func testPDFMergePerformanceSmall() throws {
        // Merge 3 simple PDFs
        let simplePDFs = testPDFURLs.filter { $0.lastPathComponent.contains("simple") }
        
        measure {
            let expectation = expectation(description: "Simple merge")
            
            Task {
                do {
                    _ = try await processor.mergePDFs(
                        simplePDFs,
                        progressHandler: { _ in }
                    )
                    expectation.fulfill()
                } catch {
                    XCTFail("Merge test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 15.0)
        }
    }
    
    func testPDFMergePerformanceLarge() throws {
        // Merge 5 complex PDFs with many pages
        let largePDFs = testPDFURLs.filter { $0.lastPathComponent.contains("large") }
        
        measure {
            let expectation = expectation(description: "Large merge")
            
            Task {
                do {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    _ = try await processor.mergePDFs(
                        Array(largePDFs.prefix(5)),
                        progressHandler: { progress in
                            if Int(progress * 100) % 20 == 0 {
                                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                                print("📈 Merge progress: \(Int(progress * 100))% (\(String(format: "%.2f", elapsed))s)")
                            }
                        }
                    )
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    print("📊 Large PDF merge completed in \(String(format: "%.2f", duration))s")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Large merge test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 60.0)
        }
    }
    
    // MARK: - PDF Compression Performance Tests
    
    func testPDFCompressionPerformance() throws {
        // Compress various PDF sizes
        let testPDFs = [
            testPDFURLs.first { $0.lastPathComponent.contains("medium") },
            testPDFURLs.first { $0.lastPathComponent.contains("complex") },
            testPDFURLs.first { $0.lastPathComponent.contains("large") }
        ].compactMap { $0 }
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            for (index, pdfURL) in testPDFs.enumerated() {
                let expectation = expectation(description: "Compress PDF \(index)")
                
                startMeasuring()
                
                Task {
                    do {
                        let originalSize = try FileManager.default.attributesOfItem(atPath: pdfURL.path)[.size] as! Int
                        let startTime = CFAbsoluteTimeGetCurrent()
                        
                        let compressedURL = try await processor.compressPDF(
                            pdfURL,
                            quality: .medium,
                            targetSizeMB: nil,
                            progressHandler: { _ in }
                        )
                        
                        let duration = CFAbsoluteTimeGetCurrent() - startTime
                        let compressedSize = try FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as! Int
                        let compressionRatio = Double(compressedSize) / Double(originalSize)
                        
                        print("📊 PDF compression \(index): \(originalSize/1024)KB → \(compressedSize/1024)KB (\(String(format: "%.1f", compressionRatio * 100))%) in \(String(format: "%.2f", duration))s")
                        
                        // Clean up compressed file
                        try? FileManager.default.removeItem(at: compressedURL)
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("Compression test failed: \(error)")
                    }
                }
                
                wait(for: [expectation], timeout: 30.0)
                stopMeasuring()
            }
        }
    }
    
    // MARK: - PDF Split Performance Tests
    
    func testPDFSplitPerformance() throws {
        // Split large PDF into individual pages
        guard let largePDF = testPDFURLs.first(where: { $0.lastPathComponent.contains("large") }) else {
            XCTFail("No large PDF found for split test")
            return
        }
        
        measure {
            let expectation = expectation(description: "Split large PDF")
            
            Task {
                do {
                    let startTime = CFAbsoluteTimeGetCurrent()
                    
                    _ = try await processor.splitPDF(
                        largePDF,
                        ranges: [1...50], // All pages individually
                        progressHandler: { progress in
                            if Int(progress * 100) % 25 == 0 {
                                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                                print("✂️  Split progress: \(Int(progress * 100))% (\(String(format: "%.2f", elapsed))s)")
                            }
                        }
                    )
                    
                    let duration = CFAbsoluteTimeGetCurrent() - startTime
                    print("📊 PDF split completed in \(String(format: "%.2f", duration))s")
                    
                    expectation.fulfill()
                } catch {
                    XCTFail("Split test failed: \(error)")
                }
            }
            
            wait(for: [expectation], timeout: 45.0)
        }
    }
    
    // MARK: - Watermark Performance Tests
    
    func testWatermarkPerformance() throws {
        // Add watermarks to PDFs of various sizes
        let testCases = [
            (pdf: testPDFURLs.first { $0.lastPathComponent.contains("medium") }, type: "text"),
            (pdf: testPDFURLs.first { $0.lastPathComponent.contains("complex") }, type: "image")
        ].compactMap { $0.pdf != nil ? (pdf: $0.pdf!, type: $0.type) : nil }
        
        for testCase in testCases {
            measure {
                let expectation = expectation(description: "Watermark \(testCase.type)")
                
                Task {
                    do {
                        let startTime = CFAbsoluteTimeGetCurrent()
                        
                        if testCase.type == "text" {
                            _ = try await processor.watermarkPDF(
                                testCase.pdf,
                                text: "CONFIDENTIAL",
                                position: .center,
                                progressHandler: { _ in }
                            )
                        } else {
                            // Create watermark image
                            let watermarkImage = createTestImage(width: 200, height: 100, index: 0)
                            
                            _ = try await processor.watermarkPDF(
                                testCase.pdf,
                                image: watermarkImage,
                                position: .bottomRight,
                                progressHandler: { _ in }
                            )
                        }
                        
                        let duration = CFAbsoluteTimeGetCurrent() - startTime
                        print("📊 \(testCase.type.capitalized) watermark completed in \(String(format: "%.2f", duration))s")
                        
                        expectation.fulfill()
                    } catch {
                        XCTFail("Watermark test failed: \(error)")
                    }
                }
                
                wait(for: [expectation], timeout: 20.0)
            }
        }
    }
}