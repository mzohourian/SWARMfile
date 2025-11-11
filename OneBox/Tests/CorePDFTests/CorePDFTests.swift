//
//  CorePDFTests.swift
//  OneBox Tests
//

import XCTest
@testable import CorePDF

final class CorePDFTests: XCTestCase {

    var processor: PDFProcessor!
    var testImagesURLs: [URL]!

    override func setUp() async throws {
        processor = PDFProcessor()
        testImagesURLs = try createTestImages()
    }

    override func tearDown() async throws {
        // Clean up test files
        for url in testImagesURLs {
            try? FileManager.default.removeItem(at: url)
        }
        testImagesURLs = nil
        processor = nil
    }

    // MARK: - Images to PDF Tests

    func testCreatePDFFromImages() async throws {
        // Given
        let pageSize = CGSize(width: 595, height: 842) // A4

        // When
        let outputURL = try await processor.createPDF(
            from: testImagesURLs,
            pageSize: pageSize,
            orientation: .portrait,
            margins: 20,
            backgroundColor: .white,
            stripMetadata: true,
            title: "Test PDF",
            author: "OneBox Tests",
            progressHandler: { _ in }
        )

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: outputURL.path))
        XCTAssertEqual(outputURL.pathExtension, "pdf")

        // Verify PDF properties
        let pdfData = try Data(contentsOf: outputURL)
        XCTAssertGreaterThan(pdfData.count, 0)

        // Clean up
        try FileManager.default.removeItem(at: outputURL)
    }

    func testCreatePDFWithMultipleOrientations() async throws {
        // Test portrait
        let portraitURL = try await processor.createPDF(
            from: testImagesURLs,
            pageSize: CGSize(width: 595, height: 842),
            orientation: .portrait,
            progressHandler: { _ in }
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: portraitURL.path))
        try FileManager.default.removeItem(at: portraitURL)

        // Test landscape
        let landscapeURL = try await processor.createPDF(
            from: testImagesURLs,
            pageSize: CGSize(width: 595, height: 842),
            orientation: .landscape,
            progressHandler: { _ in }
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: landscapeURL.path))
        try FileManager.default.removeItem(at: landscapeURL)
    }

    func testCreatePDFWithInvalidImage() async {
        // Given
        let invalidURL = URL(fileURLWithPath: "/tmp/nonexistent.jpg")

        // When/Then
        do {
            _ = try await processor.createPDF(
                from: [invalidURL],
                pageSize: CGSize(width: 595, height: 842),
                progressHandler: { _ in }
            )
            XCTFail("Should throw error for invalid image")
        } catch {
            XCTAssertTrue(error is PDFError)
        }
    }

    // MARK: - PDF Merge Tests

    func testMergePDFs() async throws {
        // Given
        let pdf1 = try await createTestPDF(pageCount: 2)
        let pdf2 = try await createTestPDF(pageCount: 3)

        // When
        let mergedURL = try await processor.mergePDFs(
            [pdf1, pdf2],
            progressHandler: { _ in }
        )

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: mergedURL.path))

        // Verify page count
        let pdfDocument = PDFDocument(url: mergedURL)
        XCTAssertEqual(pdfDocument?.pageCount, 5)

        // Clean up
        try FileManager.default.removeItem(at: pdf1)
        try FileManager.default.removeItem(at: pdf2)
        try FileManager.default.removeItem(at: mergedURL)
    }

    func testMergeEmptyPDFArray() async {
        do {
            _ = try await processor.mergePDFs(
                [],
                progressHandler: { _ in }
            )
            XCTFail("Should throw error for empty array")
        } catch {
            XCTAssertTrue(error is PDFError)
        }
    }

    // MARK: - PDF Split Tests

    func testSplitPDF() async throws {
        // Given
        let sourcePDF = try await createTestPDF(pageCount: 10)
        let ranges = [0...2, 3...5, 6...9]

        // When
        let splitURLs = try await processor.splitPDF(
            sourcePDF,
            ranges: ranges,
            progressHandler: { _ in }
        )

        // Then
        XCTAssertEqual(splitURLs.count, 3)

        for (index, url) in splitURLs.enumerated() {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
            let pdfDocument = PDFDocument(url: url)
            XCTAssertEqual(pdfDocument?.pageCount, ranges[index].count)
            try FileManager.default.removeItem(at: url)
        }

        // Clean up
        try FileManager.default.removeItem(at: sourcePDF)
    }

    // MARK: - PDF Compression Tests

    func testCompressPDFWithQuality() async throws {
        // Given
        let sourcePDF = try await createTestPDF(pageCount: 5)
        let originalSize = try fileSize(of: sourcePDF)

        // When
        let compressedURL = try await processor.compressPDF(
            sourcePDF,
            quality: .medium,
            progressHandler: { _ in }
        )

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: compressedURL.path))

        let compressedSize = try fileSize(of: compressedURL)
        XCTAssertLessThan(compressedSize, originalSize)

        // Clean up
        try FileManager.default.removeItem(at: sourcePDF)
        try FileManager.default.removeItem(at: compressedURL)
    }

    func testProgressReporting() async throws {
        // Given
        var progressUpdates: [Double] = []

        // When
        let outputURL = try await processor.createPDF(
            from: testImagesURLs,
            pageSize: CGSize(width: 595, height: 842),
            progressHandler: { progress in
                progressUpdates.append(progress)
            }
        )

        // Then
        XCTAssertFalse(progressUpdates.isEmpty)
        XCTAssertLessThanOrEqual(progressUpdates.last ?? 0, 1.0)
        XCTAssertGreaterThanOrEqual(progressUpdates.last ?? 0, 0)

        // Clean up
        try FileManager.default.removeItem(at: outputURL)
    }

    // MARK: - Helper Methods

    private func createTestImages() throws -> [URL] {
        var urls: [URL] = []

        for i in 0..<3 {
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("test_image_\(i).jpg")

            // Create a simple test image
            let size = CGSize(width: 100, height: 100)
            UIGraphicsBeginImageContext(size)
            let context = UIGraphicsGetCurrentContext()!
            context.setFillColor(UIColor.red.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
            let image = UIGraphicsGetImageFromCurrentImageContext()!
            UIGraphicsEndImageContext()

            let data = image.jpegData(compressionQuality: 0.9)!
            try data.write(to: url)

            urls.append(url)
        }

        return urls
    }

    private func createTestPDF(pageCount: Int) async throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test_\(UUID().uuidString).pdf")

        UIGraphicsBeginPDFContextToFile(url.path, .zero, nil)

        for _ in 0..<pageCount {
            UIGraphicsBeginPDFPage()
            let context = UIGraphicsGetCurrentContext()!
            context.setFillColor(UIColor.white.cgColor)
            context.fill(CGRect(x: 0, y: 0, width: 595, height: 842))
        }

        UIGraphicsEndPDFContext()

        return url
    }

    private func fileSize(of url: URL) throws -> Int64 {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.size] as? Int64 ?? 0
    }
}
