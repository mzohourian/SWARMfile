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

// MARK: - Signature Config Data (Codable version for JobSettings)
public struct SignatureConfigData: Codable {
    public let pageIndex: Int
    public let positionX: Double
    public let positionY: Double
    public let size: Double
    public let text: String?
    public let imageData: Data?
    public let opacity: Double

    public init(pageIndex: Int, position: CGPoint, size: Double, text: String? = nil, imageData: Data? = nil, opacity: Double = 1.0) {
        self.pageIndex = pageIndex
        self.positionX = position.x
        self.positionY = position.y
        self.size = size
        self.text = text
        self.imageData = imageData
        self.opacity = opacity
    }

    public var position: CGPoint {
        CGPoint(x: positionX, y: positionY)
    }

    // Convert to CorePDF SignatureConfig
    public func toSignatureConfig() -> SignatureConfig {
        let image: UIImage? = imageData != nil ? UIImage(data: imageData!) : nil
        return SignatureConfig(
            pageIndex: pageIndex,
            position: position,
            size: size,
            text: text,
            image: image,
            opacity: opacity
        )
    }
}

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

// MARK: - Workflow Redaction Preset
public enum WorkflowRedactionPreset: String, Codable, CaseIterable {
    case legal      // SSN, dates, names, addresses, case numbers
    case finance    // Account numbers, amounts, SSN
    case hr         // SSN, DOB, salary, addresses
    case medical    // PHI, patient IDs, dates
    case custom     // User-defined patterns
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

    // Multiple Signatures Support
    public var signatureConfigs: [SignatureConfigData] = []

    // PDF Redaction Settings
    public var redactionItems: [String] = [] // Text patterns to redact
    public var redactionMode: String = "automatic" // automatic, manual, combined
    public var redactionColor: String = "#000000" // Color of redaction boxes
    public var redactionPreset: WorkflowRedactionPreset = .custom // For workflow automation

    // Page Numbering / Bates Stamping Settings
    public var isPageNumbering: Bool = false
    public var batesPrefix: String?
    public var batesStartNumber: Int = 1

    // Date Stamp Settings
    public var isDateStamp: Bool = false

    // Form Flattening Settings
    public var flattenFormFields: Bool = false
    public var flattenAnnotations: Bool = false
    
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
        case signatureConfigs
        case redactionItems, redactionMode, redactionColor, redactionPreset
        case isPageNumbering, batesPrefix, batesStartNumber
        case isDateStamp
        case flattenFormFields, flattenAnnotations
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
        signatureConfigs = try container.decodeIfPresent([SignatureConfigData].self, forKey: .signatureConfigs) ?? []

        redactionItems = try container.decodeIfPresent([String].self, forKey: .redactionItems) ?? []
        redactionMode = try container.decodeIfPresent(String.self, forKey: .redactionMode) ?? "automatic"
        redactionColor = try container.decodeIfPresent(String.self, forKey: .redactionColor) ?? "#000000"
        redactionPreset = try container.decodeIfPresent(WorkflowRedactionPreset.self, forKey: .redactionPreset) ?? .custom

        isPageNumbering = try container.decodeIfPresent(Bool.self, forKey: .isPageNumbering) ?? false
        batesPrefix = try container.decodeIfPresent(String.self, forKey: .batesPrefix)
        batesStartNumber = try container.decodeIfPresent(Int.self, forKey: .batesStartNumber) ?? 1

        isDateStamp = try container.decodeIfPresent(Bool.self, forKey: .isDateStamp) ?? false

        flattenFormFields = try container.decodeIfPresent(Bool.self, forKey: .flattenFormFields) ?? false
        flattenAnnotations = try container.decodeIfPresent(Bool.self, forKey: .flattenAnnotations) ?? false
        
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
        try container.encode(signatureConfigs, forKey: .signatureConfigs)

        try container.encode(redactionItems, forKey: .redactionItems)
        try container.encode(redactionMode, forKey: .redactionMode)
        try container.encode(redactionColor, forKey: .redactionColor)
        try container.encode(redactionPreset, forKey: .redactionPreset)

        try container.encode(isPageNumbering, forKey: .isPageNumbering)
        try container.encodeIfPresent(batesPrefix, forKey: .batesPrefix)
        try container.encode(batesStartNumber, forKey: .batesStartNumber)

        try container.encode(isDateStamp, forKey: .isDateStamp)

        try container.encode(flattenFormFields, forKey: .flattenFormFields)
        try container.encode(flattenAnnotations, forKey: .flattenAnnotations)

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

            // Save output files to Documents/Exports for persistence
            // Files in temp directory get cleaned up by iOS automatically
            let persistedURLs = saveOutputFilesToDocuments(outputURLs, jobType: job.type)

            // IMPORTANT: Set all data BEFORE setting status to .success
            // Observers poll for status changes and read outputURLs immediately
            // Setting status last prevents race condition where URLs are empty
            jobs[index].outputURLs = persistedURLs
            jobs[index].progress = 1.0
            jobs[index].completedAt = Date()
            jobs[index].status = .success  // Set LAST so observers see complete data

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

        // Reconstruct valid URLs for output files
        // iOS can change the app's sandbox path between launches, invalidating stored absolute URLs
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exportsDir = documentsURL.appendingPathComponent("Exports")

        jobs = loadedJobs.map { job in
            var updatedJob = job
            updatedJob.outputURLs = job.outputURLs.compactMap { storedURL in
                let storedPath = storedURL.path
                let filename = storedURL.lastPathComponent

                // Check if file exists at stored path first (might still be valid)
                if fileManager.fileExists(atPath: storedPath) {
                    // Verify it has content
                    if let attrs = try? fileManager.attributesOfItem(atPath: storedPath),
                       let size = attrs[.size] as? Int64, size > 0 {
                        return storedURL
                    }
                }

                // Try to reconstruct URL using current Documents directory
                // Handle both /var/mobile/... and /private/var/mobile/... path formats
                let pathPatterns = ["Documents/Exports/", "Documents/", "/Exports/"]
                for pattern in pathPatterns {
                    if let range = storedPath.range(of: pattern) {
                        let relativePath = String(storedPath[range.upperBound...])
                        let reconstructedURL = exportsDir.appendingPathComponent(relativePath)
                        if fileManager.fileExists(atPath: reconstructedURL.path) {
                            print("✅ JobEngine: Reconstructed valid URL: \(reconstructedURL.lastPathComponent)")
                            return reconstructedURL
                        }
                    }
                }

                // Also try with just the filename in Exports directory
                let exportsURL = exportsDir.appendingPathComponent(filename)
                if fileManager.fileExists(atPath: exportsURL.path) {
                    // Verify it has content
                    if let attrs = try? fileManager.attributesOfItem(atPath: exportsURL.path),
                       let size = attrs[.size] as? Int64, size > 0 {
                        print("✅ JobEngine: Found file in Exports: \(filename)")
                        return exportsURL
                    }
                }

                // Last resort: Search for file by name pattern (handles renamed files)
                // Look for files that match the pattern: jobprefix_date_index.ext
                if let files = try? fileManager.contentsOfDirectory(at: exportsDir, includingPropertiesForKeys: nil) {
                    // Try to find a file with same extension that might be a match
                    let ext = storedURL.pathExtension
                    for fileURL in files where fileURL.pathExtension == ext {
                        // Return first match for same extension (simple heuristic)
                        // This helps recover files that were saved but with different names
                        if fileManager.fileExists(atPath: fileURL.path) {
                            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
                               let size = attrs[.size] as? Int64, size > 0 {
                                print("✅ JobEngine: Found potential match by extension: \(fileURL.lastPathComponent)")
                                return fileURL
                            }
                        }
                    }
                }

                print("⚠️ JobEngine: Could not find file: \(filename)")
                return nil
            }
            return updatedJob
        }

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

    /// Saves output files from temp directory to Documents/Exports for persistence
    /// Files in temp directory get cleaned up by iOS, so we need to copy them
    /// CRITICAL: This function must verify files are actually saved - never return URLs to non-existent files
    private func saveOutputFilesToDocuments(_ tempURLs: [URL], jobType: JobType) -> [URL] {
        let fileManager = FileManager.default

        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ JobEngine: Could not get Documents directory")
            return []  // Return empty rather than temp URLs that will be deleted
        }

        let exportsURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)

        // Create Exports directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ JobEngine: Failed to create Exports directory: \(error)")
            return []  // Return empty rather than temp URLs
        }

        var persistedURLs: [URL] = []

        // Create timestamp using a format that's safe for filenames (no locale-specific characters)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let jobPrefix = jobType.displayName.lowercased()
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "&", with: "and")
        let hasMultipleFiles = tempURLs.count > 1

        for (index, tempURL) in tempURLs.enumerated() {
            // Start security-scoped access if needed (for files from document picker)
            let startedAccessing = tempURL.startAccessingSecurityScopedResource()
            defer {
                if startedAccessing {
                    tempURL.stopAccessingSecurityScopedResource()
                }
            }

            // Check if file exists at source
            guard fileManager.fileExists(atPath: tempURL.path) else {
                print("⚠️ JobEngine: Temp file doesn't exist: \(tempURL.path)")
                continue
            }

            // Check if file is already in Documents/Exports (use standardized paths for comparison)
            let standardizedTempPath = (tempURL.path as NSString).standardizingPath
            let standardizedDocsPath = (documentsURL.path as NSString).standardizingPath
            if standardizedTempPath.hasPrefix(standardizedDocsPath) {
                // Verify file actually exists at this location
                if fileManager.fileExists(atPath: tempURL.path) {
                    print("📁 JobEngine: File already in Documents, verified: \(tempURL.lastPathComponent)")
                    persistedURLs.append(tempURL)
                } else {
                    print("⚠️ JobEngine: File claimed to be in Documents but doesn't exist: \(tempURL.path)")
                }
                continue
            }

            // Create clean filename with job type, timestamp, and index (for multiple files)
            let ext = tempURL.pathExtension.isEmpty ? "pdf" : tempURL.pathExtension
            let newFilename: String
            if hasMultipleFiles {
                // Include 1-based index for multiple files (e.g., split_pdf_2024-12-21_14-30-00_1.pdf)
                newFilename = "\(jobPrefix)_\(timestamp)_\(index + 1).\(ext)"
            } else {
                newFilename = "\(jobPrefix)_\(timestamp).\(ext)"
            }
            let destinationURL = exportsURL.appendingPathComponent(newFilename)

            var copySucceeded = false

            // Attempt 1: Direct copy
            do {
                // Remove existing file if present
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }

                // Copy file to persistent location
                try fileManager.copyItem(at: tempURL, to: destinationURL)

                // CRITICAL: Verify the copy actually succeeded
                if fileManager.fileExists(atPath: destinationURL.path) {
                    // Also verify file has content
                    if let attrs = try? fileManager.attributesOfItem(atPath: destinationURL.path),
                       let size = attrs[.size] as? Int64, size > 0 {
                        print("✅ JobEngine: Saved and verified file: \(destinationURL.lastPathComponent) (\(size) bytes)")
                        persistedURLs.append(destinationURL)
                        copySucceeded = true
                    } else {
                        print("⚠️ JobEngine: File exists but is empty or unreadable: \(destinationURL.path)")
                        try? fileManager.removeItem(at: destinationURL)
                    }
                } else {
                    print("⚠️ JobEngine: Copy reported success but file doesn't exist at destination")
                }
            } catch {
                print("❌ JobEngine: Failed to copy file (attempt 1): \(error.localizedDescription)")
            }

            // Attempt 2: If first attempt failed, try reading data and writing
            if !copySucceeded {
                do {
                    let data = try Data(contentsOf: tempURL)

                    // Create a new filename with UUID to avoid conflicts
                    let fallbackFilename = "\(jobPrefix)_\(UUID().uuidString.prefix(8)).\(ext)"
                    let fallbackURL = exportsURL.appendingPathComponent(fallbackFilename)

                    try data.write(to: fallbackURL, options: .atomic)

                    // Verify the write
                    if fileManager.fileExists(atPath: fallbackURL.path) {
                        if let attrs = try? fileManager.attributesOfItem(atPath: fallbackURL.path),
                           let size = attrs[.size] as? Int64, size > 0 {
                            print("✅ JobEngine: Saved via data write (attempt 2): \(fallbackURL.lastPathComponent)")
                            persistedURLs.append(fallbackURL)
                            copySucceeded = true
                        }
                    }
                } catch {
                    print("❌ JobEngine: Failed to save file (attempt 2): \(error.localizedDescription)")
                }
            }

            // If both attempts failed, DO NOT add temp URL - it will be deleted by iOS
            if !copySucceeded {
                print("❌ JobEngine: CRITICAL - Could not persist file: \(tempURL.lastPathComponent)")
            }
        }

        // Log summary
        print("📊 JobEngine: Persisted \(persistedURLs.count)/\(tempURLs.count) files to Documents/Exports")

        return persistedURLs
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
            // Page Organizer is normally handled through interactive UI (PageOrganizerView)
            // In automated workflows, copy input files to output location (pass-through)
            // since page organization requires user interaction
            progressHandler(0.5)

            if !job.outputURLs.isEmpty {
                return job.outputURLs // Use existing outputs if available (from interactive UI)
            }

            // Copy inputs to temp output files to ensure they're properly passed through
            var outputURLs: [URL] = []
            let tempDir = FileManager.default.temporaryDirectory
            for inputURL in job.inputs {
                let outputURL = tempDir.appendingPathComponent("organized_\(UUID().uuidString)_\(inputURL.lastPathComponent)")
                do {
                    if FileManager.default.fileExists(atPath: outputURL.path) {
                        try FileManager.default.removeItem(at: outputURL)
                    }
                    try FileManager.default.copyItem(at: inputURL, to: outputURL)
                    outputURLs.append(outputURL)
                } catch {
                    print("❌ pdfOrganize: Failed to copy \(inputURL.lastPathComponent): \(error)")
                    // Use original as fallback
                    outputURLs.append(inputURL)
                }
            }

            progressHandler(1.0)
            return outputURLs.isEmpty ? job.inputs : outputURLs

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

        // Start security-scoped resource access (required for files from document picker/iCloud)
        let startedAccessing = pdfURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccessing {
                pdfURL.stopAccessingSecurityScopedResource()
            }
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

        // Use smaller size for page numbering and date stamps
        var effectiveSize = job.settings.watermarkSize
        if job.settings.isPageNumbering || job.settings.isDateStamp {
            effectiveSize = 0.03 // Small, unobtrusive size for page numbers/date stamps
        }

        let outputURL = try await processor.watermarkPDF(
            pdfURL,
            text: job.settings.watermarkText,
            position: watermarkPos,
            opacity: job.settings.watermarkOpacity,
            size: effectiveSize,
            tileDensity: job.settings.watermarkTileDensity,
            isPageNumbering: job.settings.isPageNumbering,
            progressHandler: progressHandler
        )
        return try await applyPostProcessing(job: job, urls: [outputURL])
    }

    private func processPDFSign(job: Job, progressHandler: @escaping (Double) -> Void) async throws -> [URL] {
        let processor = PDFProcessor()
        guard let pdfURL = job.inputs.first else {
            throw JobError.invalidInput
        }

        // Use multi-signature method if signatureConfigs are provided
        if !job.settings.signatureConfigs.isEmpty {
            do {
                let signatures = job.settings.signatureConfigs.map { $0.toSignatureConfig() }
                let outputURL = try await processor.signPDFWithMultipleSignatures(
                    pdfURL,
                    signatures: signatures,
                    progressHandler: progressHandler
                )
                return try await applyPostProcessing(job: job, urls: [outputURL])
            } catch let error as PDFError {
                throw JobError.processingFailed(error.localizedDescription)
            } catch {
                throw JobError.processingFailed("Failed to sign PDF: \(error.localizedDescription)")
            }
        }

        // Fallback to single signature method for backwards compatibility
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
