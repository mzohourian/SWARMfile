//
//  JobEngine.swift
//  OneBox - Job Engine Module
//
//  Manages background processing jobs with progress tracking, persistence, and cancellation
//

import Foundation
import Combine
import BackgroundTasks
import CommonTypes
import CorePDF
import CoreImageKit
import UIKit
import PDFKit
import Privacy

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
    case splitPDF  // Smart split with AI
    case pdfCompress
    case pdfWatermark
    case pdfSign
    case pdfOrganize
    case fillForm  // Form filling and stamps
    case imageResize
    case pdfRedact

    public var displayName: String {
        switch self {
        case .imagesToPDF: return "Images to PDF"
        case .pdfToImages: return "PDF to Images"
        case .pdfMerge: return "Merge PDFs"
        case .pdfSplit: return "Split PDF"
        case .splitPDF: return "Smart Split PDF"
        case .pdfCompress: return "Compress PDF"
        case .pdfWatermark: return "Watermark PDF"
        case .pdfSign: return "Sign PDF"
        case .pdfOrganize: return "Organize Pages"
        case .fillForm: return "Fill Forms & Stamps"
        case .imageResize: return "Resize Images"
        case .pdfRedact: return "Redact PDF"
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
public struct JobSettings {
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
    public var imageQuality: Double = 0.6  // Sync with medium preset
    public var imageQualityPreset: ImageQuality = .medium
    public var maxDimension: Int?
    public var resizePercentage: Double?
    public var imageResolution: CGFloat = 100.0  // DPI for PDF to Images

    // Watermark Settings
    public var watermarkText: String?
    public var watermarkPosition: WatermarkPosition = .bottomRight
    public var watermarkOpacity: Double = 0.5
    public var watermarkSize: Double = 0.2
    public var watermarkTileDensity: Double = 0.3 // For tiled watermarks (spacing between tiles)

    // PDF Split Settings
    public var splitRanges: [[Int]] = []  // Array of page ranges [[1,2,3], [4], [5]]
    public var selectAllPages: Bool = true  // For PDF to Images - select all pages vs specific ranges

    // PDF Signature Settings
    public var signatureText: String?
    public var signatureImageData: Data?
    public var signaturePosition: WatermarkPosition = .bottomRight
    public var signatureCustomPosition: CGPoint? // For custom positioning
    public var signaturePageIndex: Int = -1 // -1 means last page, 0+ means specific page
    public var signatureOpacity: Double = 1.0
    public var signatureSize: Double = 0.15
    
    // PDF Redaction Settings
    public var redactionItems: [String] = [] // Text patterns to redact
    public var redactionMode: String = "automatic" // automatic, manual, combined
    public var redactionColor: String = "#000000" // Color of redaction boxes
    
    // Privacy Settings
    public var enableSecureVault: Bool = false
    public var enableZeroTrace: Bool = false
    public var enableBiometricLock: Bool = false
    public var enableStealthMode: Bool = false
    public var enableDocumentSanitization: Bool = false
    public var enableEncryption: Bool = false
    public var encryptionPassword: String?
    public var complianceMode: Privacy.ComplianceMode = .none

    public init() {}
}

// MARK: - JobSettings Codable Implementation
extension JobSettings: Codable {
    enum CodingKeys: String, CodingKey {
        case pageSize, orientation, margins, backgroundColor, stripMetadata
        case pdfTitle, pdfAuthor, targetSizeMB, compressionQuality
        case imageFormat, imageQuality, imageQualityPreset, maxDimension, resizePercentage, imageResolution
        case watermarkText, watermarkPosition, watermarkOpacity, watermarkSize, watermarkTileDensity
        case splitRanges, selectAllPages
        case signatureText, signatureImageData, signaturePosition, signatureCustomPosition, signaturePageIndex, signatureOpacity, signatureSize
        case redactionItems, redactionMode, redactionColor
        case enableSecureVault, enableZeroTrace, enableBiometricLock, enableStealthMode
        case enableDocumentSanitization, enableEncryption, encryptionPassword, complianceMode
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        pageSize = try container.decodeIfPresent(PDFPageSize.self, forKey: .pageSize) ?? .a4
        orientation = try container.decodeIfPresent(PDFOrientation.self, forKey: .orientation) ?? .portrait
        margins = try container.decodeIfPresent(CGFloat.self, forKey: .margins) ?? 20
        backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? "#FFFFFF"
        stripMetadata = try container.decodeIfPresent(Bool.self, forKey: .stripMetadata) ?? true
        pdfTitle = try container.decodeIfPresent(String.self, forKey: .pdfTitle)
        pdfAuthor = try container.decodeIfPresent(String.self, forKey: .pdfAuthor)
        targetSizeMB = try container.decodeIfPresent(Double.self, forKey: .targetSizeMB)
        compressionQuality = try container.decodeIfPresent(CompressionQuality.self, forKey: .compressionQuality) ?? .medium
        
        imageFormat = try container.decodeIfPresent(ImageFormat.self, forKey: .imageFormat) ?? .jpeg
        imageQuality = try container.decodeIfPresent(Double.self, forKey: .imageQuality) ?? 0.6
        imageQualityPreset = try container.decodeIfPresent(ImageQuality.self, forKey: .imageQualityPreset) ?? .medium
        maxDimension = try container.decodeIfPresent(Int.self, forKey: .maxDimension)
        resizePercentage = try container.decodeIfPresent(Double.self, forKey: .resizePercentage)
        imageResolution = try container.decodeIfPresent(CGFloat.self, forKey: .imageResolution) ?? 100.0
        selectAllPages = try container.decodeIfPresent(Bool.self, forKey: .selectAllPages) ?? true
        
        watermarkText = try container.decodeIfPresent(String.self, forKey: .watermarkText)
        watermarkPosition = try container.decodeIfPresent(WatermarkPosition.self, forKey: .watermarkPosition) ?? .bottomRight
        watermarkOpacity = try container.decodeIfPresent(Double.self, forKey: .watermarkOpacity) ?? 0.5
        watermarkSize = try container.decodeIfPresent(Double.self, forKey: .watermarkSize) ?? 0.2
        watermarkTileDensity = try container.decodeIfPresent(Double.self, forKey: .watermarkTileDensity) ?? 0.3
        
        splitRanges = try container.decodeIfPresent([[Int]].self, forKey: .splitRanges) ?? []
        
        signatureText = try container.decodeIfPresent(String.self, forKey: .signatureText)
        signatureImageData = try container.decodeIfPresent(Data.self, forKey: .signatureImageData)
        signaturePosition = try container.decodeIfPresent(WatermarkPosition.self, forKey: .signaturePosition) ?? .bottomRight
        
        // Decode custom position as array [x, y]
        if let posArray = try container.decodeIfPresent([Double].self, forKey: .signatureCustomPosition),
           posArray.count == 2 {
            signatureCustomPosition = CGPoint(x: posArray[0], y: posArray[1])
        } else {
            signatureCustomPosition = nil
        }
        
        signaturePageIndex = try container.decodeIfPresent(Int.self, forKey: .signaturePageIndex) ?? -1
        signatureOpacity = try container.decodeIfPresent(Double.self, forKey: .signatureOpacity) ?? 1.0
        signatureSize = try container.decodeIfPresent(Double.self, forKey: .signatureSize) ?? 0.15
        
        redactionItems = try container.decodeIfPresent([String].self, forKey: .redactionItems) ?? []
        redactionMode = try container.decodeIfPresent(String.self, forKey: .redactionMode) ?? "automatic"
        redactionColor = try container.decodeIfPresent(String.self, forKey: .redactionColor) ?? "#000000"
        
        enableSecureVault = try container.decodeIfPresent(Bool.self, forKey: .enableSecureVault) ?? false
        enableZeroTrace = try container.decodeIfPresent(Bool.self, forKey: .enableZeroTrace) ?? false
        enableBiometricLock = try container.decodeIfPresent(Bool.self, forKey: .enableBiometricLock) ?? false
        enableStealthMode = try container.decodeIfPresent(Bool.self, forKey: .enableStealthMode) ?? false
        enableDocumentSanitization = try container.decodeIfPresent(Bool.self, forKey: .enableDocumentSanitization) ?? false
        enableEncryption = try container.decodeIfPresent(Bool.self, forKey: .enableEncryption) ?? false
        encryptionPassword = try container.decodeIfPresent(String.self, forKey: .encryptionPassword)
        complianceMode = try container.decodeIfPresent(Privacy.ComplianceMode.self, forKey: .complianceMode) ?? .none
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(pageSize, forKey: .pageSize)
        try container.encode(orientation, forKey: .orientation)
        try container.encode(margins, forKey: .margins)
        try container.encode(backgroundColor, forKey: .backgroundColor)
        try container.encode(stripMetadata, forKey: .stripMetadata)
        try container.encodeIfPresent(pdfTitle, forKey: .pdfTitle)
        try container.encodeIfPresent(pdfAuthor, forKey: .pdfAuthor)
        try container.encodeIfPresent(targetSizeMB, forKey: .targetSizeMB)
        try container.encode(compressionQuality, forKey: .compressionQuality)
        
        try container.encode(imageFormat, forKey: .imageFormat)
        try container.encode(imageQuality, forKey: .imageQuality)
        try container.encode(imageQualityPreset, forKey: .imageQualityPreset)
        try container.encodeIfPresent(maxDimension, forKey: .maxDimension)
        try container.encodeIfPresent(resizePercentage, forKey: .resizePercentage)
        try container.encode(imageResolution, forKey: .imageResolution)
        
        try container.encodeIfPresent(watermarkText, forKey: .watermarkText)
        try container.encode(watermarkPosition, forKey: .watermarkPosition)
        try container.encode(watermarkOpacity, forKey: .watermarkOpacity)
        try container.encode(watermarkSize, forKey: .watermarkSize)
        try container.encode(watermarkTileDensity, forKey: .watermarkTileDensity)
        
        try container.encode(splitRanges, forKey: .splitRanges)
        try container.encode(selectAllPages, forKey: .selectAllPages)
        
        try container.encodeIfPresent(signatureText, forKey: .signatureText)
        try container.encodeIfPresent(signatureImageData, forKey: .signatureImageData)
        try container.encode(signaturePosition, forKey: .signaturePosition)
        
        // Encode custom position as array [x, y]
        if let customPos = signatureCustomPosition {
            try container.encode([customPos.x, customPos.y], forKey: .signatureCustomPosition)
        }
        
        try container.encode(signaturePageIndex, forKey: .signaturePageIndex)
        try container.encode(signatureOpacity, forKey: .signatureOpacity)
        try container.encode(signatureSize, forKey: .signatureSize)
        
        try container.encode(redactionItems, forKey: .redactionItems)
        try container.encode(redactionMode, forKey: .redactionMode)
        try container.encode(redactionColor, forKey: .redactionColor)
        
        try container.encode(enableSecureVault, forKey: .enableSecureVault)
        try container.encode(enableZeroTrace, forKey: .enableZeroTrace)
        try container.encode(enableBiometricLock, forKey: .enableBiometricLock)
        try container.encode(enableStealthMode, forKey: .enableStealthMode)
        try container.encode(enableDocumentSanitization, forKey: .enableDocumentSanitization)
        try container.encode(enableEncryption, forKey: .enableEncryption)
        try container.encodeIfPresent(encryptionPassword, forKey: .encryptionPassword)
        try container.encode(complianceMode, forKey: .complianceMode)
    }
}


// All enum types are imported from CommonTypes module

// Use Privacy module types directly

// MARK: - Job Manager
@MainActor
public class JobManager: ObservableObject {
    public static let shared = JobManager()

    @Published public var jobs: [Job] = []
    
    // Computed property to get completed jobs
    public var completedJobs: [Job] {
        jobs.filter { $0.status == .success }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private let processingQueue = DispatchQueue(label: "com.onebox.jobengine", qos: .userInitiated)
    private var currentTask: Task<Void, Never>?
    private var privacyDelegate: Privacy.PrivacyManager?

    private let persistenceURL: URL = {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("jobs.json")
    }()

    private init() {
        privacyDelegate = nil
        loadJobs()
        setupBackgroundTask()
    }
    
    public func setPrivacyDelegate(_ delegate: Privacy.PrivacyManager?) {
        privacyDelegate = delegate
    }

    // MARK: - Public Methods
    public func submitJob(_ job: Job) async {
        // Apply privacy settings from delegate if available
        var privacyJob = job
        if let delegate = privacyDelegate {
            privacyJob.settings.enableSecureVault = delegate.getSecureVaultEnabled()
            privacyJob.settings.enableZeroTrace = delegate.getZeroTraceEnabled()
            privacyJob.settings.enableBiometricLock = delegate.getBiometricLockEnabled()
            privacyJob.settings.enableStealthMode = delegate.getStealthModeEnabled()
            privacyJob.settings.complianceMode = delegate.getSelectedComplianceMode()
            
            // Authenticate if biometric lock is enabled
            if privacyJob.settings.enableBiometricLock {
                do {
                    try await delegate.performAuthenticationForProcessing()
                } catch {
                    privacyJob.status = .failed
                    privacyJob.error = error.localizedDescription
                    jobs.append(privacyJob)
                    saveJobs()
                    return
                }
            }
        }
        
        jobs.append(privacyJob)
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
        
        // Clean up secure files if secure vault was enabled
        if job.settings.enableSecureVault {
            privacyDelegate?.performSecureFilesCleanup()
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
            Task {
                processNextJob()
            }
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
            let processor = JobProcessor(privacyDelegate: privacyDelegate)
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
            
            // Clean up secure files if secure vault was enabled
            if job.settings.enableSecureVault {
                privacyDelegate?.performSecureFilesCleanup()
            }
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
        // Don't save job history if zero-trace mode is enabled
        if let delegate = privacyDelegate, delegate.getZeroTraceEnabled() {
            return
        }
        
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
    private let privacyDelegate: Privacy.PrivacyManager?
    
    init(privacyDelegate: Privacy.PrivacyManager? = nil) {
        self.privacyDelegate = privacyDelegate
    }
    
    func process(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        switch job.type {
        case .imagesToPDF:
            return try await processImagesToPDF(job: job, progressHandler: progressHandler)
        case .pdfToImages:
            return try await processPDFToImages(job: job, progressHandler: progressHandler)
        case .pdfMerge:
            return try await processPDFMerge(job: job, progressHandler: progressHandler)
        case .pdfSplit, .splitPDF:
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
            return job.outputURLs
        case .fillForm:
            return try await processFormFilling(job: job, progressHandler: progressHandler)
        case .imageResize:
            return try await processImageResize(job: job, progressHandler: progressHandler)
        case .pdfRedact:
            return try await processPDFRedact(job: job, progressHandler: progressHandler)
        }
    }

    // MARK: - Job Processing Implementations
    private func processImagesToPDF(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        
        // Secure vault URL will be implemented when needed
        
        // Use orientation directly from CommonTypes
        let orientation = job.settings.orientation
        
        let outputURL = try await processor.createPDF(
            from: job.inputs,
            pageSize: job.settings.pageSize.size,
            orientation: orientation,
            margins: job.settings.margins,
            backgroundColor: UIColor(hex: job.settings.backgroundColor) ?? .white,
            stripMetadata: job.settings.stripMetadata,
            progressHandler: progressHandler
        )
        
        return try await applyPostProcessing(job: job, urls: [outputURL])
    }

    private func processPDFToImages(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }

        let format = job.settings.imageFormat == .png ? "png" : "jpeg"
        let quality = job.settings.imageQualityPreset.compressionValue
        let pageRanges = job.settings.selectAllPages ? [] : job.settings.splitRanges
        let outputURLs = try await processor.pdfToImages(
            pdfURL,
            format: format,
            quality: quality,
            resolution: job.settings.imageResolution,
            pageRanges: pageRanges,
            progressHandler: progressHandler
        )
        return try await applyPostProcessing(job: job, urls: outputURLs)
    }

    private func processPDFMerge(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        let outputURL = try await processor.mergePDFs(job.inputs, progressHandler: progressHandler)
        return try await applyPostProcessing(job: job, urls: [outputURL])
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
        return try await applyPostProcessing(job: job, urls: outputURLs)
    }

    private func processPDFCompress(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }

        // Use compression quality directly from CommonTypes
        let quality = job.settings.compressionQuality
        
        let outputURL = try await processor.compressPDF(
            pdfURL,
            quality: quality,
            targetSizeMB: job.settings.targetSizeMB,
            progressHandler: progressHandler
        )
        return try await applyPostProcessing(job: job, urls: [outputURL])
    }

    private func processPDFWatermark(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }
        // Use watermark position directly from CommonTypes
        let watermarkPos = job.settings.watermarkPosition
        
        let outputURL = try await processor.watermarkPDF(
            pdfURL,
            text: job.settings.watermarkText,
            position: watermarkPos,
            opacity: job.settings.watermarkOpacity,
            size: job.settings.watermarkSize,
            tileDensity: job.settings.watermarkTileDensity,
            progressHandler: progressHandler
        )
        return try await applyPostProcessing(job: job, urls: [outputURL])
    }

    private func processPDFSign(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }
        
        // Validate that we have a signature before processing
        guard (job.settings.signatureText != nil && !job.settings.signatureText!.isEmpty) || 
              job.settings.signatureImageData != nil else {
            throw JobError.processingFailed("Please provide a signature. Either enter text or draw a signature.")
        }
        
        // Use signature position directly from CommonTypes
        let signaturePos = job.settings.signaturePosition
        
        // Convert image data to UIImage if present
        let signatureImage: UIImage? = {
            if let imageData = job.settings.signatureImageData {
                guard let image = UIImage(data: imageData) else {
                    // Invalid image data - this will be caught by signPDF, but we can provide better error here
                    return nil
                }
                return image
            }
            return nil
        }()
        
        do {
            let outputURL = try await processor.signPDF(
                pdfURL,
                text: job.settings.signatureText,
                image: signatureImage,
                position: signaturePos,
                customPosition: job.settings.signatureCustomPosition,
                targetPageIndex: job.settings.signaturePageIndex,
                opacity: job.settings.signatureOpacity,
                size: job.settings.signatureSize,
                progressHandler: progressHandler
            )
            return try await applyPostProcessing(job: job, urls: [outputURL])
        } catch let error as PDFError {
            // Convert PDFError to user-friendly JobError messages
            let userMessage: String
            switch error {
            case .invalidParameters(let message):
                userMessage = message
            case .invalidPDF(let name):
                userMessage = "The PDF file '\(name)' is invalid or corrupted. Please try a different file."
            case .invalidImage(let message):
                userMessage = "Signature image error: \(message)"
            case .contextCreationFailed:
                userMessage = "Failed to create PDF. You may be running low on storage space."
            case .writeFailed:
                // Check if it's actually a storage issue
                userMessage = "Unable to save the signed PDF. This could be due to insufficient storage space, file permissions, or a temporary system issue. Please try again or free up storage space."
            case .insufficientStorage(let neededMB):
                userMessage = String(format: "Not enough storage space. Please free up at least %.1f MB and try again.", neededMB)
            case .passwordProtected(let name):
                userMessage = "The PDF '\(name)' is password-protected. Please unlock it first before signing."
            case .corruptedPDF(let name):
                userMessage = "The PDF '\(name)' appears to be corrupted. Please try re-downloading it."
            case .fileNotFound(let name):
                userMessage = "The file '\(name)' could not be found. It may have been moved or deleted."
            case .emptyPDF(let name):
                userMessage = "The PDF '\(name)' contains no pages and cannot be signed."
            default:
                userMessage = error.localizedDescription
            }
            throw JobError.processingFailed(userMessage)
        } catch {
            // Handle any other errors
            throw JobError.processingFailed("Failed to sign PDF: \(error.localizedDescription)")
        }
    }

    private func processImageResize(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        // Validate inputs
        guard !job.inputs.isEmpty else {
            throw JobError.invalidInput
        }
        
        // Check if inputs exceed reasonable limit
        if job.inputs.count > 100 {
            throw JobError.processingFailed("Too many images selected (\(job.inputs.count)). Maximum is 100 images per batch. Please select fewer images.")
        }
        
        let processor = ImageProcessor()
        // Use image format directly from CommonTypes
        let imageFormat = job.settings.imageFormat
        
        do {
            let outputURLs = try await processor.processImages(
                job.inputs,
                format: imageFormat,
                quality: job.settings.imageQuality,
                maxDimension: job.settings.maxDimension,
                stripEXIF: job.settings.stripMetadata,
                progressHandler: progressHandler
            )
            return try await applyPostProcessing(job: job, urls: outputURLs)
        } catch let error as ImageError {
            // Convert ImageError to user-friendly messages
            let userMessage: String
            switch error {
            case .invalidImage(let name):
                userMessage = "Invalid or corrupted image: \(name). Please choose a different image."
            case .resizeFailed:
                userMessage = "Failed to resize image. The image may be too large or in an unsupported format."
            case .encodingFailed:
                userMessage = "Failed to save resized image. Please check available storage space."
            case .insufficientStorage(let neededMB):
                userMessage = "Not enough storage space. Please free up at least \(String(format: "%.1f", neededMB))MB and try again."
            case .invalidParameters(let message):
                userMessage = "Invalid settings: \(message). Please adjust your settings and try again."
            default:
                userMessage = "Failed to process images: \(error.localizedDescription)"
            }
            throw JobError.processingFailed(userMessage)
        } catch {
            // Handle other errors
            throw JobError.processingFailed("Failed to resize images: \(error.localizedDescription)")
        }
    }
    
    private func processPDFRedact(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }
        
        // For now, create a simplified redaction implementation
        // In a full implementation, this would apply actual redactions based on job.settings.redactionItems
        let outputURL = try await processor.redactPDF(
            pdfURL,
            redactionItems: job.settings.redactionItems,
            redactionColor: UIColor(hex: job.settings.redactionColor) ?? .black,
            progressHandler: progressHandler
        )
        return try await applyPostProcessing(job: job, urls: [outputURL])
    }
    
    private func processFormFilling(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }
        
        // For now, create a simplified form filling implementation
        // In a full implementation, this would apply form data and stamps to the PDF
        let outputURL = try await processor.fillFormFields(
            pdfURL,
            formData: [:], // Would come from job settings
            stamps: [], // Would come from job settings
            progressHandler: progressHandler
        )
        return try await applyPostProcessing(job: job, urls: [outputURL])
    }
    
    
    // MARK: - Privacy Post-Processing
    
    private func applyPostProcessing(job: Job, urls: [URL]) async throws -> [URL] {
        var processedURLs = urls
        
        // Apply document sanitization if enabled
        if job.settings.enableDocumentSanitization, let delegate = privacyDelegate {
            for url in processedURLs {
                _ = try await MainActor.run {
                    try delegate.performDocumentSanitization(at: url)
                }
            }
        }
        
        // Apply encryption if enabled
        if job.settings.enableEncryption, 
           let password = job.settings.encryptionPassword,
           let delegate = privacyDelegate {
            var encryptedURLs: [URL] = []
            for url in processedURLs {
                let encryptedURL = try await MainActor.run {
                    try delegate.performFileEncryption(at: url, password: password)
                }
                encryptedURLs.append(encryptedURL)
            }
            processedURLs = encryptedURLs
        }
        
        // Generate forensics report
        if let inputURL = job.inputs.first, 
           let outputURL = processedURLs.first,
           let delegate = privacyDelegate {
            _ = await MainActor.run {
                delegate.performFileForensics(inputURL: inputURL, outputURL: outputURL)
            }
        }
        
        return processedURLs
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
