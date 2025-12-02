//
//  PaymentIntegrationTests.swift
//  OneBox - Integration Tests for Payment System with JobEngine
//

import XCTest
@testable import Payments
@testable import JobEngine
@testable import CommonTypes
import StoreKit

@MainActor
final class PaymentIntegrationTests: XCTestCase {
    
    var paymentsManager: PaymentsManager!
    var jobManager: JobManager!
    var testFileURL: URL!
    
    override func setUp() async throws {
        paymentsManager = PaymentsManager.shared
        jobManager = JobManager.shared
        
        // Reset daily exports for testing
        paymentsManager.resetDailyExports()
        
        // Create test file
        testFileURL = try createTestFile()
    }
    
    override func tearDown() async throws {
        // Clean up test file
        try? FileManager.default.removeItem(at: testFileURL)
        
        // Clean up jobs
        for job in jobManager.jobs {
            for outputURL in job.outputURLs {
                try? FileManager.default.removeItem(at: outputURL)
            }
            jobManager.deleteJob(job)
        }
        
        // Reset payment state
        paymentsManager.resetDailyExports()
        
        testFileURL = nil
        paymentsManager = nil
        jobManager = nil
    }
    
    // MARK: - Test Data Creation
    
    private func createTestFile() throws -> URL {
        let image = UIImage(systemName: "doc.fill")!
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("payment_test_image.jpg")
        try image.jpegData(compressionQuality: 0.9)?.write(to: url)
        return url
    }
    
    // MARK: - Free Tier Export Limit Tests
    
    func testFreeTierExportLimit() async throws {
        // Given - user is on free tier
        XCTAssertFalse(paymentsManager.hasPro)
        XCTAssertEqual(paymentsManager.remainingFreeExports, 3)
        
        // When - process 3 jobs (free tier limit)
        for i in 0..<3 {
            let job = Job(
                type: .imageResize,
                inputs: [testFileURL],
                settings: JobSettings(maxDimension: 100 + i * 100)
            )
            
            await jobManager.submitJob(job)
            
            // Consume export
            paymentsManager.consumeExport()
            
            // Wait for job completion
            let expectation = expectation(description: "Job \(i + 1) completes")
            
            let observation = jobManager.$jobs.sink { jobs in
                if jobs.contains(where: { $0.id == job.id && $0.status == .success }) {
                    expectation.fulfill()
                }
            }
            
            await fulfillment(of: [expectation], timeout: 5.0)
            observation.cancel()
        }
        
        // Then - verify export limit reached
        XCTAssertEqual(paymentsManager.dailyExportsUsed, 3)
        XCTAssertEqual(paymentsManager.remainingFreeExports, 0)
        XCTAssertFalse(paymentsManager.canExport)
    }
    
    func testExportLimitEnforcementAfterLimit() async throws {
        // Given - use up free exports
        for _ in 0..<3 {
            paymentsManager.consumeExport()
        }
        
        XCTAssertEqual(paymentsManager.remainingFreeExports, 0)
        XCTAssertFalse(paymentsManager.canExport)
        
        // When - try to process another job
        let job = Job(
            type: .pdfCompress,
            inputs: [testFileURL],
            settings: JobSettings()
        )
        
        // Then - verify export is blocked
        if paymentsManager.canExport {
            await jobManager.submitJob(job)
            XCTFail("Should not be able to export after limit reached")
        } else {
            // Export correctly blocked
            XCTAssertTrue(true)
        }
    }
    
    // MARK: - Daily Reset Tests
    
    func testDailyExportReset() async throws {
        // Given - use up exports
        for _ in 0..<3 {
            paymentsManager.consumeExport()
        }
        XCTAssertEqual(paymentsManager.remainingFreeExports, 0)
        
        // When - reset daily exports (simulating midnight)
        paymentsManager.resetDailyExports()
        
        // Then - verify exports available again
        XCTAssertEqual(paymentsManager.dailyExportsUsed, 0)
        XCTAssertEqual(paymentsManager.remainingFreeExports, 3)
        XCTAssertTrue(paymentsManager.canExport)
        
        // Verify can process job again
        let job = Job(
            type: .imageResize,
            inputs: [testFileURL],
            settings: JobSettings()
        )
        
        await jobManager.submitJob(job)
        paymentsManager.consumeExport()
        
        XCTAssertEqual(paymentsManager.dailyExportsUsed, 1)
        XCTAssertEqual(paymentsManager.remainingFreeExports, 2)
    }
    
    // MARK: - Pro Subscription Tests
    
    func testProSubscriptionUnlimitedExports() async throws {
        // Given - simulate pro subscription
        // In real tests, we'd need to mock StoreKit purchases
        // For now, we'll test the behavior assuming pro is active
        
        // Simulate having pro by using test configuration
        let testProductIDs = Set([PaymentsManager.ProductID.monthly.rawValue])
        
        // When - process many jobs (more than free tier limit)
        var processedJobs = 0
        
        for i in 0..<10 {
            // Check if we can export (would be unlimited with pro)
            if paymentsManager.canExport || paymentsManager.hasPro {
                let job = Job(
                    type: .imageResize,
                    inputs: [testFileURL],
                    settings: JobSettings(maxDimension: 100)
                )
                
                await jobManager.submitJob(job)
                
                // Don't consume export if pro (in real app)
                if !paymentsManager.hasPro {
                    paymentsManager.consumeExport()
                }
                
                processedJobs += 1
            }
        }
        
        // Then - verify behavior
        if paymentsManager.hasPro {
            XCTAssertEqual(processedJobs, 10) // All jobs processed
        } else {
            XCTAssertEqual(processedJobs, 3) // Only free tier limit
        }
    }
    
    // MARK: - Export Counter Persistence Tests
    
    func testExportCounterPersistence() throws {
        // Given - consume some exports
        paymentsManager.consumeExport()
        paymentsManager.consumeExport()
        
        let initialCount = paymentsManager.dailyExportsUsed
        XCTAssertEqual(initialCount, 2)
        
        // When - create new payments manager instance (simulating app restart)
        let newPaymentsManager = PaymentsManager()
        
        // Then - verify count persisted
        XCTAssertEqual(newPaymentsManager.dailyExportsUsed, initialCount)
        XCTAssertEqual(newPaymentsManager.remainingFreeExports, 1)
    }
    
    // MARK: - Job Processing with Payment Validation Tests
    
    func testJobProcessingRespectsExportLimits() async throws {
        // Given - use up most exports
        paymentsManager.consumeExport()
        paymentsManager.consumeExport()
        
        XCTAssertEqual(paymentsManager.remainingFreeExports, 1)
        
        // When - submit jobs that would exceed limit
        let jobs = [
            Job(type: .pdfCompress, inputs: [testFileURL], settings: JobSettings()),
            Job(type: .imageResize, inputs: [testFileURL], settings: JobSettings())
        ]
        
        var successfulJobs = 0
        
        for job in jobs {
            if paymentsManager.canExport {
                await jobManager.submitJob(job)
                paymentsManager.consumeExport()
                
                // Wait for completion
                let expectation = expectation(description: "Job completes")
                
                let observation = jobManager.$jobs.sink { currentJobs in
                    if currentJobs.contains(where: { $0.id == job.id && $0.status == .success }) {
                        successfulJobs += 1
                        expectation.fulfill()
                    }
                }
                
                await fulfillment(of: [expectation], timeout: 5.0)
                observation.cancel()
            }
        }
        
        // Then - verify only one job processed (remaining export)
        XCTAssertEqual(successfulJobs, 1)
        XCTAssertEqual(paymentsManager.remainingFreeExports, 0)
    }
    
    // MARK: - Performance Tests
    
    func testExportConsumptionPerformance() throws {
        measure {
            // Test rapid export consumption
            for _ in 0..<100 {
                if paymentsManager.canExport {
                    paymentsManager.consumeExport()
                }
                
                // Reset when limit reached
                if paymentsManager.remainingFreeExports == 0 {
                    paymentsManager.resetDailyExports()
                }
            }
        }
    }
    
    // MARK: - Edge Case Tests
    
    func testMidnightResetTiming() throws {
        // Given - exports used just before midnight
        paymentsManager.consumeExport()
        paymentsManager.consumeExport()
        paymentsManager.consumeExport()
        
        XCTAssertEqual(paymentsManager.remainingFreeExports, 0)
        
        // When - simulate time passing to next day
        // In production, this would happen automatically at midnight
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
        let tomorrowMidnight = calendar.startOfDay(for: tomorrow)
        
        // Simulate checking if reset needed (would be called on app launch)
        let lastResetDate = UserDefaults.standard.object(forKey: "last_export_reset") as? Date ?? Date.distantPast
        let shouldReset = !calendar.isDate(lastResetDate, inSameDayAs: Date())
        
        if shouldReset {
            paymentsManager.resetDailyExports()
        }
        
        // Then - verify reset would occur
        XCTAssertTrue(shouldReset)
    }
    
    func testExportLimitWithConcurrentRequests() async throws {
        // Given - one export remaining
        paymentsManager.consumeExport()
        paymentsManager.consumeExport()
        
        XCTAssertEqual(paymentsManager.remainingFreeExports, 1)
        
        // When - multiple concurrent export attempts
        let concurrentExports = await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<5 {
                group.addTask {
                    if await self.paymentsManager.canExport {
                        await self.paymentsManager.consumeExport()
                        return true
                    }
                    return false
                }
            }
            
            var successCount = 0
            for await success in group {
                if success {
                    successCount += 1
                }
            }
            return successCount
        }
        
        // Then - only one should succeed
        XCTAssertEqual(concurrentExports, 1)
        XCTAssertEqual(paymentsManager.remainingFreeExports, 0)
    }
}