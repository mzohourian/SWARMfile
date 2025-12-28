//
//  JobEnginePerformanceTests.swift
//  OneBox - Performance Benchmarks for Job Processing System
//

import XCTest
@testable import JobEngine
@testable import CommonTypes
import UIKit

@MainActor
final class JobEnginePerformanceTests: XCTestCase {
    
    var jobManager: JobManager!
    var testFiles: [URL]!
    
    override func setUp() async throws {
        jobManager = JobManager.shared
        testFiles = try createTestFiles()
    }
    
    override func tearDown() async throws {
        // Clean up test files and job outputs
        for url in testFiles ?? [] {
            try? FileManager.default.removeItem(at: url)
        }
        
        for job in jobManager.jobs {
            for outputURL in job.outputURLs {
                try? FileManager.default.removeItem(at: outputURL)
            }
            jobManager.deleteJob(job)
        }
        
        testFiles = nil
        jobManager = nil
    }
    
    // MARK: - Test Data Creation
    
    private func createTestFiles() throws -> [URL] {
        var urls: [URL] = []
        
        // Create test images
        for i in 0..<50 {
            let image = createTestImage(size: CGSize(width: 1024, height: 768), index: i)
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("job_perf_image_\(i).jpg")
            try image.jpegData(compressionQuality: 0.9)?.write(to: url)
            urls.append(url)
        }
        
        // Create test PDFs
        for i in 0..<10 {
            let url = try createTestPDF(pages: 5, index: i)
            urls.append(url)
        }
        
        return urls
    }
    
    private func createTestImage(size: CGSize, index: Int) -> UIImage {
        UIGraphicsBeginImageContext(size)
        defer { UIGraphicsEndImageContext() }
        
        let context = UIGraphicsGetCurrentContext()!
        
        // Create colorful background
        let hue = CGFloat(index) / 50.0
        UIColor(hue: hue, saturation: 0.8, brightness: 0.9, alpha: 1.0).setFill()
        context.fill(CGRect(origin: .zero, size: size))
        
        // Add text
        let text = "Image \(index)"
        text.draw(at: CGPoint(x: 20, y: 20), withAttributes: [
            .font: UIFont.systemFont(ofSize: 24),
            .foregroundColor: UIColor.white
        ])
        
        return UIGraphicsGetImageFromCurrentImageContext()!
    }
    
    private func createTestPDF(pages: Int, index: Int) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("job_perf_pdf_\(index).pdf")
        
        UIGraphicsBeginPDFContextToFile(url.path, .zero, nil)
        
        for page in 0..<pages {
            UIGraphicsBeginPDFPageWithInfo(CGRect(x: 0, y: 0, width: 595, height: 842), nil)
            
            let text = "PDF \(index) - Page \(page + 1)"
            text.draw(at: CGPoint(x: 100, y: 100), withAttributes: [
                .font: UIFont.systemFont(ofSize: 18)
            ])
        }
        
        UIGraphicsEndPDFContext()
        return url
    }
    
    // MARK: - Job Submission Performance Tests
    
    func testJobSubmissionPerformance() async throws {
        // Test rapid job submission
        let jobs = Array(0..<100).map { index in
            Job(
                type: .imageResize,
                inputs: [testFiles[index % testFiles.count]],
                settings: JobSettings(maxDimension: 400)
            )
        }
        
        measure {
            let expectation = expectation(description: "Rapid job submission")
            
            Task {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                for job in jobs {
                    await jobManager.submitJob(job)
                }
                
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                print("📊 100 jobs submitted in \(String(format: "%.3f", duration))s (\(String(format: "%.1f", 100.0/duration)) jobs/sec)")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 10.0)
        }
        
        // Clean up jobs
        for job in jobs {
            jobManager.deleteJob(job)
        }
    }
    
    func testJobQueueProcessingThroughput() async throws {
        // Test job processing throughput
        let imageFiles = testFiles.filter { $0.pathExtension == "jpg" }
        let batchSize = 20
        
        let jobs = Array(0..<batchSize).map { index in
            Job(
                type: .imageResize,
                inputs: [imageFiles[index % imageFiles.count]],
                settings: JobSettings(maxDimension: 800)
            )
        }
        
        measure {
            let expectation = expectation(description: "Job queue throughput")
            
            Task {
                let startTime = CFAbsoluteTimeGetCurrent()
                var completedCount = 0
                
                // Submit all jobs
                for job in jobs {
                    await jobManager.submitJob(job)
                }
                
                // Monitor completion
                let observation = jobManager.$jobs.sink { currentJobs in
                    let newCompletedCount = currentJobs.filter { job in
                        jobs.contains(where: { $0.id == job.id }) && job.status == .success
                    }.count
                    
                    if newCompletedCount > completedCount {
                        completedCount = newCompletedCount
                        let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                        print("📈 \(completedCount)/\(batchSize) jobs completed (\(String(format: "%.2f", elapsed))s)")
                    }
                    
                    if completedCount == batchSize {
                        let totalDuration = CFAbsoluteTimeGetCurrent() - startTime
                        let throughput = Double(batchSize) / totalDuration
                        print("📊 Throughput: \(String(format: "%.1f", throughput)) jobs/sec")
                        expectation.fulfill()
                    }
                }
                
                // Set timeout to prevent hanging
                DispatchQueue.main.asyncAfter(deadline: .now() + 45) {
                    observation.cancel()
                    if completedCount < batchSize {
                        print("⚠️  Timeout: Only \(completedCount)/\(batchSize) jobs completed")
                        expectation.fulfill()
                    }
                }
            }
            
            wait(for: [expectation], timeout: 60.0)
        }
    }
    
    // MARK: - Job Progress Tracking Performance Tests
    
    func testProgressTrackingPerformance() async throws {
        // Test performance of progress tracking with many jobs
        let jobs = Array(0..<50).map { index in
            Job(
                type: .imagesToPDF,
                inputs: Array(testFiles.filter { $0.pathExtension == "jpg" }.prefix(5)),
                settings: JobSettings()
            )
        }
        
        measure {
            let expectation = expectation(description: "Progress tracking performance")
            
            Task {
                let startTime = CFAbsoluteTimeGetCurrent()
                var progressUpdateCount = 0
                
                // Submit all jobs
                for job in jobs {
                    await jobManager.submitJob(job)
                }
                
                // Track progress updates
                let observation = jobManager.$jobs.sink { currentJobs in
                    progressUpdateCount += 1
                    
                    let completedJobs = currentJobs.filter { job in
                        jobs.contains(where: { $0.id == job.id }) && job.status == .success
                    }
                    
                    if completedJobs.count == jobs.count {
                        let duration = CFAbsoluteTimeGetCurrent() - startTime
                        print("📊 Progress tracking: \(progressUpdateCount) updates in \(String(format: "%.2f", duration))s")
                        expectation.fulfill()
                    }
                }
                
                // Prevent hanging
                DispatchQueue.main.asyncAfter(deadline: .now() + 90) {
                    observation.cancel()
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: 120.0)
        }
    }
    
    // MARK: - Job Persistence Performance Tests
    
    func testJobPersistencePerformance() async throws {
        // Test performance of job persistence with many jobs
        let jobs = Array(0..<200).map { index in
            Job(
                type: .pdfCompress,
                inputs: [testFiles.filter { $0.pathExtension == "pdf" }.first!],
                settings: JobSettings()
            )
        }
        
        measureMetrics([.wallClockTime], automaticallyStartMeasuring: false) {
            let expectation = expectation(description: "Job persistence performance")
            
            Task {
                startMeasuring()
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // Submit jobs rapidly to test persistence performance
                for job in jobs {
                    await jobManager.submitJob(job)
                }
                
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                print("📊 200 jobs persisted in \(String(format: "%.3f", duration))s")
                
                stopMeasuring()
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
        
        // Clean up
        for job in jobs {
            jobManager.deleteJob(job)
        }
    }
    
    // MARK: - Memory Usage Tests
    
    func testJobManagerMemoryUsage() async throws {
        // Test memory usage with large number of jobs
        let startMemory = getMemoryUsage()
        
        measure {
            let expectation = expectation(description: "Job manager memory usage")
            
            Task {
                // Create many jobs
                let jobs = Array(0..<1000).map { index in
                    Job(
                        type: .imageResize,
                        inputs: [testFiles[index % testFiles.count]],
                        settings: JobSettings()
                    )
                }
                
                // Submit all jobs
                for job in jobs {
                    await jobManager.submitJob(job)
                }
                
                let peakMemory = getMemoryUsage()
                let memoryIncrease = peakMemory - startMemory
                
                print("🧠 Memory usage: \(startMemory)MB → \(peakMemory)MB (+\(memoryIncrease)MB for 1000 jobs)")
                
                // Clean up
                for job in jobs {
                    jobManager.deleteJob(job)
                }
                
                let endMemory = getMemoryUsage()
                print("🧠 Memory after cleanup: \(endMemory)MB")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Concurrent Access Performance Tests
    
    func testConcurrentJobAccessPerformance() async throws {
        // Test performance with multiple concurrent operations
        let jobs = Array(0..<100).map { index in
            Job(
                type: .imageResize,
                inputs: [testFiles[index % testFiles.count]],
                settings: JobSettings()
            )
        }
        
        measure {
            let expectation = expectation(description: "Concurrent access performance")
            expectation.expectedFulfillmentCount = 4
            
            let startTime = CFAbsoluteTimeGetCurrent()
            
            // Concurrent job submission
            Task {
                for job in jobs.prefix(25) {
                    await jobManager.submitJob(job)
                }
                expectation.fulfill()
            }
            
            // Concurrent job deletion
            Task {
                await Task.sleep(nanoseconds: 100_000_000) // 0.1s delay
                for job in Array(jobManager.jobs.suffix(10)) {
                    jobManager.deleteJob(job)
                }
                expectation.fulfill()
            }
            
            // Concurrent job status checking
            Task {
                for _ in 0..<100 {
                    let _ = jobManager.jobs.filter { $0.status == .pending }
                    await Task.yield()
                }
                expectation.fulfill()
            }
            
            // Concurrent job progress monitoring
            Task {
                var lastCount = 0
                for _ in 0..<50 {
                    let currentCount = jobManager.jobs.count
                    if currentCount != lastCount {
                        lastCount = currentCount
                        print("📊 Job count: \(currentCount)")
                    }
                    await Task.sleep(nanoseconds: 50_000_000) // 0.05s
                }
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 20.0)
            
            let duration = CFAbsoluteTimeGetCurrent() - startTime
            print("📊 Concurrent operations completed in \(String(format: "%.2f", duration))s")
        }
    }
    
    // MARK: - Background Processing Performance Tests
    
    func testBackgroundProcessingPerformance() async throws {
        // Test performance when app goes to background
        let backgroundJobs = Array(0..<20).map { index in
            Job(
                type: .pdfMerge,
                inputs: Array(testFiles.filter { $0.pathExtension == "pdf" }.prefix(3)),
                settings: JobSettings()
            )
        }
        
        measure {
            let expectation = expectation(description: "Background processing")
            
            Task {
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // Submit background-capable jobs
                for job in backgroundJobs {
                    await jobManager.submitJob(job)
                }
                
                // Simulate background processing
                await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                
                // Check progress
                let progressSum = jobManager.jobs.reduce(0.0) { sum, job in
                    sum + job.progress
                }
                let avgProgress = progressSum / Double(backgroundJobs.count)
                
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                print("📊 Background processing: avg progress \(String(format: "%.1f", avgProgress * 100))% in \(String(format: "%.2f", duration))s")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 30.0)
        }
    }
    
    // MARK: - Job Cancellation Performance Tests
    
    func testJobCancellationPerformance() async throws {
        // Test performance of rapid job cancellation
        let jobs = Array(0..<100).map { index in
            Job(
                type: .imagesToPDF,
                inputs: Array(testFiles.filter { $0.pathExtension == "jpg" }.prefix(10)),
                settings: JobSettings()
            )
        }
        
        measure {
            let expectation = expectation(description: "Job cancellation performance")
            
            Task {
                // Submit all jobs
                for job in jobs {
                    await jobManager.submitJob(job)
                }
                
                let startTime = CFAbsoluteTimeGetCurrent()
                
                // Cancel all jobs rapidly
                for job in jobs {
                    await jobManager.cancelJob(job.id)
                }
                
                let duration = CFAbsoluteTimeGetCurrent() - startTime
                print("📊 100 jobs cancelled in \(String(format: "%.3f", duration))s")
                
                expectation.fulfill()
            }
            
            wait(for: [expectation], timeout: 15.0)
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