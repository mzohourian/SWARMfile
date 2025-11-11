//
//  JobEngine.swift
//  OneBox - Job Engine Module
//
//  Manages background processing jobs with progress tracking, persistence, and cancellation
//

import Foundation
import Combine
import BackgroundTasks
import CorePDF
import CoreImageKit
import VideoProcessor
import CoreZip

// MARK: - Job Model
public struct Job: Identifiable, Codable {
    public let id: UUID
    public let type: JobType
    public var inputs: [URL]
    public var settings: JobSettings
    public var status: JobStatus
    public var progress: Double
    public var outputURLs: [URL]
    public var error: String?
    public let createdAt: Date
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        type: JobType,
        inputs: [URL],
        settings: JobSettings = JobSettings(),
        status: JobStatus = .pending,
        progress: Double = 0,
        outputURLs: [URL] = [],
        error: String? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.type = type
        self.inputs = inputs
        self.settings = settings
        self.status = status
        self.progress = progress
        self.outputURLs = outputURLs
        self.error = error
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

// MARK: - Job Type
public enum JobType: String, Codable, CaseIterable {
    case imagesToPDF
    case pdfMerge
    case pdfSplit
    case pdfCompress
    case pdfWatermark
    case pdfSign
    case imageResize
    case videoCompress
    case zip
    case unzip

    public var displayName: String {
        switch self {
        case .imagesToPDF: return "Images to PDF"
        case .pdfMerge: return "Merge PDFs"
        case .pdfSplit: return "Split PDF"
        case .pdfCompress: return "Compress PDF"
        case .pdfWatermark: return "Watermark PDF"
        case .pdfSign: return "Sign PDF"
        case .imageResize: return "Resize Images"
        case .videoCompress: return "Compress Video"
        case .zip: return "Create ZIP"
        case .unzip: return "Extract ZIP"
        }
    }
}

// MARK: - Job Status
public enum JobStatus: String, Codable {
    case pending
    case running
    case success
    case failed
}

// MARK: - Job Settings
public struct JobSettings: Codable {
    // PDF Settings
    public var pageSize: PDFPageSize = .a4
    public var orientation: PDFOrientation = .portrait
    public var margins: CGFloat = 20
    public var backgroundColor: String = "#FFFFFF"
    public var stripMetadata: Bool = true
    public var pdfTitle: String?
    public var pdfAuthor: String?
    public var targetSizeMB: Double?
    public var compressionQuality: CompressionQuality = .medium

    // Image Settings
    public var imageFormat: ImageFormat = .jpeg
    public var imageQuality: Double = 0.8
    public var maxDimension: Int?
    public var resizePercentage: Double?

    // Video Settings
    public var videoPreset: VideoCompressionPreset = .mediumQuality
    public var keepAudio: Bool = true
    public var targetBitrate: Int?

    // Watermark Settings
    public var watermarkText: String?
    public var watermarkPosition: WatermarkPosition = .bottomRight
    public var watermarkOpacity: Double = 0.5
    public var watermarkSize: Double = 0.2

    public init() {}
}

public enum PDFPageSize: String, Codable, CaseIterable {
    case a4
    case letter
    case fit

    public var displayName: String {
        switch self {
        case .a4: return "A4"
        case .letter: return "Letter"
        case .fit: return "Fit to Image"
        }
    }

    public var size: CGSize? {
        switch self {
        case .a4: return CGSize(width: 595, height: 842) // A4 in points
        case .letter: return CGSize(width: 612, height: 792) // Letter in points
        case .fit: return nil
        }
    }
}

public enum PDFOrientation: String, Codable {
    case portrait
    case landscape
}

public enum CompressionQuality: String, Codable, CaseIterable {
    case maximum
    case high
    case medium
    case low

    public var displayName: String {
        switch self {
        case .maximum: return "Maximum"
        case .high: return "High"
        case .medium: return "Medium"
        case .low: return "Low"
        }
    }

    public var jpegQuality: Double {
        switch self {
        case .maximum: return 0.3
        case .high: return 0.5
        case .medium: return 0.7
        case .low: return 0.85
        }
    }
}

public enum ImageFormat: String, Codable {
    case jpeg
    case png
    case heic

    public var displayName: String {
        rawValue.uppercased()
    }
}

public enum VideoPreset: String, Codable, CaseIterable {
    case highQuality
    case mediumQuality
    case lowQuality
    case socialMedia

    public var displayName: String {
        switch self {
        case .highQuality: return "High Quality"
        case .mediumQuality: return "Medium Quality"
        case .lowQuality: return "Low Quality"
        case .socialMedia: return "Social Media"
        }
    }
}

public enum WatermarkPosition: String, Codable, CaseIterable {
    case topLeft, topCenter, topRight
    case middleLeft, center, middleRight
    case bottomLeft, bottomCenter, bottomRight
    case tiled

    public var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Center"
        case .topRight: return "Top Right"
        case .middleLeft: return "Middle Left"
        case .center: return "Center"
        case .middleRight: return "Middle Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        case .tiled: return "Tiled"
        }
    }
}

// MARK: - Job Manager
@MainActor
public class JobManager: ObservableObject {
    public static let shared = JobManager()

    @Published public var jobs: [Job] = []
    private var cancellables = Set<AnyCancellable>()
    private let processingQueue = DispatchQueue(label: "com.onebox.jobengine", qos: .userInitiated)
    private var currentTask: Task<Void, Never>?

    private let persistenceURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("jobs.json")
    }()

    private init() {
        loadJobs()
        setupBackgroundTask()
    }

    // MARK: - Public Methods
    public func submitJob(_ job: Job) {
        jobs.append(job)
        saveJobs()
        processNextJob()
    }

    public func cancelJob(_ job: Job) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index].status = .failed
        jobs[index].error = "Cancelled by user"
        saveJobs()
        currentTask?.cancel()
    }

    public func deleteJob(_ job: Job) {
        jobs.removeAll { $0.id == job.id }
        saveJobs()

        // Clean up output files
        for url in job.outputURLs {
            try? FileManager.default.removeItem(at: url)
        }
    }

    public func retryJob(_ job: Job) {
        var retryJob = job
        retryJob.status = .pending
        retryJob.progress = 0
        retryJob.error = nil
        retryJob.outputURLs = []

        if let index = jobs.firstIndex(where: { $0.id == job.id }) {
            jobs[index] = retryJob
            saveJobs()
            processNextJob()
        }
    }

    // MARK: - Private Methods
    private func processNextJob() {
        guard currentTask == nil else { return }
        guard let nextJob = jobs.first(where: { $0.status == .pending }) else { return }

        currentTask = Task {
            await processJob(nextJob)
            currentTask = nil
            processNextJob() // Process next queued job
        }
    }

    private func processJob(_ job: Job) async {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }

        // Update status to running
        jobs[index].status = .running
        saveJobs()

        do {
            let processor = JobProcessor()
            let outputURLs = try await processor.process(
                job: job,
                progressHandler: { [weak self] progress in
                    Task { @MainActor in
                        guard let self = self,
                              let idx = self.jobs.firstIndex(where: { $0.id == job.id }) else { return }
                        self.jobs[idx].progress = progress
                        self.saveJobs()
                    }
                }
            )

            jobs[index].status = .success
            jobs[index].progress = 1.0
            jobs[index].outputURLs = outputURLs
            jobs[index].completedAt = Date()
        } catch {
            jobs[index].status = .failed
            jobs[index].error = error.localizedDescription
        }

        saveJobs()
    }

    private func loadJobs() {
        guard let data = try? Data(contentsOf: persistenceURL),
              let loadedJobs = try? JSONDecoder().decode([Job].self, from: data) else {
            return
        }
        jobs = loadedJobs

        // Resume any running jobs
        for job in jobs where job.status == .running {
            var resumedJob = job
            resumedJob.status = .pending
            if let index = jobs.firstIndex(where: { $0.id == job.id }) {
                jobs[index] = resumedJob
            }
        }
    }

    private func saveJobs() {
        guard let data = try? JSONEncoder().encode(jobs) else { return }
        try? data.write(to: persistenceURL)
    }

    private func setupBackgroundTask() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.onebox.process",
            using: nil
        ) { task in
            self.handleBackgroundTask(task as! BGProcessingTask)
        }
    }

    private func handleBackgroundTask(_ task: BGProcessingTask) {
        task.expirationHandler = {
            self.currentTask?.cancel()
        }

        Task {
            await processNextPendingJob()
            task.setTaskCompleted(success: true)
        }
    }

    private func processNextPendingJob() async {
        guard let nextJob = jobs.first(where: { $0.status == .pending }) else { return }
        await processJob(nextJob)
    }
}

// MARK: - Job Processor
actor JobProcessor {
    func process(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        switch job.type {
        case .imagesToPDF:
            return try await processImagesToPDF(job: job, progressHandler: progressHandler)
        case .pdfMerge:
            return try await processPDFMerge(job: job, progressHandler: progressHandler)
        case .pdfSplit:
            return try await processPDFSplit(job: job, progressHandler: progressHandler)
        case .pdfCompress:
            return try await processPDFCompress(job: job, progressHandler: progressHandler)
        case .pdfWatermark:
            return try await processPDFWatermark(job: job, progressHandler: progressHandler)
        case .pdfSign:
            return try await processPDFSign(job: job, progressHandler: progressHandler)
        case .imageResize:
            return try await processImageResize(job: job, progressHandler: progressHandler)
        case .videoCompress:
            return try await processVideoCompress(job: job, progressHandler: progressHandler)
        case .zip:
            return try await processZip(job: job, progressHandler: progressHandler)
        case .unzip:
            return try await processUnzip(job: job, progressHandler: progressHandler)
        }
    }

    // Placeholder implementations - will be implemented in specific modules
    private func processImagesToPDF(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        // Implementation in CorePDF module
        throw JobError.notImplemented
    }

    private func processPDFMerge(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }

    private func processPDFSplit(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }

    private func processPDFCompress(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }

    private func processPDFWatermark(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }

    private func processPDFSign(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }

    private func processImageResize(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }

    private func processVideoCompress(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }

    private func processZip(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }

    private func processUnzip(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        throw JobError.notImplemented
    }
}

// MARK: - Job Error
public enum JobError: LocalizedError {
    case notImplemented
    case invalidInput
    case processingFailed(String)
    case insufficientSpace
    case cancelled

    public var errorDescription: String? {
        switch self {
        case .notImplemented:
            return "This feature is not yet implemented"
        case .invalidInput:
            return "Invalid input files"
        case .processingFailed(let message):
            return "Processing failed: \(message)"
        case .insufficientSpace:
            return "Not enough storage space"
        case .cancelled:
            return "Operation cancelled"
        }
    }
}
