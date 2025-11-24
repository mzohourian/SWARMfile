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
            // Organization usually requires UI interaction. 
            // In an automated workflow, this might be a "pass-through" or auto-sort if implemented.
            // For now, we'll treat it as a no-op or basic merge if multiple files.
            jobType = .pdfMerge
            
        case .compress:
            jobType = .pdfCompress
            settings.compressionQuality = .medium
            settings.targetSizeMB = nil // Auto
            
        case .watermark:
            jobType = .pdfWatermark
            settings.watermarkText = "CONFIDENTIAL"
            settings.watermarkPosition = .center
            settings.watermarkOpacity = 0.3
            
        case .sign:
            jobType = .pdfSign
            // In automated flow, we can't easily prompt for signature.
            // We'll skip actual signing or use a placeholder if configured.
            // Ideally, we'd have a stored signature profile.
            // For this implementation, we'll assume a text signature.
            settings.signatureText = "Digitally Processed"
            settings.signaturePosition = .bottomRight
            
        case .merge:
            jobType = .pdfMerge
            
        case .split:
            jobType = .pdfSplit
            // Split requires ranges. Default to splitting all pages? 
            // Or maybe this step shouldn't be in a linear auto-workflow without config.
            // Let's default to no-op (pass through) or specific behavior?
            // Actually, split produces multiple files. Subsequent steps need to handle multiple files.
            // Our JobEngine handles [URL] inputs, so it's fine.
            // Default: Split into single pages
            settings.splitRanges = [] // Empty implies all pages
            
        case .imagesToPDF:
            jobType = .imagesToPDF
            settings.pageSize = .a4
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
