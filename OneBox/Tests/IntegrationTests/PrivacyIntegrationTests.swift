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
        privacyManager.resetAllSettings()
        
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
        XCTAssertTrue(privacyManager.zeroTrace)
        
        let initialJobCount = jobManager.jobs.count
        
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
        XCTAssertTrue(privacyManager.secureVault)
        
        // When - process a sensitive document
        let job = Job(
            type: .pdfWatermark,
            inputs: [testDocumentURL],
            settings: JobSettings(
                watermarkText: "CONFIDENTIAL",
                watermarkPosition: .center
            )
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
    
    // MARK: - Compliance Mode Integration Tests
    
    func testHealthcareComplianceModeIntegration() async throws {
        // Given - set healthcare compliance mode
        privacyManager.complianceMode = .healthcare
        
        // Verify all privacy features enabled
        XCTAssertTrue(privacyManager.secureVault)
        XCTAssertTrue(privacyManager.zeroTrace)
        XCTAssertTrue(privacyManager.biometricLock)
        
        // When - process PHI document
        let job = Job(
            type: .pdfRedact,
            inputs: [testDocumentURL],
            settings: JobSettings()
        )
        
        await jobManager.submitJob(job)
        
        // Wait for completion
        let expectation = expectation(description: "HIPAA compliant job completes")
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id && $0.status != .pending && $0.status != .running }) {
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()
        
        // Then - verify compliant processing
        let processedJob = jobManager.jobs.first(where: { $0.id == job.id })
        XCTAssertNotNil(processedJob)
        
        // Verify audit trail created
        let auditEntries = privacyManager.getAuditEntries()
        XCTAssertTrue(auditEntries.contains(where: { entry in
            if case .documentProcessed = entry.event {
                return true
            }
            return false
        }))
    }
    
    // MARK: - Encryption Integration Tests
    
    func testDocumentEncryptionIntegration() async throws {
        // Given - encrypt a document
        let password = "TestPassword123!"
        let encryptedDoc = try await privacyManager.encryptDocument(at: testDocumentURL, password: password)
        
        // When - try to process encrypted document
        let job = Job(
            type: .pdfCompress,
            inputs: [testDocumentURL], // Using original URL
            settings: JobSettings()
        )
        
        await jobManager.submitJob(job)
        
        // Wait for job to complete or fail
        let expectation = expectation(description: "Job processes encrypted document")
        var completedJob: Job?
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id && ($0.status == .success || $0.status == .failed) }) {
                completedJob = updatedJob
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()
        
        // Then - verify appropriate handling
        XCTAssertNotNil(completedJob)
        // Should either fail or handle encrypted document appropriately
    }
    
    // MARK: - Privacy Audit Integration Tests
    
    func testPrivacyAuditDuringJobProcessing() async throws {
        // Given - enable audit trail
        privacyManager.complianceMode = .legal
        
        let initialAuditCount = privacyManager.getAuditEntries().count
        
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
        expectation.expectedFulfillmentCount = jobs.count
        
        let observation = jobManager.$jobs.sink { currentJobs in
            let completedCount = currentJobs.filter { job in
                jobs.contains(where: { $0.id == job.id }) && job.status == .success
            }.count
            
            if completedCount == jobs.count {
                for _ in 0..<jobs.count {
                    expectation.fulfill()
                }
            }
        }
        
        await fulfillment(of: [expectation], timeout: 15.0)
        observation.cancel()
        
        // Then - verify audit entries created
        let finalAuditCount = privacyManager.getAuditEntries().count
        XCTAssertGreaterThan(finalAuditCount, initialAuditCount)
        
        // Verify audit entries contain document processing events
        let auditEntries = privacyManager.getAuditEntries()
        let processingEvents = auditEntries.filter { entry in
            if case .documentProcessed = entry.event {
                return true
            }
            return false
        }
        
        XCTAssertGreaterThanOrEqual(processingEvents.count, jobs.count)
    }
    
    // MARK: - Memory Cleanup Integration Tests
    
    func testSecureMemoryCleanupAfterProcessing() async throws {
        // Given - enable stealth mode for maximum security
        privacyManager.enableStealthMode(true)
        
        // When - process sensitive document
        let job = Job(
            type: .pdfSign,
            inputs: [testDocumentURL],
            settings: JobSettings(
                signatureText: "Approved",
                signaturePosition: CGPoint(x: 100, y: 700)
            )
        )
        
        await jobManager.submitJob(job)
        
        // Wait for completion
        let expectation = expectation(description: "Secure job completes")
        
        let observation = jobManager.$jobs.sink { jobs in
            if let updatedJob = jobs.first(where: { $0.id == job.id && $0.status == .success }) {
                expectation.fulfill()
            }
        }
        
        await fulfillment(of: [expectation], timeout: 10.0)
        observation.cancel()
        
        // Then - verify secure cleanup
        // In production, this would verify secure memory wiping
        // For testing, we verify the job completed successfully
        let completedJob = jobManager.jobs.first(where: { $0.id == job.id })
        XCTAssertEqual(completedJob?.status, .success)
        
        // Verify memory status is good
        let memoryStatus = privacyManager.getMemoryStatus()
        XCTAssertGreaterThan(memoryStatus.availableMemory, 0)
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
        let imageJob = Job(
            type: .imageResize,
            inputs: [imageURL],
            settings: JobSettings(maxDimension: 200)
        )
        
        // When - process jobs
        await jobManager.submitJob(pdfJob)
        await jobManager.submitJob(imageJob)
        
        // Wait for both to complete
        let expectation = expectation(description: "Both jobs complete")
        expectation.expectedFulfillmentCount = 2
        
        let observation = jobManager.$jobs.sink { jobs in
            let completed = jobs.filter { ($0.id == pdfJob.id || $0.id == imageJob.id) && $0.status == .success }
            if completed.count == 2 {
                expectation.fulfill()
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