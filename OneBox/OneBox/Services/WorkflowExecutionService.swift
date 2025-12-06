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

@MainActor
class WorkflowExecutionService: ObservableObject {
    static let shared = WorkflowExecutionService()
    
    @Published var currentWorkflowId: UUID?
    @Published var currentStepIndex: Int = 0
    @Published var totalSteps: Int = 0
    @Published var isRunning = false
    @Published var error: String?
    
    private init() {}
    
    func executeWorkflow(
        template: WorkflowTemplate,
        inputURLs: [URL],
        jobManager: JobManager
    ) async {
        guard !inputURLs.isEmpty else {
            self.error = "No input files provided"
            return
        }
        
        isRunning = true
        currentWorkflowId = UUID()
        totalSteps = template.steps.count
        currentStepIndex = 0
        error = nil
        
        var currentInputs = inputURLs
        
        // Create a temporary directory for workflow intermediates to keep things clean
        let workflowDir = FileManager.default.temporaryDirectory.appendingPathComponent("Workflow_\(currentWorkflowId!.uuidString)")
        try? FileManager.default.createDirectory(at: workflowDir, withIntermediateDirectories: true)
        
        do {
            for (index, step) in template.steps.enumerated() {
                currentStepIndex = index
                print("Workflow: Executing step \(index + 1)/\(template.steps.count): \(step.title)")
                
                // 1. Determine Job Type & Settings
                let (jobType, settings) = configureJobForStep(step)
                
                // 2. Create Job
                // For intermediate steps, we might want to ensure inputs are valid for the next step
                // e.g. Images -> PDF produces PDF, next step must handle PDF
                
                let job = Job(
                    type: jobType,
                    inputs: currentInputs,
                    settings: settings
                )
                
                // 3. Submit to JobManager
                await jobManager.submitJob(job)
                
                // 4. Wait for completion
                let outputURLs = try await waitForJobCompletion(jobId: job.id, jobManager: jobManager)
                
                // 5. Update inputs for next step
                currentInputs = outputURLs
                
                // 6. Clean up previous intermediate files if they were created by this workflow
                // (Skipping specific cleanup logic for now to ensure stability, 
                // but in production we'd delete intermediate files from previous steps)
            }
            
            print("Workflow: Completed successfully. Final outputs: \(currentInputs)")
            
        } catch {
            print("Workflow: Failed with error: \(error.localizedDescription)")
            self.error = error.localizedDescription
        }
        
        isRunning = false
        currentWorkflowId = nil
    }
    
    private func waitForJobCompletion(jobId: UUID, jobManager: JobManager) async throws -> [URL] {
        while true {
            guard let job = jobManager.jobs.first(where: { $0.id == jobId }) else {
                throw WorkflowError.jobLost
            }
            
            switch job.status {
            case .success:
                return job.outputURLs
            case .failed:
                throw WorkflowError.stepFailed(job.error ?? "Unknown error")
            case .pending, .running:
                try await Task.sleep(nanoseconds: 500_000_000) // 0.5s poll
            }
        }
    }
    
    private func configureJobForStep(_ step: WorkflowStep) -> (JobType, JobSettings) {
        var settings: JobSettings = JobSettings()
        let jobType: JobType

        switch step {
        case .organize:
            // Use pdfOrganize for proper page organization
            jobType = .pdfOrganize
            // In automated workflow, pass through without changes
            // User should use the interactive organizer for custom ordering

        case .compress:
            jobType = .pdfCompress
            settings.compressionQuality = .medium
            settings.targetSizeMB = nil // Auto-optimize

        case .watermark:
            jobType = .pdfWatermark
            // Use configurable watermark text from step config
            settings.watermarkText = stepConfig?.watermarkText ?? "PROCESSED"
            settings.watermarkPosition = stepConfig?.watermarkPosition ?? .center
            settings.watermarkOpacity = stepConfig?.watermarkOpacity ?? 0.3

        case .sign:
            jobType = .pdfSign
            // Use saved signature if available, otherwise use date stamp
            settings.signatureText = stepConfig?.signatureText ?? "Signed: \(DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .short))"
            settings.signaturePosition = stepConfig?.signaturePosition ?? .bottomRight

        case .merge:
            jobType = .pdfMerge

        case .split:
            jobType = .pdfSplit
            // Default: split into individual pages
            settings.splitRanges = stepConfig?.splitRanges ?? []

        case .imagesToPDF:
            jobType = .imagesToPDF
            settings.pageSize = .a4

        case .redact:
            jobType = .pdfRedact
            // Use automatic redaction with legal preset by default
            settings.redactionPreset = stepConfig?.redactionPreset ?? .legal
            settings.stripMetadata = true
            settings.enableDocumentSanitization = true

        case .addPageNumbers:
            // Page numbering uses watermark job type with special configuration
            jobType = .pdfWatermark
            settings.watermarkText = stepConfig?.pageNumberFormat ?? "Page {page} of {total}"
            settings.watermarkPosition = .bottomCenter
            settings.watermarkOpacity = 1.0
            settings.isPageNumbering = true
            // For Bates numbering in legal workflows
            settings.batesPrefix = stepConfig?.batesPrefix
            settings.batesStartNumber = stepConfig?.batesStartNumber ?? 1

        case .addDateStamp:
            // Date stamp uses watermark job type with date text
            jobType = .pdfWatermark
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            settings.watermarkText = "Processed: \(dateFormatter.string(from: Date()))"
            settings.watermarkPosition = stepConfig?.dateStampPosition ?? .topRight
            settings.watermarkOpacity = 0.8
            settings.isDateStamp = true

        case .flatten:
            // Flatten uses fillForm job type with flatten option
            jobType = .fillForm
            settings.flattenFormFields = true
            settings.flattenAnnotations = true
        }

        return (jobType, settings)
    }

    // Step configuration passed from workflow template
    private var stepConfig: StepConfiguration?

    func setStepConfiguration(_ config: StepConfiguration?) {
        self.stepConfig = config
    }
}

// MARK: - Step Configuration
struct StepConfiguration {
    // Watermark settings
    var watermarkText: String?
    var watermarkPosition: WatermarkPosition?
    var watermarkOpacity: Double?

    // Signature settings
    var signatureText: String?
    var signaturePosition: WatermarkPosition?

    // Split settings
    var splitRanges: [[Int]]?

    // Redaction settings
    var redactionPreset: WorkflowRedactionPreset?

    // Page numbering settings
    var pageNumberFormat: String?
    var batesPrefix: String?
    var batesStartNumber: Int?

    // Date stamp settings
    var dateStampPosition: WatermarkPosition?
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
