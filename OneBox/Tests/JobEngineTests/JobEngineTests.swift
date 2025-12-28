//
//  JobEngineTests.swift
//  OneBox Tests
//

import XCTest
@testable import CommonTypes
@testable import JobEngine

@MainActor
final class JobEngineTests: XCTestCase {

    var jobManager: JobManager!

    override func setUp() async throws {
        jobManager = JobManager.shared
        // Clear any existing jobs
        for job in jobManager.jobs {
            await jobManager.deleteJob(job)
        }
    }

    override func tearDown() async throws {
        // Clean up jobs
        for job in jobManager.jobs {
            await jobManager.deleteJob(job)
        }
        jobManager = nil
    }

    // MARK: - Job Creation Tests

    func testCreateJob() {
        // Given
        let testURL = URL(fileURLWithPath: "/tmp/test.jpg")
        let job = Job(
            type: .imagesToPDF,
            inputs: [testURL],
            settings: JobSettings()
        )

        // Then
        XCTAssertEqual(job.type, .imagesToPDF)
        XCTAssertEqual(job.inputs.count, 1)
        XCTAssertEqual(job.status, .pending)
        XCTAssertEqual(job.progress, 0)
    }

    func testJobStatusTransitions() {
        // Given
        var job = Job(
            type: .imagesToPDF,
            inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
            settings: JobSettings()
        )

        // When/Then
        XCTAssertEqual(job.status, .pending)

        job.status = .running
        XCTAssertEqual(job.status, .running)

        job.status = .success
        XCTAssertEqual(job.status, .success)
    }

    // MARK: - Job Manager Tests

    func testSubmitJob() async {
        // Given
        let job = Job(
            type: .imagesToPDF,
            inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
            settings: JobSettings()
        )

        // When
        await jobManager.submitJob(job)

        // Then
        XCTAssertEqual(jobManager.jobs.count, 1)
        XCTAssertEqual(jobManager.jobs.first?.id, job.id)
    }

    func testDeleteJob() async {
        // Given
        let job = Job(
            type: .imagesToPDF,
            inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
            settings: JobSettings()
        )
        await jobManager.submitJob(job)

        // When
        await jobManager.deleteJob(job)

        // Then
        XCTAssertEqual(jobManager.jobs.count, 0)
    }

    func testCancelJob() async {
        // Given
        let job = Job(
            type: .imagesToPDF,
            inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
            settings: JobSettings(),
            status: .running
        )
        await jobManager.submitJob(job)

        // When
        await jobManager.cancelJob(job)

        // Then
        let updatedJob = jobManager.jobs.first { $0.id == job.id }
        XCTAssertEqual(updatedJob?.status, .failed)
        XCTAssertNotNil(updatedJob?.error)
    }

    func testRetryJob() async {
        // Given
        var job = Job(
            type: .imagesToPDF,
            inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
            settings: JobSettings(),
            status: .failed,
            error: "Test error"
        )
        job.progress = 0.5
        await jobManager.submitJob(job)

        // When
        await jobManager.retryJob(job)

        // Then
        let retriedJob = jobManager.jobs.first { $0.id == job.id }
        XCTAssertEqual(retriedJob?.status, .pending)
        XCTAssertEqual(retriedJob?.progress, 0)
        XCTAssertNil(retriedJob?.error)
    }

    // MARK: - Job Settings Tests

    func testJobSettingsDefaults() {
        // Given
        let settings = JobSettings()

        // Then
        XCTAssertEqual(settings.pageSize, .a4)
        XCTAssertEqual(settings.orientation, .portrait)
        XCTAssertEqual(settings.margins, 20)
        XCTAssertEqual(settings.stripMetadata, true)
        XCTAssertEqual(settings.imageFormat, .jpeg)
        XCTAssertEqual(settings.imageQuality, 0.8)
        XCTAssertEqual(settings.compressionQuality, .medium)
    }

    func testJobSettingsCustomization() {
        // Given
        var settings = JobSettings()

        // When
        settings.pageSize = .letter
        settings.orientation = .landscape
        settings.stripMetadata = false
        settings.targetSizeMB = 10.0

        // Then
        XCTAssertEqual(settings.pageSize, .letter)
        XCTAssertEqual(settings.orientation, .landscape)
        XCTAssertEqual(settings.stripMetadata, false)
        XCTAssertEqual(settings.targetSizeMB, 10.0)
    }

    // MARK: - Job Type Tests

    func testJobTypeDisplayNames() {
        XCTAssertEqual(JobType.imagesToPDF.displayName, "Images to PDF")
        XCTAssertEqual(JobType.pdfMerge.displayName, "Merge PDFs")
        XCTAssertEqual(JobType.pdfSplit.displayName, "Split PDF")
        XCTAssertEqual(JobType.pdfCompress.displayName, "Compress PDF")
        XCTAssertEqual(JobType.imageResize.displayName, "Resize Images")
    }

    func testAllJobTypes() {
        let allTypes = JobType.allCases
        XCTAssertTrue(allTypes.contains(.imagesToPDF))
        XCTAssertTrue(allTypes.contains(.pdfMerge))
        XCTAssertTrue(allTypes.contains(.pdfSplit))
        XCTAssertTrue(allTypes.contains(.pdfCompress))
        XCTAssertTrue(allTypes.contains(.imageResize))
    }

    // MARK: - Persistence Tests

    func testJobPersistence() async {
        // Given
        let job = Job(
            type: .imagesToPDF,
            inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
            settings: JobSettings()
        )

        // When
        await jobManager.submitJob(job)

        // Then - JobManager.shared maintains state
        XCTAssertEqual(JobManager.shared.jobs.count, 1)
    }

    // MARK: - Progress Tracking Tests

    func testProgressTracking() {
        // Given
        var job = Job(
            type: .imagesToPDF,
            inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
            settings: JobSettings()
        )

        // When
        job.progress = 0.5

        // Then
        XCTAssertEqual(job.progress, 0.5)

        // When
        job.progress = 1.0

        // Then
        XCTAssertEqual(job.progress, 1.0)
    }

    // MARK: - Error Handling Tests

    func testJobError() {
        // Given
        var job = Job(
            type: .imagesToPDF,
            inputs: [URL(fileURLWithPath: "/tmp/test.jpg")],
            settings: JobSettings()
        )

        // When
        job.status = .failed
        job.error = "Test error message"

        // Then
        XCTAssertEqual(job.status, .failed)
        XCTAssertEqual(job.error, "Test error message")
    }

    // MARK: - Compression Quality Tests

    func testCompressionQualityValues() {
        XCTAssertEqual(CompressionQuality.maximum.jpegQuality, 0.95)
        XCTAssertEqual(CompressionQuality.high.jpegQuality, 0.75)
        XCTAssertEqual(CompressionQuality.medium.jpegQuality, 0.50)
        XCTAssertEqual(CompressionQuality.low.jpegQuality, 0.25)
    }

    func testCompressionQualityDisplayNames() {
        XCTAssertEqual(CompressionQuality.maximum.displayName, "Maximum")
        XCTAssertEqual(CompressionQuality.high.displayName, "High")
        XCTAssertEqual(CompressionQuality.medium.displayName, "Medium")
        XCTAssertEqual(CompressionQuality.low.displayName, "Low")
    }

    // MARK: - PDF Page Size Tests

    func testPDFPageSizes() {
        // A4
        let a4Size = PDFPageSize.a4.size
        XCTAssertEqual(a4Size?.width, 595)
        XCTAssertEqual(a4Size?.height, 842)

        // Letter
        let letterSize = PDFPageSize.letter.size
        XCTAssertEqual(letterSize?.width, 612)
        XCTAssertEqual(letterSize?.height, 792)

        // Fit
        let fitSize = PDFPageSize.fit.size
        XCTAssertNil(fitSize)
    }

    // MARK: - Watermark Position Tests

    func testWatermarkPositions() {
        let positions = WatermarkPosition.allCases
        XCTAssertEqual(positions.count, 10)
        XCTAssertTrue(positions.contains(.topLeft))
        XCTAssertTrue(positions.contains(.center))
        XCTAssertTrue(positions.contains(.bottomRight))
        XCTAssertTrue(positions.contains(.tiled))
    }
}
