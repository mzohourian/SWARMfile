//
//  WorkflowExecutionService.swift
//  OneBox
//
//  Executes multi-step workflows by chaining jobs together
//

import Foundation
import JobEngine
import CommonTypes
import UIKit // For UIImage if needed

// Import the ConfiguredStepData and WorkflowStepConfig types
// These are defined in WorkflowConciergeView.swift

@MainActor
class WorkflowExecutionService: ObservableObject {
    static let shared = WorkflowExecutionService()

    @Published var currentWorkflowId: UUID?
    @Published var currentStepIndex: Int = 0
    @Published var totalSteps: Int = 0
    @Published var isRunning = false
    @Published var error: String?

    private init() {}

    /// Execute a workflow with user-configured step settings
    func executeConfiguredWorkflow(
        name: String,
        configuredSteps: [ConfiguredStepData],
        inputURLs: [URL],
        jobManager: JobManager
    ) async {
        guard !inputURLs.isEmpty else {
            self.error = "No input files provided"
            return
        }

        guard !configuredSteps.isEmpty else {
            self.error = "No workflow steps configured"
            return
        }

        isRunning = true
        currentWorkflowId = UUID()
        totalSteps = configuredSteps.count
        currentStepIndex = 0
        error = nil

        // Create a temporary directory for workflow intermediates
        let workflowDir = FileManager.default.temporaryDirectory.appendingPathComponent("Workflow_\(currentWorkflowId!.uuidString)")
        try? FileManager.default.createDirectory(at: workflowDir, withIntermediateDirectories: true)

        // Copy security-scoped input files to temp directory for reliable access
        var currentInputs: [URL] = []
        for inputURL in inputURLs {
            let fileName = inputURL.lastPathComponent
            let tempURL = workflowDir.appendingPathComponent(fileName)

            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: inputURL, to: tempURL)
                currentInputs.append(tempURL)
                print("Workflow: Copied input file to: \(tempURL.path)")
            } catch {
                print("Workflow: Failed to copy input file \(inputURL.lastPathComponent): \(error.localizedDescription)")
                if FileManager.default.fileExists(atPath: inputURL.path) {
                    currentInputs.append(inputURL)
                }
            }
        }

        guard !currentInputs.isEmpty else {
            self.error = "Failed to prepare input files for processing"
            isRunning = false
            currentWorkflowId = nil
            return
        }

        do {
            for (index, configuredStep) in configuredSteps.enumerated() {
                currentStepIndex = index
                print("Workflow: Executing step \(index + 1)/\(configuredSteps.count): \(configuredStep.step.title)")

                // Verify input files exist
                let validInputs = currentInputs.filter { FileManager.default.fileExists(atPath: $0.path) }

                if validInputs.isEmpty {
                    print("Workflow: No valid input files for step \(index + 1)")
                    throw WorkflowError.stepFailed("No valid input files available for \(configuredStep.step.title)")
                }

                print("Workflow: Processing \(validInputs.count) file(s)")

                // Configure job using user's saved settings
                let (jobType, settings) = configureJobWithUserSettings(
                    step: configuredStep.step,
                    config: configuredStep.config
                )

                let job = Job(
                    type: jobType,
                    inputs: validInputs,
                    settings: settings
                )

                await jobManager.submitJob(job)
                let outputURLs = try await waitForJobCompletion(jobId: job.id, jobManager: jobManager)
                currentInputs = outputURLs
            }

            print("Workflow: Completed successfully. Final outputs: \(currentInputs)")

        } catch {
            print("Workflow: Failed with error: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }

        isRunning = false
        currentWorkflowId = nil
    }

    /// Legacy method for backwards compatibility
    func executeWorkflow(
        template: WorkflowTemplate,
        inputURLs: [URL],
        jobManager: JobManager
    ) async {
        // Convert to configured steps with defaults and execute
        let configuredSteps = template.steps.map { step in
            ConfiguredStepData(step: step, config: WorkflowStepConfig.defaultConfig(for: step))
        }
        await executeConfiguredWorkflow(
            name: template.title,
            configuredSteps: configuredSteps,
            inputURLs: inputURLs,
            jobManager: jobManager
        )
    }
    
    private func waitForJobCompletion(jobId: UUID, jobManager: JobManager) async throws -> [URL] {
        while true {
            guard let job = jobManager.jobs.first(where: { $0.id == jobId }) else {
                throw WorkflowError.jobLost
            }

            switch job.status {
            case .success:
                // Validate output URLs exist before returning
                let validURLs = job.outputURLs.filter { url in
                    FileManager.default.fileExists(atPath: url.path)
                }

                if validURLs.isEmpty && !job.outputURLs.isEmpty {
                    print("Workflow: Warning - output files don't exist at expected paths")
                    print("Workflow: Expected outputs: \(job.outputURLs)")
                    throw WorkflowError.stepFailed("Output files were not created properly")
                }

                if validURLs.isEmpty {
                    throw WorkflowError.stepFailed("No output files were produced")
                }

                print("Workflow: Step completed with \(validURLs.count) output file(s)")
                return validURLs

            case .failed:
                throw WorkflowError.stepFailed(job.error ?? "Unknown error")

            case .pending, .running:
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1s poll (was 0.5s)
            }
        }
    }
    
    /// Configure job settings based on user's saved configuration
    private func configureJobWithUserSettings(step: WorkflowStep, config: WorkflowStepConfig) -> (JobType, JobSettings) {
        var settings = JobSettings()
        let jobType: JobType

        switch step {
        case .organize:
            // Organize step should not be in configured workflows (requires interactive UI)
            // But handle it gracefully by passing through
            jobType = .pdfOrganize

        case .compress:
            jobType = .pdfCompress
            // Convert string to enum
            settings.compressionQuality = CompressionQuality(rawValue: config.compressionQuality) ?? .medium
            settings.targetSizeMB = nil // Auto-optimize

        case .watermark:
            jobType = .pdfWatermark
            settings.watermarkText = config.watermarkText
            settings.watermarkPosition = WatermarkPosition(rawValue: config.watermarkPosition) ?? .center
            settings.watermarkOpacity = config.watermarkOpacity

        case .sign:
            jobType = .pdfSign
            // Use saved signature position
            settings.signaturePosition = WatermarkPosition(rawValue: config.signaturePosition) ?? .bottomRight

            // Priority: saved signature image > custom text > auto-generated text
            var hasSignature = false

            // Try to use saved signature image first
            if config.useStoredSignature {
                if let signatureData = SignatureManager.shared.getSavedSignatureImage() {
                    settings.signatureImageData = signatureData
                    hasSignature = true
                    print("Workflow: Using saved signature image")
                }
            }

            // If no saved signature, try custom text
            if !hasSignature && !config.signatureText.isEmpty {
                settings.signatureText = config.signatureText
                hasSignature = true
                print("Workflow: Using custom signature text: \(config.signatureText)")
            }

            // Always ensure a fallback signature text exists
            if !hasSignature {
                let dateStr = DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short)
                settings.signatureText = "Signed: \(dateStr)"
                print("Workflow: Using fallback signature text")
            }

        case .merge:
            jobType = .pdfMerge

        case .split:
            jobType = .pdfSplit
            // Default: split into individual pages
            settings.splitRanges = []

        case .imagesToPDF:
            jobType = .imagesToPDF
            settings.pageSize = .a4

        case .redact:
            jobType = .pdfRedact
            // Convert string preset to enum
            settings.redactionPreset = WorkflowRedactionPreset(rawValue: config.redactionPreset) ?? .legal
            settings.stripMetadata = true
            settings.enableDocumentSanitization = true

        case .addPageNumbers:
            jobType = .pdfWatermark
            settings.watermarkText = config.pageNumberFormat
            settings.watermarkPosition = WatermarkPosition(rawValue: config.pageNumberPosition) ?? .bottomCenter
            settings.watermarkOpacity = 1.0
            settings.isPageNumbering = true
            // For Bates numbering
            if !config.batesPrefix.isEmpty {
                settings.batesPrefix = config.batesPrefix
            }
            settings.batesStartNumber = config.batesStartNumber

        case .addDateStamp:
            jobType = .pdfWatermark
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            settings.watermarkText = "Processed: \(dateFormatter.string(from: Date()))"
            settings.watermarkPosition = WatermarkPosition(rawValue: config.dateStampPosition) ?? .topRight
            settings.watermarkOpacity = 0.8
            settings.isDateStamp = true

        case .flatten:
            jobType = .fillForm
            settings.flattenFormFields = true
            settings.flattenAnnotations = true
        }

        return (jobType, settings)
    }
}

enum WorkflowError: LocalizedError {
    case jobLost
    case stepFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .jobLost: return "The job was lost during processing."
        case .stepFailed(let msg): return "Workflow step failed: \(msg)"
        }
    }
}
