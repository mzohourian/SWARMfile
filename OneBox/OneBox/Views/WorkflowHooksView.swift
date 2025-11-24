//
//  WorkflowHooksView.swift
//  OneBox
//
//  Workflow hooks for bundling file operations (100% on-device)
//

import SwiftUI
import UIComponents
import JobEngine

struct WorkflowHooksView: View {
    let selectedURLs: [URL]
    let tool: ToolType
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    @State private var workflowSteps: [WorkflowStep] = []
    @State private var workflowName = ""
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Header
                        workflowHeader
                        
                        // Selected files summary
                        selectedFilesSummary
                        
                        // Suggested workflow steps
                        suggestedStepsSection
                        
                        // Workflow builder
                        workflowBuilderSection
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Create Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createWorkflow()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(workflowName.isEmpty || workflowSteps.isEmpty)
                }
            }
        }
    }
    
    private var workflowHeader: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Bundle Operations")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Create a multi-step workflow from your selected files")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                TextField("Workflow Name", text: $workflowName)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                    .padding(OneBoxSpacing.small)
                    .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                    .cornerRadius(OneBoxRadius.small)
            }
        }
    }
    
    private var selectedFilesSummary: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                Text("Selected Files")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Text("\(selectedURLs.count) file\(selectedURLs.count == 1 ? "" : "s")")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
            }
        }
    }
    
    private var suggestedStepsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Suggested Steps")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
            
            // Auto-suggest workflow based on tool and file types
            let suggestedSteps = suggestWorkflowSteps()
            
            ForEach(suggestedSteps, id: \.id) { step in
                suggestedStepCard(step)
            }
        }
    }
    
    private func suggestedStepCard(_ step: WorkflowStep) -> some View {
        Button(action: {
            if !workflowSteps.contains(step) {
                workflowSteps.append(step)
            }
        }) {
            HStack {
                Image(systemName: step.icon)
                    .foregroundColor(OneBoxColors.primaryGold)
                    .frame(width: 24)
                
                Text(step.title)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                if workflowSteps.contains(step) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OneBoxColors.secureGreen)
                }
            }
            .padding(OneBoxSpacing.small)
            .background(OneBoxColors.surfaceGraphite.opacity(0.3))
            .cornerRadius(OneBoxRadius.small)
        }
    }
    
    private var workflowBuilderSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Workflow Steps")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
            
            ForEach(Array(workflowSteps.enumerated()), id: \.offset) { index, step in
                workflowStepRow(step, index: index)
            }
        }
    }
    
    private func workflowStepRow(_ step: WorkflowStep, index: Int) -> some View {
        HStack {
            Text("\(index + 1)")
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 24)
            
            Text(step.title)
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
            
            Button(action: {
                workflowSteps.remove(at: index)
            }) {
                Image(systemName: "trash")
                    .foregroundColor(OneBoxColors.criticalRed)
            }
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.tertiaryGraphite)
        .cornerRadius(OneBoxRadius.small)
    }
    
    private func suggestWorkflowSteps() -> [WorkflowStep] {
        // Suggest workflow steps based on tool and file types (on-device logic)
        var steps: [WorkflowStep] = []
        
        // Add current tool as first step
        switch tool {
        case .imagesToPDF:
            steps.append(.imagesToPDF)
            steps.append(.compress) // Suggest compression after conversion
        case .pdfCompress:
            steps.append(.compress)
        case .pdfMerge:
            steps.append(.merge)
        case .pdfSplit:
            steps.append(.split)
        default:
            break
        }
        
        // Analyze file types to suggest additional steps
        let hasPDFs = selectedURLs.contains { $0.pathExtension.lowercased() == "pdf" }
        let _ = selectedURLs.contains { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
        
        if hasPDFs && !steps.contains(.compress) {
            steps.append(.compress)
        }
        
        if hasPDFs && steps.count < 3 {
            steps.append(.watermark) // Suggest watermarking
        }
        
        return steps
    }
    
    private func createWorkflow() {
        // Save workflow to UserDefaults (on-device only)
        let defaults = UserDefaults.standard
        var savedWorkflows: [CustomWorkflowData] = []
        
        if let data = defaults.data(forKey: "saved_custom_workflows"),
           let decoded = try? JSONDecoder().decode([CustomWorkflowData].self, from: data) {
            savedWorkflows = decoded
        }
        
        let newWorkflow = CustomWorkflowData(
            id: UUID(),
            name: workflowName.isEmpty ? "Workflow from \(tool.displayName)" : workflowName,
            steps: workflowSteps,
            lastUsed: Date()
        )
        
        savedWorkflows.append(newWorkflow)
        
        if let encoded = try? JSONEncoder().encode(savedWorkflows) {
            defaults.set(encoded, forKey: "saved_custom_workflows")
        }
        
        HapticManager.shared.notification(.success)
        dismiss()
    }
}

