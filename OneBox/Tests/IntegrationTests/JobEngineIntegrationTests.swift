//
//  JobEngineIntegrationTests.swift
//  OneBox - Integration Tests for JobEngine with CorePDF and CoreImageKit
//

import XCTest
@testable import JobEngine
@testable import CorePDF
@testable import CoreImageKit
@testable import CommonTypes
import UIKit

@MainActor
final class JobEngineIntegrationTests: XCTestCase {
    
    var jobManager: JobManager!
    var testImageURLs: [URL]!
    var testPDFURLs: [URL]!
    
    override func setUp() async throws {
        jobManager = JobManager.shared
        testImageURLs = try createTestImages()
        testPDFURLs = try createTestPDFs()
    }
    
    override func tearDown() async throws {
        // Clean up test files
        for url in (testImageURLs ?? []) + (testPDFURLs ?? []) {
            try? FileManager.default.removeItem(at: url)
        }
        
        // Clean up job outputs
        for job in jobManager.jobs {
            for outputURL in job.outputURLs {
                try? FileManager.default.removeItem(at: outputURL)
            }
            jobManager.deleteJob(job)
        }
        
        testImageURLs = nil
        testPDFURLs = nil
        jobManager = nil
    }
    
    // MARK: - Test Data Creation
    
    private func createTestImages() throws -> [URL] {
        var urls: [URL] = []
        
        for i in 0..<3 {
            let image = createTestImage(width: 300, height: 300, color: [.systemRed, .systemGreen, .systemBlue][i])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("integration_test_image_\(i).jpg")
            
            if let data = image.jpegData(compressionQuality: 0.9) {
                try data.write(to: url)
                urls.append(url)
            }
        }
        
        return urls
    }
    
    private func createTestPDFs() throws -> [URL] {
        var urls: [URL] = []
        
        // Create simple test PDFs
        for i in 0..<3 {
            let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("integration_test_pdf_\(i).pdf")
            
            UIGraphicsBeginPDFContextToFile(pdfURL.path, .zero, nil)
            UIGraphicsBeginPDFPageWithInfo(CGRect(x: 0, y: 0, width: 595, height: 842), nil)
            
            let text = "Test PDF \(i + 1)"
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 24),
                .foregroundColor: UIColor.label
            ]
            text.draw(at: CGPoint(x: 100, y: 100), withAttributes: attributes)
            
            UIGraphicsEndPDFContext()
            urls.append(pdfURL)
        }
        
        return urls
    }
    
    private func createTestImage(width: Int, height: Int, color: UIColor) -> UIImage {
        UIGraphicsBeginImageContext(CGSize(width: width, height: height))
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        context.setFillColor(color.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    // MARK: - Images to PDF Integration Tests
    
    func testImagesToPDFIntegration() async throws {
        // Given
        var settings = JobSettings()
        settings.pageSize = .a4
        settings.orientation = .portrait
        settings.margins = 20
        settings.stripMetadata = true

        let job = Job(
            type: .imagesToPDF,
            inputs: testImageURLs,
            settings: settings
        )
        
        // When
        await jobManager.submitJob(job)
        
        // Wait for job completion
        let expectation = expectation(description: "Job completes")
        var completedJob: Job?
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id && $0.status == .success }) {
                completedJob = updatedJob
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()
        
        // Then
        XCTAssertNotNil(completedJob)
        XCTAssertEqual(completedJob?.status, .success)
        XCTAssertEqual(completedJob?.outputURLs.count, 1)
        
        // Verify PDF was created
        if let pdfURL = completedJob?.outputURLs.first {
            XCTAssertTrue(FileManager.default.fileExists(atPath: pdfURL.path))
            XCTAssertEqual(pdfURL.pathExtension, "pdf")
            
            // Verify PDF has content
            let fileSize = try FileManager.default.attributesOfItem(atPath: pdfURL.path)[.size] as! Int
            XCTAssertGreaterThan(fileSize, 1000) // Should have substantial content
        }
    }
    
    // MARK: - PDF Merge Integration Tests
    
    func testPDFMergeIntegration() async throws {
        // Given
        let job = Job(
            type: .pdfMerge,
            inputs: testPDFURLs,
            settings: JobSettings()
        )
        
        // When
        await jobManager.submitJob(job)
        
        // Wait for completion
        let expectation = expectation(description: "PDF merge completes")
        var completedJob: Job?
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id && $0.status == .success }) {
                completedJob = updatedJob
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()
        
        // Then
        XCTAssertNotNil(completedJob)
        XCTAssertEqual(completedJob?.status, .success)
        XCTAssertEqual(completedJob?.outputURLs.count, 1)
        
        // Verify merged PDF
        if let mergedURL = completedJob?.outputURLs.first {
            XCTAssertTrue(FileManager.default.fileExists(atPath: mergedURL.path))
            
            // Should be larger than individual PDFs
            let mergedSize = try FileManager.default.attributesOfItem(atPath: mergedURL.path)[.size] as! Int
            let firstSize = try FileManager.default.attributesOfItem(atPath: testPDFURLs[0].path)[.size] as! Int
            XCTAssertGreaterThan(mergedSize, firstSize)
        }
    }
    
    // MARK: - PDF Compression Integration Tests
    
    func testPDFCompressionIntegration() async throws {
        // Given - use a larger PDF for compression
        let largePDF = try createLargePDF()
        let originalSize = try FileManager.default.attributesOfItem(atPath: largePDF.path)[.size] as! Int
        
        var compressSettings = JobSettings()
        compressSettings.compressionQuality = .medium

        let job = Job(
            type: .pdfCompress,
            inputs: [largePDF],
            settings: compressSettings
        )
        
        // When
        await jobManager.submitJob(job)
        
        // Wait for completion
        let expectation = expectation(description: "PDF compression completes")
        var completedJob: Job?
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id }) {
                if updatedJob.status == .success || updatedJob.status == .failed {
                    completedJob = updatedJob
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
        observation.cancel()
        
        // Then
        XCTAssertNotNil(completedJob)
        XCTAssertEqual(completedJob?.status, .success)
        
        // Verify compression
        if let compressedURL = completedJob?.outputURLs.first {
            let compressedSize = try FileManager.default.attributesOfItem(atPath: compressedURL.path)[.size] as! Int
            XCTAssertLessThan(compressedSize, originalSize)
            print("Compression ratio: \(Double(compressedSize) / Double(originalSize))")
        }
        
        // Clean up
        try? FileManager.default.removeItem(at: largePDF)
    }
    
    // MARK: - Image Resize Integration Tests
    
    func testImageResizeIntegration() async throws {
        // Given
        var resizeSettings = JobSettings()
        resizeSettings.imageFormat = .jpeg
        resizeSettings.imageQualityPreset = .medium
        resizeSettings.maxDimension = 200

        let job = Job(
            type: .imageResize,
            inputs: testImageURLs,
            settings: resizeSettings
        )
        
        // When
        await jobManager.submitJob(job)
        
        // Wait for completion
        let expectation = expectation(description: "Image resize completes")
        var completedJob: Job?
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id && $0.status == .success }) {
                completedJob = updatedJob
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()
        
        // Then
        XCTAssertNotNil(completedJob)
        XCTAssertEqual(completedJob?.status, .success)
        XCTAssertEqual(completedJob?.outputURLs.count, testImageURLs.count)
        
        // Verify resized images
        for outputURL in completedJob?.outputURLs ?? [] {
            if let image = UIImage(contentsOfFile: outputURL.path) {
                XCTAssertLessThanOrEqual(max(image.size.width, image.size.height), 200)
            }
        }
    }
    
    // MARK: - Error Handling Integration Tests
    
    func testInvalidInputHandling() async throws {
        // Given - invalid file that doesn't exist
        let invalidURL = URL(fileURLWithPath: "/tmp/nonexistent_file.pdf")
        let job = Job(
            type: .pdfCompress,
            inputs: [invalidURL],
            settings: JobSettings()
        )
        
        // When
        await jobManager.submitJob(job)
        
        // Wait for job to fail
        let expectation = expectation(description: "Job fails")
        var failedJob: Job?
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id && $0.status == .failed }) {
                failedJob = updatedJob
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 5.0)
        observation.cancel()
        
        // Then
        XCTAssertNotNil(failedJob)
        XCTAssertEqual(failedJob?.status, .failed)
        XCTAssertNotNil(failedJob?.error)
        XCTAssertTrue(failedJob?.outputURLs.isEmpty ?? false)
    }
    
    // MARK: - Progress Tracking Integration Tests
    
    func testProgressTracking() async throws {
        // Given
        let job = Job(
            type: .imagesToPDF,
            inputs: testImageURLs,
            settings: JobSettings()
        )
        
        var progressUpdates: [Double] = []
        
        // When
        await jobManager.submitJob(job)
        
        // Track progress updates
        let expectation = expectation(description: "Job completes with progress")
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id }) {
                progressUpdates.append(updatedJob.progress)
                if updatedJob.status == .success {
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()
        
        // Then
        XCTAssertGreaterThan(progressUpdates.count, 2) // Should have multiple progress updates
        XCTAssertTrue(progressUpdates.contains(where: { $0 > 0 && $0 < 1 })) // Intermediate progress
        XCTAssertEqual(progressUpdates.last, 1.0) // Final progress should be 100%
    }
    
    // MARK: - Concurrent Jobs Integration Tests
    
    func testConcurrentJobExecution() async throws {
        // Given - multiple jobs
        var job2Settings = JobSettings()
        job2Settings.maxDimension = 100

        let job1 = Job(type: .imagesToPDF, inputs: Array(testImageURLs.prefix(2)), settings: JobSettings())
        let job2 = Job(type: .imageResize, inputs: Array(testImageURLs.suffix(1)), settings: job2Settings)
        
        // When - submit both jobs
        await jobManager.submitJob(job1)
        await jobManager.submitJob(job2)
        
        // Wait for both to complete
        let expectation = expectation(description: "Both jobs complete")
        expectation.expectedFulfillmentCount = 2
        
        let observation = jobManager.$jobs.sink { jobs in
            let completedJobs = jobs.filter { ($0.id == job1.id || $0.id == job2.id) && $0.status == .success }
            if completedJobs.count == 2 {
                expectation.fulfill()
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
        observation.cancel()
        
        // Then - verify both completed
        let finalJobs = jobManager.jobs.filter { $0.id == job1.id || $0.id == job2.id }
        XCTAssertEqual(finalJobs.count, 2)
        XCTAssertTrue(finalJobs.allSatisfy { $0.status == .success })
    }
    
    // MARK: - Helper Methods
    
    private func createLargePDF() throws -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("large_test.pdf")
        
        UIGraphicsBeginPDFContextToFile(pdfURL.path, .zero, nil)
        
        // Create 10 pages with images
        for i in 0..<10 {
            UIGraphicsBeginPDFPageWithInfo(CGRect(x: 0, y: 0, width: 595, height: 842), nil)
            
            // Draw a large image on each page
            let image = createTestImage(width: 500, height: 700, color: .systemBlue)
            image.draw(in: CGRect(x: 50, y: 50, width: 500, height: 700))
            
            let text = "Page \(i + 1)"
            text.draw(at: CGPoint(x: 250, y: 400), withAttributes: [
                .font: UIFont.systemFont(ofSize: 36),
                .foregroundColor: UIColor.white
            ])
        }
        
        UIGraphicsEndPDFContext()
        return pdfURL
    }
}