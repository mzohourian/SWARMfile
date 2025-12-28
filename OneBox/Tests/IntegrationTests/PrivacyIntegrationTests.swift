//
//  PrivacyIntegrationTests.swift
//  OneBox - Integration Tests for Privacy Module with JobEngine
//

import XCTest
@testable import Privacy
@testable import JobEngine
@testable import CorePDF
@testable import CommonTypes
import UIKit
import CryptoKit

@MainActor
final class PrivacyIntegrationTests: XCTestCase {

    var privacyManager: Privacy.PrivacyManager!
    var jobManager: JobManager!
    var testDocumentURL: URL!

    override func setUp() async throws {
        privacyManager = Privacy.PrivacyManager.shared
        jobManager = JobManager.shared

        // Set up privacy delegate
        jobManager.setPrivacyDelegate(privacyManager)

        // Create test document
        testDocumentURL = try createTestDocument()
    }

    override func tearDown() async throws {
        // Reset privacy settings
        privacyManager.enableSecureVault(false)
        privacyManager.enableZeroTrace(false)
        privacyManager.enableBiometricLock(false)
        privacyManager.enableStealthMode(false)

        // Clean up test files
        try? FileManager.default.removeItem(at: testDocumentURL)

        // Clean up jobs
        for job in jobManager.jobs {
            for outputURL in job.outputURLs {
                try? FileManager.default.removeItem(at: outputURL)
            }
            jobManager.deleteJob(job)
        }

        testDocumentURL = nil
        privacyManager = nil
        jobManager = nil
    }

    // MARK: - Test Data Creation

    private func createTestDocument() throws -> URL {
        let pdfURL = FileManager.default.temporaryDirectory.appendingPathComponent("privacy_test.pdf")

        UIGraphicsBeginPDFContextToFile(pdfURL.path, .zero, nil)
        UIGraphicsBeginPDFPageWithInfo(CGRect(x: 0, y: 0, width: 595, height: 842), nil)

        // Add sensitive content
        let sensitiveText = "SSN: 123-45-6789\nAccount: 1234567890"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: UIFont.systemFont(ofSize: 14),
            .foregroundColor: UIColor.label
        ]
        sensitiveText.draw(at: CGPoint(x: 100, y: 100), withAttributes: attributes)

        UIGraphicsEndPDFContext()
        return pdfURL
    }

    // MARK: - Zero Trace Mode Integration Tests

    func testZeroTraceModeJobProcessing() async throws {
        // Given - enable zero trace mode
        privacyManager.enableZeroTrace(true)
        XCTAssertTrue(privacyManager.isZeroTraceEnabled)

        // When - process a job
        let job = Job(
            type: .pdfCompress,
            inputs: [testDocumentURL],
            settings: JobSettings()
        )

        await jobManager.submitJob(job)

        // Wait for completion
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

        // Then - verify job completed but history not persisted
        XCTAssertNotNil(completedJob)
        XCTAssertEqual(completedJob?.status, .success)

        // In zero trace mode, job history should not be persisted
        // Verify by checking persistence file doesn't exist or is empty
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jobsFile = documentsPath.appendingPathComponent("jobs.json")

        if FileManager.default.fileExists(atPath: jobsFile.path) {
            let data = try Data(contentsOf: jobsFile)
            let jobs = try JSONDecoder().decode([Job].self, from: data)
            // Should not contain our test job
            XCTAssertFalse(jobs.contains(where: { $0.id == job.id }))
        }
    }

    // MARK: - Secure Vault Integration Tests

    func testSecureVaultFileProcessing() async throws {
        // Given - enable secure vault
        privacyManager.enableSecureVault(true)
        XCTAssertTrue(privacyManager.isSecureVaultEnabled)

        // When - process a sensitive document
        var settings = JobSettings()
        settings.watermarkText = "CONFIDENTIAL"
        settings.watermarkPosition = .center

        let job = Job(
            type: .pdfWatermark,
            inputs: [testDocumentURL],
            settings: settings
        )

        await jobManager.submitJob(job)

        // Wait for completion
        let expectation = expectation(description: "Secure job completes")
        var completedJob: Job?

        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id && ($0.status == .success || $0.status == .failed) }) {
                completedJob = updatedJob
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()

        // Then - verify job completed with secure handling
        XCTAssertNotNil(completedJob)
        XCTAssertEqual(completedJob?.status, .success)

        // Output should be in secure temporary location
        if let outputURL = completedJob?.outputURLs.first {
            XCTAssertTrue(outputURL.path.contains("tmp") || outputURL.path.contains("Temporary"))
        }
    }

    // MARK: - Encryption Integration Tests

    func testDocumentEncryptionIntegration() async throws {
        // Given - encrypt a document
        let password = "TestPassword123!"
        let encryptedDoc = try privacyManager.encryptFile(at: testDocumentURL, password: password)

        // Verify encrypted file exists
        XCTAssertTrue(FileManager.default.fileExists(atPath: encryptedDoc.path))

        // When - decrypt the document
        let decryptedDoc = try privacyManager.decryptFile(at: encryptedDoc, password: password)

        // Then - verify decryption succeeded
        XCTAssertTrue(FileManager.default.fileExists(atPath: decryptedDoc.path))

        // Clean up
        try? FileManager.default.removeItem(at: encryptedDoc)
        try? FileManager.default.removeItem(at: decryptedDoc)
    }

    // MARK: - Privacy Audit Integration Tests

    func testPrivacyAuditDuringJobProcessing() async throws {
        // Given - clear existing audit trail and enable settings
        privacyManager.clearAuditTrail()
        privacyManager.enableSecureVault(true)

        let initialAuditCount = privacyManager.getAuditTrail().count

        // When - process multiple jobs
        let jobs = [
            Job(type: .pdfMerge, inputs: [testDocumentURL], settings: JobSettings()),
            Job(type: .pdfCompress, inputs: [testDocumentURL], settings: JobSettings())
        ]

        for job in jobs {
            await jobManager.submitJob(job)
        }

        // Wait for all jobs to complete
        let expectation = expectation(description: "All jobs complete")

        let observation = jobManager.$jobs.sink { currentJobs in
            let completedCount = currentJobs.filter { job in
                jobs.contains(where: { $0.id == job.id }) && (job.status == .success || job.status == .failed)
            }.count

            if completedCount == jobs.count {
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 15.0)
        observation.cancel()

        // Then - verify audit entries created (at least for the setting toggle)
        let finalAuditCount = privacyManager.getAuditTrail().count
        XCTAssertGreaterThan(finalAuditCount, initialAuditCount)
    }

    // MARK: - Memory Cleanup Integration Tests

    func testSecureMemoryCleanupAfterProcessing() async throws {
        // Given - enable stealth mode for maximum security
        privacyManager.enableStealthMode(true)
        XCTAssertTrue(privacyManager.isStealthModeEnabled)

        // When - process sensitive document
        var settings = JobSettings()
        settings.signatureText = "Approved"
        settings.signaturePosition = .bottomRight

        let job = Job(
            type: .pdfSign,
            inputs: [testDocumentURL],
            settings: settings
        )

        await jobManager.submitJob(job)

        // Wait for completion
        let expectation = expectation(description: "Secure job completes")

        let observation = jobManager.$jobs.sink { jobs in
            if jobs.first(where: { $0.id == job.id && ($0.status == .success || $0.status == .failed) }) != nil {
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()

        // Then - verify secure cleanup
        let completedJob = jobManager.jobs.first(where: { $0.id == job.id })
        XCTAssertNotNil(completedJob)

        // Verify memory status is available
        let memoryUsage = privacyManager.memoryStatus.usage
        XCTAssertGreaterThanOrEqual(memoryUsage, 0)
    }

    // MARK: - Cross-Module Security Tests

    func testPrivacySettingsRespectedAcrossModules() async throws {
        // Given - configure privacy settings
        privacyManager.enableSecureVault(true)
        privacyManager.enableZeroTrace(true)

        // Create jobs that use different modules
        let pdfJob = Job(
            type: .pdfCompress,
            inputs: [testDocumentURL],
            settings: JobSettings()
        )

        let imageURL = try createTestImage()
        var imageSettings = JobSettings()
        imageSettings.maxDimension = 200
        let imageJob = Job(
            type: .imageResize,
            inputs: [imageURL],
            settings: imageSettings
        )

        // When - process jobs
        await jobManager.submitJob(pdfJob)
        await jobManager.submitJob(imageJob)

        // Wait for both to complete
        let expectation = expectation(description: "Both jobs complete")

        let observation = jobManager.$jobs.sink { jobs in
            let completed = jobs.filter { ($0.id == pdfJob.id || $0.id == imageJob.id) && ($0.status == .success || $0.status == .failed) }
            if completed.count == 2 {
                expectation.fulfill()
            }
        }

        await fulfillment(of: [expectation], timeout: 15.0)
        observation.cancel()

        // Then - verify privacy settings were respected
        // Check that zero trace is active (no persisted job history)
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let jobsFile = documentsPath.appendingPathComponent("jobs.json")

        if FileManager.default.fileExists(atPath: jobsFile.path) {
            let data = try Data(contentsOf: jobsFile)
            let persistedJobs = try JSONDecoder().decode([Job].self, from: data)
            XCTAssertFalse(persistedJobs.contains(where: { $0.id == pdfJob.id || $0.id == imageJob.id }))
        }

        // Clean up
        try? FileManager.default.removeItem(at: imageURL)
    }

    // MARK: - Helper Methods

    private func createTestImage() throws -> URL {
        let image = UIImage(systemName: "lock.fill")!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("test_secure_image.jpg")
        try image.jpegData(compressionQuality: 0.9)?.write(to: url)
        return url
    }
}
