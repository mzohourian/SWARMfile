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
import UIKit
import PDFKit

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
    case pdfToImages
    case pdfMerge
    case pdfSplit
    case pdfCompress
    case pdfWatermark
    case pdfSign
    case pdfOrganize
    case imageResize
    case videoCompress
    case zip
    case unzip

    public var displayName: String {
        switch self {
        case .imagesToPDF: return "Images to PDF"
        case .pdfToImages: return "PDF to Images"
        case .pdfMerge: return "Merge PDFs"
        case .pdfSplit: return "Split PDF"
        case .pdfCompress: return "Compress PDF"
        case .pdfWatermark: return "Watermark PDF"
        case .pdfSign: return "Sign PDF"
        case .pdfOrganize: return "Organize Pages"
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
    public var imageResolution: CGFloat = 150.0  // DPI for PDF to Images

    // Video Settings
    public var videoPreset: VideoCompressionPreset = .mediumQuality
    public var keepAudio: Bool = true
    public var targetBitrate: Int?

    // Watermark Settings
    public var watermarkText: String?
    public var watermarkPosition: WatermarkPosition = .bottomRight
    public var watermarkOpacity: Double = 0.5
    public var watermarkSize: Double = 0.2

    // PDF Split Settings
    public var splitRanges: [[Int]] = []  // Array of page ranges [[1,2,3], [4], [5]]

    // PDF Signature Settings
    public var signatureType: SignatureType = .text
    public var signatureText: String?
    public var signatureImageData: Data?  // For handwritten signatures
    public var signaturePosition: WatermarkPosition = .bottomRight
    public var signatureOpacity: Double = 1.0
    public var signatureSize: Double = 0.15

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

public enum SignatureType: String, Codable, CaseIterable {
    case text
    case handwritten

    public var displayName: String {
        switch self {
        case .text: return "Text"
        case .handwritten: return "Handwritten"
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
        case .pdfToImages:
            return try await processPDFToImages(job: job, progressHandler: progressHandler)
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
        case .pdfOrganize:
            // Page Organizer is handled through interactive UI (PageOrganizerView)
            // Jobs are created after user completes organization, already processed
            // This case should not normally be reached through standard job flow
            guard let pdfURL = job.inputs.first else {
                throw JobError.invalidInput
            }
            return [pdfURL]  // Return original URL as it's already processed
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

    // MARK: - Job Processing Implementations
    private func processImagesToPDF(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        let outputURL = try await processor.createPDF(
            from: job.inputs,
            pageSize: job.settings.pageSize.size,
            orientation: job.settings.orientation,
            margins: job.settings.margins,
            backgroundColor: UIColor(hex: job.settings.backgroundColor) ?? .white,
            stripMetadata: job.settings.stripMetadata,
            progressHandler: progressHandler
        )
        return [outputURL]
    }

    private func processPDFToImages(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }

        let format = job.settings.imageFormat == .png ? "png" : "jpeg"
        let outputURLs = try await processor.pdfToImages(
            pdfURL,
            format: format,
            quality: job.settings.imageQuality,
            resolution: job.settings.imageResolution,
            progressHandler: progressHandler
        )
        return outputURLs
    }

    private func processPDFMerge(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        let outputURL = try await processor.mergePDFs(job.inputs, progressHandler: progressHandler)
        return [outputURL]
    }

    private func processPDFSplit(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }

        // Get total page count from PDF
        guard let pdf = PDFDocument(url: pdfURL) else {
            throw JobError.invalidInput
        }

        // Use custom ranges if provided, otherwise split into individual pages
        let ranges: [ClosedRange<Int>]
        if !job.settings.splitRanges.isEmpty {
            // Convert user-facing 1-based page numbers to 0-based indices
            ranges = job.settings.splitRanges.compactMap { pageArray -> ClosedRange<Int>? in
                guard let first = pageArray.first, let last = pageArray.last else { return nil }
                // Convert from 1-based (user input) to 0-based (PDF indices)
                return (first - 1)...(last - 1)
            }
        } else {
            // Default: split into individual pages
            let pageCount = pdf.pageCount
            ranges = (0..<pageCount).map { $0...$0 }
        }

        let outputURLs = try await processor.splitPDF(pdfURL, ranges: ranges, progressHandler: progressHandler)
        return outputURLs
    }

    private func processPDFCompress(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }

        let outputURL = try await processor.compressPDF(
            pdfURL,
            quality: job.settings.compressionQuality,
            targetSizeMB: job.settings.targetSizeMB,
            progressHandler: progressHandler
        )
        return [outputURL]
    }

    private func processPDFWatermark(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }
        let outputURL = try await processor.watermarkPDF(
            pdfURL,
            text: job.settings.watermarkText,
            position: job.settings.watermarkPosition,
            opacity: job.settings.watermarkOpacity,
            tiled: job.settings.watermarkPosition == .tiled,
            progressHandler: progressHandler
        )
        return [outputURL]
    }

    private func processPDFSign(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }

        // Handle handwritten signature if provided
        var signatureImage: UIImage?
        if job.settings.signatureType == .handwritten,
           let imageData = job.settings.signatureImageData {
            signatureImage = UIImage(data: imageData)
        }

        let outputURL = try await processor.signPDF(
            pdfURL,
            text: job.settings.signatureType == .text ? job.settings.signatureText : nil,
            image: signatureImage,
            position: job.settings.signaturePosition,
            opacity: job.settings.signatureOpacity,
            size: job.settings.signatureSize,
            progressHandler: progressHandler
        )
        return [outputURL]
    }

    private func processImageResize(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = ImageProcessor()
        let outputURLs = try await processor.processImages(
            job.inputs,
            format: job.settings.imageFormat,
            quality: job.settings.imageQuality,
            maxDimension: job.settings.maxDimension,
            stripEXIF: job.settings.stripMetadata,
            progressHandler: progressHandler
        )
        return outputURLs
    }

    private func processVideoCompress(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = VideoProcessor()
        guard let videoURL = job.inputs.first else {
            throw JobError.invalidInput
        }
        let outputURL = try await processor.compressVideo(
            videoURL,
            preset: job.settings.videoPreset,
            targetSizeMB: job.settings.targetSizeMB,
            keepAudio: job.settings.keepAudio,
            codec: VideoCodec.h264,
            progressHandler: progressHandler
        )
        return [outputURL]
    }

    private func processZip(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = ZipProcessor()
        let outputURL = try await processor.createZip(
            from: job.inputs,
            outputName: "archive",
            progressHandler: progressHandler
        )
        return [outputURL]
    }

    private func processUnzip(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = ZipProcessor()
        guard let zipURL = job.inputs.first else {
            throw JobError.invalidInput
        }
        let extractedDir = try await processor.extractZip(zipURL, progressHandler: progressHandler)
        // Return all extracted files
        let fileManager = FileManager.default
        let files = try fileManager.contentsOfDirectory(at: extractedDir, includingPropertiesForKeys: nil)
        return files
    }
}

// MARK: - Job Error
public enum JobError: LocalizedError {
    case notImplemented
    case invalidInput
    case processingFailed(String)
    case insufficientSpace
    case cancelled
    case featureComingSoon(String)

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
        case .featureComingSoon(let message):
            return message
        }
    }
}

// MARK: - UIColor Extension
extension UIColor {
    convenience init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let green = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let blue = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}
