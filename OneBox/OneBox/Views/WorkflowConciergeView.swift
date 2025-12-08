//
//  WorkflowConciergeView.swift
//  OneBox
//
//  Workflow Concierge: AI-powered automation for multi-step document workflows
//

import SwiftUI
import UIComponents
import JobEngine
import CorePDF

struct WorkflowConciergeView: View {
    @EnvironmentObject var jobManager: JobManager
    @EnvironmentObject var paymentsManager: PaymentsManager
    @State private var availableWorkflows: [WorkflowTemplate] = []
    @State private var customWorkflows: [CustomWorkflow] = []
    @State private var suggestedWorkflows: [WorkflowSuggestion] = []
    @State private var isCreatingWorkflow = false
    @State private var selectedTemplate: WorkflowTemplate?

    // Workflow Execution
    @State private var showingFilePicker = false
    @State private var activeTemplate: WorkflowTemplate?
    @State private var activeConfiguredSteps: [ConfiguredStepData] = []
    @State private var isWorkflowRunning = false
    @State private var workflowError: String?
    @State private var currentStepIndex = 0
    @State private var totalSteps = 0

    // Interactive workflow state - for pausing workflow to show existing views
    @State private var workflowInputURLs: [URL] = [] // Current input files for workflow
    @State private var workflowRemainingSteps: [ConfiguredStepData] = [] // Steps left to execute
    @State private var showingPageOrganizer = false // For interactive organize step
    @State private var showingInteractiveSign = false // For interactive sign step
    @State private var showingRedactionView = false // For interactive redact step
    @State private var interactiveCurrentURL: URL? // URL being processed by interactive view

    // Success state
    @State private var workflowSucceeded = false
    @State private var completedOutputURLs: [URL] = []
    @State private var showingShareSheet = false

    // Delete workflow
    @State private var showingDeleteConfirmation = false
    @State private var workflowToDelete: CustomWorkflow?

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Hero Section
                        heroSection
                        
                        // Suggested Workflows (AI-powered)
                        if !suggestedWorkflows.isEmpty {
                            suggestedWorkflowsSection
                        }
                        
                        // Quick Templates
                        templatesSection
                        
                        // Custom Workflows
                        customWorkflowsSection
                        
                        // Create New Workflow
                        createWorkflowSection
                    }
                    .padding(OneBoxSpacing.medium)
                }
                
                // Progress Overlay
                if isWorkflowRunning {
                    workflowProgressOverlay
                }
            }
            .navigationTitle("Workflow Concierge")
            .navigationBarTitleDisplayMode(.inline)
            .background(OneBoxColors.primaryGraphite)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SecurityBadge(style: .minimal)
                }
            }
        }
        .onAppear {
            loadWorkflowData()
        }
        .onChange(of: isCreatingWorkflow) { isCreating in
            // Reload workflows when the builder sheet is dismissed
            if !isCreating {
                loadCustomWorkflows()
            }
        }
        .sheet(isPresented: $isCreatingWorkflow) {
            WorkflowBuilderView(template: selectedTemplate)
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .image],
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
        .alert("Workflow Error", isPresented: Binding<Bool>(
            get: { workflowError != nil },
            set: { if !$0 { workflowError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = workflowError {
                Text(error)
            }
        }
        .alert("Workflow Complete", isPresented: $workflowSucceeded) {
            Button("Share Result") {
                showingShareSheet = true
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text("Your document has been processed successfully and saved to Files.")
        }
        .sheet(isPresented: $showingShareSheet) {
            if !completedOutputURLs.isEmpty {
                ShareSheet(items: completedOutputURLs)
            }
        }
        .alert("Delete Workflow", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                if let workflow = workflowToDelete {
                    deleteWorkflow(workflow)
                }
            }
            Button("Cancel", role: .cancel) {
                workflowToDelete = nil
            }
        } message: {
            if let workflow = workflowToDelete {
                Text("Are you sure you want to delete \"\(workflow.name)\"? This cannot be undone.")
            }
        }
        // Interactive Page Organizer - uses existing view
        .fullScreenCover(isPresented: $showingPageOrganizer) {
            if let url = interactiveCurrentURL {
                PageOrganizerView(pdfURL: url, workflowMode: true)
                    .environmentObject(jobManager)
                    .environmentObject(paymentsManager)
                    .onDisappear {
                        handleInteractiveStepCompleted()
                    }
            }
        }
        // Interactive Sign PDF - uses existing view
        .fullScreenCover(isPresented: $showingInteractiveSign) {
            if let url = interactiveCurrentURL {
                InteractiveSignPDFView(pdfURL: url, workflowMode: true) { job in
                    // Job submitted - will be handled by onDisappear
                }
                .environmentObject(jobManager)
                .environmentObject(paymentsManager)
                .onDisappear {
                    handleInteractiveStepCompleted()
                }
            }
        }
        // Interactive Redaction - uses existing RedactionView
        .fullScreenCover(isPresented: $showingRedactionView) {
            if let url = interactiveCurrentURL {
                RedactionView(pdfURL: url, workflowMode: true)
                    .environmentObject(jobManager)
                    .environmentObject(paymentsManager)
                    .onDisappear {
                        handleInteractiveStepCompleted()
                    }
            }
        }
    }

    // MARK: - Hero Section
    private var heroSection: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Automate Your Workflows")
                            .font(OneBoxTypography.heroTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Chain multiple operations together for seamless document processing")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "gear.badge.checkmark")
                        .font(.system(size: 40, weight: .medium))
                        .foregroundColor(OneBoxColors.primaryGold)
                }
                
                // Workflow Stats
                HStack(spacing: OneBoxSpacing.large) {
                    workflowStat("Templates", "\(availableWorkflows.count)")
                    workflowStat("Custom", "\(customWorkflows.count)")
                    workflowStat("Saved Time", "~45min")
                }
            }
        }
    }
    
    private func workflowStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Text(value)
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryGold)
            
            Text(title)
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
    
    // MARK: - Suggested Workflows Section
    private var suggestedWorkflowsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            HStack {
                Text("Suggested for You")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                Text("AI Powered")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.primaryGold)
                    .padding(.horizontal, OneBoxSpacing.tiny)
                    .padding(.vertical, 2)
                    .background(OneBoxColors.mutedGold)
                    .cornerRadius(OneBoxRadius.small)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OneBoxSpacing.medium) {
                    ForEach(suggestedWorkflows) { suggestion in
                        suggestionCard(suggestion)
                    }
                }
                .padding(.horizontal, OneBoxSpacing.medium)
            }
        }
    }
    
    private func suggestionCard(_ suggestion: WorkflowSuggestion) -> some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                HStack {
                    Image(systemName: suggestion.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(OneBoxColors.primaryGold)
                    
                    Spacer()
                    
                    Text(suggestion.confidence)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secureGreen)
                }
                
                Text(suggestion.title)
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(suggestion.description)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(2)
                
                OneBoxButton("Try Now", style: .secondary) {
                    applySuggestedWorkflow(suggestion)
                }
            }
            .frame(width: 200)
        }
    }
    
    // MARK: - Templates Section
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Quick Templates")
                .font(OneBoxTypography.sectionTitle)
                .foregroundColor(OneBoxColors.primaryText)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: OneBoxSpacing.medium) {
                ForEach(availableWorkflows) { template in
                    templateCard(template)
                }
            }
        }
    }
    
    private func templateCard(_ template: WorkflowTemplate) -> some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(template.accentColor)
                    
                    Spacer()
                    
                    if template.isPro && !paymentsManager.hasPro {
                        Image(systemName: "crown.fill")
                            .font(.system(size: 12))
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                Text(template.title)
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(template.description)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(2)
                
                // Step indicators
                HStack(spacing: OneBoxSpacing.tiny) {
                    ForEach(0..<min(template.steps.count, 4), id: \.self) { index in
                        Circle()
                            .fill(template.accentColor.opacity(0.3))
                            .frame(width: 6, height: 6)
                    }
                    
                    if template.steps.count > 4 {
                        Text("+\(template.steps.count - 4)")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                    
                    Spacer()
                    
                    Text("\(template.estimatedTime)")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                OneBoxButton("Use Template", style: .primary) {
                    useTemplate(template)
                }
            }
        }
    }
    
    // MARK: - Custom Workflows Section
    private var customWorkflowsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            HStack {
                Text("Your Workflows")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                if !customWorkflows.isEmpty {
                    Text("\(customWorkflows.count) saved")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
            }
            
            if customWorkflows.isEmpty {
                OneBoxCard(style: .standard) {
                    VStack(spacing: OneBoxSpacing.medium) {
                        Image(systemName: "plus.circle.dashed")
                            .font(.system(size: 32))
                            .foregroundColor(OneBoxColors.tertiaryText)
                        
                        Text("No Custom Workflows Yet")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        Text("Create automated workflows tailored to your specific needs")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(OneBoxSpacing.large)
                }
            } else {
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(customWorkflows) { workflow in
                        customWorkflowRow(workflow)
                    }
                }
            }
        }
    }
    
    private func customWorkflowRow(_ workflow: CustomWorkflow) -> some View {
        OneBoxCard(style: .standard) {
            HStack(spacing: OneBoxSpacing.medium) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(workflow.name)
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)

                    Text("\(workflow.steps.count) steps • Last used \(workflow.lastUsed.formatted(.relative(presentation: .named)))")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }

                Spacer()

                // Delete button
                Button {
                    workflowToDelete = workflow
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 16))
                        .foregroundColor(OneBoxColors.criticalRed)
                        .padding(OneBoxSpacing.small)
                }

                OneBoxButton("Run", icon: "play.fill", style: .secondary) {
                    runCustomWorkflow(workflow)
                }
            }
        }
    }
    
    // MARK: - Create Workflow Section
    private var createWorkflowSection: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Create Custom Workflow")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Build automated workflows that match your exact needs")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "plus.app.fill")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(OneBoxColors.primaryGold)
                }
                
                OneBoxButton("Start Building", icon: "plus", style: .security) {
                    selectedTemplate = nil
                    isCreatingWorkflow = true
                }
            }
        }
    }
    
    // MARK: - Workflow Progress Overlay
    private var workflowProgressOverlay: some View {
        ZStack {
            Color.black.opacity(0.7).ignoresSafeArea()
            
            OneBoxCard(style: .security) {
                VStack(spacing: OneBoxSpacing.large) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(OneBoxColors.primaryGold)
                    
                    VStack(spacing: OneBoxSpacing.small) {
                        Text("Running Workflow")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Step \(currentStepIndex + 1) of \(totalSteps)")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Button("Cancel") {
                        // In a real implementation, we'd support cancellation
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.criticalRed)
                    .disabled(true) // Not implemented yet
                }
                .padding(OneBoxSpacing.large)
                .frame(width: 280)
            }
        }
    }

    // MARK: - Actions
    private func loadWorkflowData() {
        // Load available workflow templates
        availableWorkflows = WorkflowTemplate.defaultTemplates
        
        // Load custom workflows
        loadCustomWorkflows()
        
        // Generate AI suggestions based on usage patterns
        generateWorkflowSuggestions()
    }
    
    private func loadCustomWorkflows() {
        // Load saved custom workflows from UserDefaults
        let defaults = UserDefaults.standard
        guard let data = defaults.data(forKey: "saved_custom_workflows"),
              let decoded = try? JSONDecoder().decode([CustomWorkflowData].self, from: data) else {
            customWorkflows = []
            return
        }

        customWorkflows = decoded.map { data in
            CustomWorkflow(
                id: data.id,
                name: data.name,
                configuredSteps: data.configuredSteps,
                lastUsed: data.lastUsed
            )
        }
    }
    
    private func saveCustomWorkflows() {
        let defaults = UserDefaults.standard
        let data = customWorkflows.map { workflow in
            CustomWorkflowData(
                id: workflow.id,
                name: workflow.name,
                configuredSteps: workflow.configuredSteps,
                lastUsed: workflow.lastUsed
            )
        }

        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: "saved_custom_workflows")
        }
    }

    private func deleteWorkflow(_ workflow: CustomWorkflow) {
        // Remove from local array
        customWorkflows.removeAll { $0.id == workflow.id }

        // Save updated list
        saveCustomWorkflows()

        // Clear the workflow to delete
        workflowToDelete = nil

        // Provide haptic feedback
        HapticManager.shared.notification(.success)
    }
    
    private func generateWorkflowSuggestions() {
        // Analyze job history to suggest workflows
        let jobHistory = jobManager.completedJobs.suffix(20)
        
        var suggestions: [WorkflowSuggestion] = []
        
        // Check for common patterns
        let hasFrequentCompressionAfterMerge = analyzePattern(jobHistory, firstType: .pdfMerge, secondType: .pdfCompress)
        if hasFrequentCompressionAfterMerge {
            suggestions.append(WorkflowSuggestion(
                title: "Merge & Compress",
                description: "You often compress after merging. Automate this workflow?",
                icon: "doc.on.doc.fill",
                confidence: "85%",
                workflow: WorkflowTemplate.mergeAndCompress
            ))
        }
        
        let hasFrequentWatermarkAfterSign = analyzePattern(jobHistory, firstType: .pdfSign, secondType: .pdfWatermark)
        if hasFrequentWatermarkAfterSign {
            suggestions.append(WorkflowSuggestion(
                title: "Sign & Watermark",
                description: "Automatically watermark documents after signing",
                icon: "signature",
                confidence: "78%",
                workflow: WorkflowTemplate.signAndWatermark
            ))
        }
        
        suggestedWorkflows = suggestions
    }
    
    private func analyzePattern(_ jobs: ArraySlice<Job>, firstType: JobType, secondType: JobType) -> Bool {
        let jobArray = Array(jobs)

        // Need at least 2 jobs to analyze patterns
        guard jobArray.count >= 2 else { return false }

        var patternCount = 0

        for i in 0..<(jobArray.count - 1) {
            if jobArray[i].type == firstType && jobArray[i + 1].type == secondType {
                let timeDiff = jobArray[i + 1].createdAt.timeIntervalSince(jobArray[i].createdAt)
                if timeDiff < 600 { // Within 10 minutes
                    patternCount += 1
                }
            }
        }
        
        return patternCount >= 2 // Pattern observed at least twice
    }
    
    private func applySuggestedWorkflow(_ suggestion: WorkflowSuggestion) {
        HapticManager.shared.impact(.medium)
        startWorkflow(suggestion.workflow)
    }
    
    private func useTemplate(_ template: WorkflowTemplate) {
        HapticManager.shared.impact(.light)
        
        if template.isPro && !paymentsManager.hasPro {
            // Show upgrade prompt - In a real app this would trigger the paywall
            // For now, we'll allow it or show a mock alert
            return
        }
        
        startWorkflow(template)
    }
    
    private func runCustomWorkflow(_ workflow: CustomWorkflow) {
        HapticManager.shared.impact(.medium)

        // Update last used date
        if let index = customWorkflows.firstIndex(where: { $0.id == workflow.id }) {
            // Create new CustomWorkflow with updated lastUsed date, preserving configurations
            customWorkflows[index] = CustomWorkflow(
                id: workflow.id,
                name: workflow.name,
                configuredSteps: workflow.configuredSteps,
                lastUsed: Date()
            )
            saveCustomWorkflows()
        }

        // Store configured steps for execution
        activeConfiguredSteps = workflow.configuredSteps

        // Create template for workflow execution (steps only, configs passed separately)
        let template = WorkflowTemplate(
            title: workflow.name,
            description: "Custom Workflow",
            icon: "gear",
            accentColor: .blue,
            steps: workflow.steps,
            estimatedTime: "Unknown",
            isPro: false
        )

        startWorkflow(template)
    }
    
    private func startWorkflow(_ template: WorkflowTemplate) {
        activeTemplate = template

        // If activeConfiguredSteps is empty (template workflow, not custom),
        // create default configurations for each step
        if activeConfiguredSteps.isEmpty {
            activeConfiguredSteps = template.steps.map { step in
                ConfiguredStepData(step: step, config: WorkflowStepConfig.defaultConfig(for: step))
            }
        }

        showingFilePicker = true
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard activeTemplate != nil else { return }

            // Copy files to temp directory for reliable access
            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("Workflow_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            var secureURLs: [URL] = []
            for url in urls {
                _ = url.startAccessingSecurityScopedResource()
                let tempURL = tempDir.appendingPathComponent(url.lastPathComponent)
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    secureURLs.append(tempURL)
                } catch {
                    secureURLs.append(url)
                }
                url.stopAccessingSecurityScopedResource()
            }

            // Initialize workflow state
            workflowInputURLs = secureURLs
            workflowRemainingSteps = activeConfiguredSteps
            activeConfiguredSteps = []
            totalSteps = workflowRemainingSteps.count
            currentStepIndex = 0
            isWorkflowRunning = true
            workflowError = nil

            // Start the workflow
            continueWorkflow()

        case .failure(let error):
            print("File selection failed: \(error.localizedDescription)")
        }
    }

    /// Continue workflow execution - handles both interactive and automated steps
    private func continueWorkflow() {
        // Check if there are more steps
        guard !workflowRemainingSteps.isEmpty else {
            // Workflow complete!
            finishWorkflow()
            return
        }

        // Get the next step
        let nextStep = workflowRemainingSteps.first!
        currentStepIndex = totalSteps - workflowRemainingSteps.count

        // Check if this is an interactive step
        if nextStep.step.isInteractive {
            // Interactive step - show the appropriate existing view
            guard let inputURL = workflowInputURLs.first else {
                workflowError = "No input file available for \(nextStep.step.title)"
                finishWorkflow()
                return
            }

            interactiveCurrentURL = inputURL

            switch nextStep.step {
            case .organize:
                showingPageOrganizer = true
            case .sign:
                showingInteractiveSign = true
            case .redact:
                showingRedactionView = true
            default:
                // Shouldn't happen, but handle gracefully
                workflowRemainingSteps.removeFirst()
                continueWorkflow()
            }
        } else {
            // Automated step - run via execution service
            runAutomatedStep(nextStep)
        }
    }

    /// Run a single automated step
    private func runAutomatedStep(_ step: ConfiguredStepData) {
        Task {
            do {
                let outputURLs = try await WorkflowExecutionService.shared.executeSingleStep(
                    step: step,
                    inputURLs: workflowInputURLs,
                    jobManager: jobManager
                )

                await MainActor.run {
                    // Update inputs for next step
                    workflowInputURLs = outputURLs
                    // Remove completed step
                    workflowRemainingSteps.removeFirst()
                    // Continue to next step
                    continueWorkflow()
                }
            } catch {
                await MainActor.run {
                    workflowError = error.localizedDescription
                    finishWorkflow()
                }
            }
        }
    }

    /// Called when an interactive view (PageOrganizer or InteractiveSign) completes
    private func handleInteractiveStepCompleted() {
        // The interactive view submitted a job - get the output
        // Look for the most recent completed job's output
        if let lastJob = jobManager.completedJobs.last,
           !lastJob.outputURLs.isEmpty {
            workflowInputURLs = lastJob.outputURLs
        }

        // Remove the completed interactive step
        if !workflowRemainingSteps.isEmpty {
            workflowRemainingSteps.removeFirst()
        }

        // Clear interactive state
        interactiveCurrentURL = nil
        showingPageOrganizer = false
        showingInteractiveSign = false
        showingRedactionView = false

        // Small delay to ensure UI updates, then continue
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.continueWorkflow()
        }
    }

    /// Finish the workflow (success or error)
    private func finishWorkflow() {
        isWorkflowRunning = false

        if workflowError == nil {
            // Success!
            completedOutputURLs = workflowInputURLs
            workflowSucceeded = true
            HapticManager.shared.notification(.success)
        }

        // Cleanup
        workflowInputURLs = []
        workflowRemainingSteps = []
        interactiveCurrentURL = nil
    }
}

// MARK: - Supporting Data Models
struct WorkflowTemplate: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let accentColor: Color
    let steps: [WorkflowStep]
    let estimatedTime: String
    let isPro: Bool
    
    static let defaultTemplates: [WorkflowTemplate] = [
        // Basic Templates (Free)
        WorkflowTemplate(
            title: "Quick Share",
            description: "Compress and watermark documents for quick sharing",
            icon: "square.and.arrow.up",
            accentColor: OneBoxColors.secureGreen,
            steps: [.compress, .watermark],
            estimatedTime: "30 sec",
            isPro: false
        ),
        WorkflowTemplate(
            title: "Image to PDF",
            description: "Convert images to PDF with compression",
            icon: "photo.on.rectangle",
            accentColor: OneBoxColors.warningAmber,
            steps: [.imagesToPDF, .compress],
            estimatedTime: "45 sec",
            isPro: false
        ),

        // Professional Templates (Pro)
        WorkflowTemplate(
            title: "Legal Discovery",
            description: "Prepare documents for legal discovery: redact PII, add Bates numbers, date stamp, and flatten",
            icon: "scale.3d",
            accentColor: OneBoxColors.primaryGold,
            steps: [.redact, .addPageNumbers, .addDateStamp, .flatten, .compress],
            estimatedTime: "5 min",
            isPro: true
        ),
        WorkflowTemplate(
            title: "Contract Execution",
            description: "Merge contract pages, flatten forms, sign, watermark with EXECUTED, and compress",
            icon: "doc.text.magnifyingglass",
            accentColor: OneBoxColors.primaryGold,
            steps: [.merge, .flatten, .sign, .watermark, .compress],
            estimatedTime: "3 min",
            isPro: true
        ),
        WorkflowTemplate(
            title: "Financial Report",
            description: "Redact account numbers, add CONFIDENTIAL watermark, date stamp, and compress",
            icon: "chart.bar.doc.horizontal",
            accentColor: OneBoxColors.secureGreen,
            steps: [.redact, .watermark, .addDateStamp, .compress],
            estimatedTime: "4 min",
            isPro: true
        ),
        WorkflowTemplate(
            title: "HR Documents",
            description: "Redact SSN/personal data, watermark INTERNAL, add page numbers, compress",
            icon: "person.text.rectangle",
            accentColor: OneBoxColors.criticalRed,
            steps: [.redact, .watermark, .addPageNumbers, .compress],
            estimatedTime: "4 min",
            isPro: true
        ),
        WorkflowTemplate(
            title: "Medical Records",
            description: "Redact sensitive data, add processing date, watermark, flatten, compress",
            icon: "cross.case",
            accentColor: OneBoxColors.warningAmber,
            steps: [.redact, .addDateStamp, .watermark, .flatten, .compress],
            estimatedTime: "5 min",
            isPro: true
        ),
        WorkflowTemplate(
            title: "Merge & Archive",
            description: "Combine documents, add page numbers, date stamp, compress for archival",
            icon: "archivebox",
            accentColor: OneBoxColors.secondaryGold,
            steps: [.merge, .addPageNumbers, .addDateStamp, .compress],
            estimatedTime: "3 min",
            isPro: true
        )
    ]
    
    static let mergeAndCompress = WorkflowTemplate(
        title: "Merge & Compress",
        description: "Combine PDFs and optimize file size",
        icon: "doc.on.doc.fill",
        accentColor: OneBoxColors.primaryGold,
        steps: [.merge, .compress],
        estimatedTime: "90 sec",
        isPro: false
    )
    
    static let signAndWatermark = WorkflowTemplate(
        title: "Sign & Watermark",
        description: "Sign documents and apply protective watermarks",
        icon: "signature",
        accentColor: OneBoxColors.secureGreen,
        steps: [.sign, .watermark],
        estimatedTime: "2 min",
        isPro: false
    )
}

struct CustomWorkflow: Identifiable {
    let id: UUID
    let name: String
    let configuredSteps: [ConfiguredStepData]
    let lastUsed: Date

    // Convenience property for step list (used in UI)
    var steps: [WorkflowStep] {
        configuredSteps.map { $0.step }
    }
}

struct WorkflowSuggestion: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let confidence: String
    let workflow: WorkflowTemplate
}

enum WorkflowStep: String, CaseIterable, Identifiable, Codable {
    case organize, compress, watermark, sign, merge, split, imagesToPDF, redact, addPageNumbers, addDateStamp, flatten

    var id: String { rawValue }

    var title: String {
        switch self {
        case .organize: return "Organize"
        case .compress: return "Compress"
        case .watermark: return "Watermark"
        case .sign: return "Sign"
        case .merge: return "Merge"
        case .split: return "Split"
        case .imagesToPDF: return "Images to PDF"
        case .redact: return "Redact"
        case .addPageNumbers: return "Add Page Numbers"
        case .addDateStamp: return "Add Date Stamp"
        case .flatten: return "Flatten Forms"
        }
    }

    var icon: String {
        switch self {
        case .organize: return "square.grid.2x2"
        case .compress: return "arrow.down.circle"
        case .watermark: return "drop.fill"
        case .sign: return "signature"
        case .merge: return "doc.on.doc"
        case .split: return "scissors"
        case .imagesToPDF: return "photo.on.rectangle"
        case .redact: return "eye.slash.fill"
        case .addPageNumbers: return "number"
        case .addDateStamp: return "calendar.badge.clock"
        case .flatten: return "square.on.square.dashed"
        }
    }

    var description: String {
        switch self {
        case .organize: return "Reorder, rotate, or remove pages"
        case .compress: return "Reduce file size while maintaining quality"
        case .watermark: return "Add text or image watermarks"
        case .sign: return "Add digital signature"
        case .merge: return "Combine multiple PDFs into one"
        case .split: return "Split PDF into separate files"
        case .imagesToPDF: return "Convert images to PDF document"
        case .redact: return "Permanently remove sensitive information"
        case .addPageNumbers: return "Add page numbers (Bates numbering for legal)"
        case .addDateStamp: return "Add processing date to documents"
        case .flatten: return "Flatten form fields and annotations"
        }
    }

    /// Whether this step requires interactive user input (uses existing app views)
    var isInteractive: Bool {
        switch self {
        case .organize, .sign, .redact:
            return true // Uses existing interactive views
        default:
            return false // Automated with configured settings
        }
    }
}

// MARK: - Workflow Builder View
struct WorkflowBuilderView: View {
    let template: WorkflowTemplate?
    @Environment(\.dismiss) var dismiss
    @State private var workflowName = ""
    @State private var configuredSteps: [ConfiguredStepData] = []
    @State private var stepBeingConfigured: WorkflowStep?
    @State private var currentStepConfig = WorkflowStepConfig()

    // Available steps - all workflow steps including Organize
    // Note: Organize in automated workflow passes files through (requires interactive UI for actual reordering)
    private var availableSteps: [WorkflowStep] {
        WorkflowStep.allCases
    }

    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Header
                        workflowBuilderHeader

                        // Workflow Name
                        workflowNameSection

                        // Selected Steps with configurations
                        selectedStepsSection

                        // Available Steps (always show so user can add steps)
                        availableStepsSection

                        // Tip
                        if !configuredSteps.isEmpty {
                            addStepButton
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Build Workflow")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkflow()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(workflowName.isEmpty || configuredSteps.isEmpty)
                }
            }
            .sheet(item: $stepBeingConfigured) { step in
                StepConfigurationView(
                    step: step,
                    config: $currentStepConfig,
                    onSave: {
                        let configured = ConfiguredStepData(step: step, config: currentStepConfig)
                        configuredSteps.append(configured)
                        stepBeingConfigured = nil
                        HapticManager.shared.notification(.success)
                    },
                    onCancel: {
                        stepBeingConfigured = nil
                    }
                )
            }
        }
        .onAppear {
            if let template = template {
                workflowName = template.title
                // Convert template steps to configured steps with default configs
                configuredSteps = template.steps.map { step in
                    ConfiguredStepData(step: step, config: WorkflowStepConfig.defaultConfig(for: step))
                }
            }
        }
    }
    
    private var workflowBuilderHeader: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Image(systemName: "gear.badge.checkmark")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(OneBoxColors.primaryGold)
                    
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Create Custom Workflow")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Chain multiple operations together")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var workflowNameSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                Text("Workflow Name")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                TextField("Enter workflow name", text: $workflowName)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                    .padding(OneBoxSpacing.small)
                    .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                    .cornerRadius(OneBoxRadius.small)
            }
        }
    }
    
    private var selectedStepsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            if !configuredSteps.isEmpty {
                Text("Workflow Steps")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)

                ForEach(Array(configuredSteps.enumerated()), id: \.element.id) { index, configured in
                    configuredStepRow(configured, index: index)
                }
            }
        }
    }

    private func configuredStepRow(_ configured: ConfiguredStepData, index: Int) -> some View {
        OneBoxCard(style: .interactive) {
            HStack(spacing: OneBoxSpacing.medium) {
                // Step number
                ZStack {
                    Circle()
                        .fill(OneBoxColors.primaryGold.opacity(0.2))
                        .frame(width: 32, height: 32)

                    Text("\(index + 1)")
                        .font(OneBoxTypography.caption)
                        .fontWeight(.bold)
                        .foregroundColor(OneBoxColors.primaryGold)
                }

                // Step info with config summary
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(configured.step.title)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)

                    Text(configSummary(for: configured))
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                // Reorder controls
                HStack(spacing: OneBoxSpacing.tiny) {
                    if index > 0 {
                        Button(action: {
                            moveStep(from: index, to: index - 1)
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 14))
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                    }

                    if index < configuredSteps.count - 1 {
                        Button(action: {
                            moveStep(from: index, to: index + 1)
                        }) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 14))
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                    }
                    
                    Button(action: {
                        removeStep(at: index)
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.criticalRed)
                    }
                }
            }
        }
    }
    
    private var addStepButton: some View {
        OneBoxCard(style: .standard) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(OneBoxColors.primaryGold)
                Text("Tap any step above to add more to your workflow")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    private var availableStepsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Available Steps")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)

            Text("Tap a step to configure and add it")
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.secondaryText)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: OneBoxSpacing.small) {
                ForEach(availableSteps, id: \.id) { step in
                    availableStepCard(step)
                }
            }
        }
    }

    private func availableStepCard(_ step: WorkflowStep) -> some View {
        Button(action: {
            addStep(step)
        }) {
            VStack(spacing: OneBoxSpacing.small) {
                Image(systemName: step.icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(OneBoxColors.primaryGold)

                Text(step.title)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(OneBoxSpacing.medium)
            .background(OneBoxColors.surfaceGraphite.opacity(0.3))
            .cornerRadius(OneBoxRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func addStep(_ step: WorkflowStep) {
        // Set up config first, then set stepBeingConfigured to trigger sheet
        currentStepConfig = WorkflowStepConfig.defaultConfig(for: step)
        stepBeingConfigured = step
        HapticManager.shared.selection()
    }
    
    private func removeStep(at index: Int) {
        configuredSteps.remove(at: index)
        HapticManager.shared.impact(.light)
    }
    
    private func moveStep(from: Int, to: Int) {
        guard from >= 0 && from < configuredSteps.count,
              to >= 0 && to < configuredSteps.count else { return }

        let step = configuredSteps.remove(at: from)
        configuredSteps.insert(step, at: to)
        HapticManager.shared.impact(.light)
    }

    private func configSummary(for configured: ConfiguredStepData) -> String {
        let config = configured.config
        switch configured.step {
        case .compress:
            return "Quality: \(config.compressionQuality.capitalized)"
        case .watermark:
            return "\"\(config.watermarkText)\" • \(config.watermarkPosition) • \(Int(config.watermarkOpacity * 100))%"
        case .sign:
            return "Interactive - touch to place"
        case .organize:
            return "Interactive - reorder pages"
        case .addPageNumbers:
            return config.batesPrefix.isEmpty ? "Page X of Y • \(config.pageNumberPosition)" : "Bates: \(config.batesPrefix)"
        case .addDateStamp:
            return "Position: \(config.dateStampPosition)"
        case .redact:
            return "Interactive - review & select"
        case .merge:
            return "Combine all files"
        case .split:
            return "Split into pages"
        case .imagesToPDF:
            return "Convert images"
        case .flatten:
            return "Flatten forms & annotations"
        default:
            return configured.step.description
        }
    }

    private func saveWorkflow() {
        guard !workflowName.isEmpty && !configuredSteps.isEmpty else { return }

        // Save to UserDefaults
        let defaults = UserDefaults.standard
        var savedWorkflows: [CustomWorkflowData] = []

        if let data = defaults.data(forKey: "saved_custom_workflows"),
           let decoded = try? JSONDecoder().decode([CustomWorkflowData].self, from: data) {
            savedWorkflows = decoded
        }

        let newWorkflow = CustomWorkflowData(
            id: UUID(),
            name: workflowName,
            configuredSteps: configuredSteps,
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

// MARK: - Custom Workflow Data (for persistence)
struct CustomWorkflowData: Codable {
    let id: UUID
    let name: String
    let configuredSteps: [ConfiguredStepData]
    let lastUsed: Date

    // Migration: Support old format without configurations
    init(id: UUID, name: String, configuredSteps: [ConfiguredStepData], lastUsed: Date) {
        self.id = id
        self.name = name
        self.configuredSteps = configuredSteps
        self.lastUsed = lastUsed
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        lastUsed = try container.decode(Date.self, forKey: .lastUsed)

        // Try new format first, fall back to old format
        if let configured = try? container.decode([ConfiguredStepData].self, forKey: .configuredSteps) {
            configuredSteps = configured
        } else if let oldSteps = try? container.decode([WorkflowStep].self, forKey: .steps) {
            // Migrate old format to new format with default configs
            configuredSteps = oldSteps.map { ConfiguredStepData(step: $0, config: WorkflowStepConfig.defaultConfig(for: $0)) }
        } else {
            configuredSteps = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(configuredSteps, forKey: .configuredSteps)
        try container.encode(lastUsed, forKey: .lastUsed)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, configuredSteps, steps, lastUsed
    }
}

// MARK: - Configured Step (Step + Configuration)
struct ConfiguredStepData: Codable, Identifiable {
    let id: UUID
    let step: WorkflowStep
    var config: WorkflowStepConfig

    init(step: WorkflowStep, config: WorkflowStepConfig) {
        self.id = UUID()
        self.step = step
        self.config = config
    }
}

// MARK: - Step Configuration
struct WorkflowStepConfig: Codable {
    // Compression settings
    var compressionQuality: String = "medium" // low, medium, high, maximum

    // Watermark settings
    var watermarkText: String = "CONFIDENTIAL"
    var watermarkPosition: String = "center" // center, topLeft, topRight, bottomLeft, bottomRight, tiled
    var watermarkOpacity: Double = 0.3
    var watermarkSize: Double = 0.15

    // Sign settings
    var signaturePosition: String = "bottomRight"
    var useStoredSignature: Bool = true // Use user's saved signature
    var signatureText: String = "" // Fallback text if no saved signature
    var drawnSignatureData: Data? = nil // Signature drawn in workflow config

    // Page numbers settings
    var pageNumberPosition: String = "bottomCenter"
    var pageNumberFormat: String = "Page {page} of {total}"
    var batesPrefix: String = ""
    var batesStartNumber: Int = 1

    // Date stamp settings
    var dateStampPosition: String = "topRight"

    // Redaction settings
    var redactionPreset: String = "legal" // legal, finance, hr, medical, custom

    // Default configurations per step type
    static func defaultConfig(for step: WorkflowStep) -> WorkflowStepConfig {
        var config = WorkflowStepConfig()

        switch step {
        case .compress:
            config.compressionQuality = "medium"
        case .watermark:
            config.watermarkText = "CONFIDENTIAL"
            config.watermarkPosition = "tiled"
            config.watermarkOpacity = 0.3
        case .sign:
            config.signaturePosition = "bottomRight"
            config.useStoredSignature = true
        case .addPageNumbers:
            config.pageNumberPosition = "bottomCenter"
        case .addDateStamp:
            config.dateStampPosition = "topRight"
        case .redact:
            config.redactionPreset = "legal"
        default:
            break
        }

        return config
    }
}

// MARK: - Step Configuration View
struct StepConfigurationView: View {
    let step: WorkflowStep
    @Binding var config: WorkflowStepConfig
    let onSave: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Step header
                        stepHeader

                        // Configuration options based on step type
                        configurationOptions
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Configure \(step.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OneBoxColors.primaryGraphite, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { onCancel() }
                        .foregroundColor(OneBoxColors.primaryText)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Step") { onSave() }
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
    }

    private var stepHeader: some View {
        OneBoxCard(style: .standard) {
            HStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: step.icon)
                    .font(.system(size: 32))
                    .foregroundColor(OneBoxColors.primaryGold)

                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(step.title)
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    Text(step.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var configurationOptions: some View {
        switch step {
        case .compress:
            compressOptions
        case .watermark:
            watermarkOptions
        case .sign:
            signOptions
        case .addPageNumbers:
            pageNumberOptions
        case .addDateStamp:
            dateStampOptions
        case .redact:
            redactOptions
        case .organize:
            organizeInfo
        default:
            simpleStepInfo
        }
    }

    private var organizeInfo: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            OneBoxCard(style: .standard) {
                VStack(spacing: OneBoxSpacing.medium) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 48))
                        .foregroundColor(OneBoxColors.warningAmber)

                    Text("Interactive Step")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)

                    Text("Page organization requires the interactive organizer.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(OneBoxSpacing.large)
            }

            OneBoxCard(style: .standard) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Label("What happens in workflow:", systemImage: "info.circle")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryGold)

                    Text("When this step runs, the Page Organizer will open so you can:")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Reorder pages by dragging", systemImage: "arrow.up.arrow.down")
                        Label("Rotate pages", systemImage: "rotate.right")
                        Label("Delete unwanted pages", systemImage: "trash")
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(OneBoxSpacing.medium)
            }
        }
    }

    private var compressOptions: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Compression Quality")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)

                ForEach(["low", "medium", "high", "maximum"], id: \.self) { quality in
                    Button(action: { config.compressionQuality = quality }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(quality.capitalized)
                                    .foregroundColor(OneBoxColors.primaryText)
                                Text(qualityDescription(quality))
                                    .font(OneBoxTypography.micro)
                                    .foregroundColor(OneBoxColors.secondaryText)
                            }
                            Spacer()
                            if config.compressionQuality == quality {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(OneBoxColors.primaryGold)
                            }
                        }
                        .padding(OneBoxSpacing.small)
                        .background(config.compressionQuality == quality ? OneBoxColors.primaryGold.opacity(0.1) : Color.clear)
                        .cornerRadius(OneBoxRadius.small)
                    }
                }
            }
        }
    }

    private func qualityDescription(_ quality: String) -> String {
        switch quality {
        case "low": return "Smallest file size, lower quality"
        case "medium": return "Balanced size and quality"
        case "high": return "Good quality, moderate size"
        case "maximum": return "Best quality, larger file"
        default: return ""
        }
    }

    private var watermarkOptions: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            OneBoxCard(style: .standard) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Text("Watermark Text")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    TextField("Enter watermark text", text: $config.watermarkText)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                        .padding(OneBoxSpacing.small)
                        .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                        .cornerRadius(OneBoxRadius.small)
                }
            }

            OneBoxCard(style: .standard) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Text("Position")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(["topLeft", "topRight", "center", "bottomLeft", "bottomRight", "tiled"], id: \.self) { pos in
                            Button(action: { config.watermarkPosition = pos }) {
                                Text(positionLabel(pos))
                                    .font(OneBoxTypography.micro)
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(config.watermarkPosition == pos ? OneBoxColors.primaryGold : OneBoxColors.surfaceGraphite)
                                    .foregroundColor(config.watermarkPosition == pos ? .black : OneBoxColors.primaryText)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }

            OneBoxCard(style: .standard) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Text("Opacity: \(Int(config.watermarkOpacity * 100))%")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    Slider(value: $config.watermarkOpacity, in: 0.1...1.0, step: 0.05)
                        .tint(OneBoxColors.primaryGold)
                }
            }
        }
    }

    private func positionLabel(_ pos: String) -> String {
        switch pos {
        case "topLeft": return "Top Left"
        case "topRight": return "Top Right"
        case "center": return "Center"
        case "bottomLeft": return "Bottom Left"
        case "bottomRight": return "Bottom Right"
        case "bottomCenter": return "Bottom Center"
        case "tiled": return "Tiled"
        default: return pos.capitalized
        }
    }

    private var signOptions: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            OneBoxCard(style: .standard) {
                VStack(spacing: OneBoxSpacing.medium) {
                    Image(systemName: "signature")
                        .font(.system(size: 48))
                        .foregroundColor(OneBoxColors.warningAmber)

                    Text("Interactive Step")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)

                    Text("Signing requires the interactive signature view.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(OneBoxSpacing.large)
            }

            OneBoxCard(style: .standard) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Label("What happens in workflow:", systemImage: "info.circle")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryGold)

                    Text("When this step runs, the Signature View will open so you can:")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Draw your signature on the document", systemImage: "pencil.tip")
                        Label("Position it exactly where you want", systemImage: "arrow.up.and.down.and.arrow.left.and.right")
                        Label("Resize for the perfect fit", systemImage: "arrow.up.left.and.arrow.down.right")
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(OneBoxSpacing.medium)
            }
        }
    }

    private var pageNumberOptions: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            OneBoxCard(style: .standard) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Text("Position")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(["bottomLeft", "bottomCenter", "bottomRight"], id: \.self) { pos in
                            Button(action: { config.pageNumberPosition = pos }) {
                                Text(positionLabel(pos))
                                    .font(OneBoxTypography.micro)
                                    .padding(8)
                                    .frame(maxWidth: .infinity)
                                    .background(config.pageNumberPosition == pos ? OneBoxColors.primaryGold : OneBoxColors.surfaceGraphite)
                                    .foregroundColor(config.pageNumberPosition == pos ? .black : OneBoxColors.primaryText)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
            }

            OneBoxCard(style: .standard) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Text("Bates Numbering (Optional)")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    TextField("Prefix (e.g., DOC-)", text: $config.batesPrefix)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                        .padding(OneBoxSpacing.small)
                        .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                        .cornerRadius(OneBoxRadius.small)

                    if !config.batesPrefix.isEmpty {
                        Stepper("Start: \(config.batesStartNumber)", value: $config.batesStartNumber, in: 1...99999)
                            .foregroundColor(OneBoxColors.primaryText)
                    }
                }
            }
        }
    }

    private var dateStampOptions: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                Text("Position")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(["topLeft", "topRight", "bottomLeft", "bottomRight"], id: \.self) { pos in
                        Button(action: { config.dateStampPosition = pos }) {
                            Text(positionLabel(pos))
                                .font(OneBoxTypography.caption)
                                .padding(12)
                                .frame(maxWidth: .infinity)
                                .background(config.dateStampPosition == pos ? OneBoxColors.primaryGold : OneBoxColors.surfaceGraphite)
                                .foregroundColor(config.dateStampPosition == pos ? .black : OneBoxColors.primaryText)
                                .cornerRadius(8)
                        }
                    }
                }
            }
        }
    }

    private var redactOptions: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            OneBoxCard(style: .standard) {
                VStack(spacing: OneBoxSpacing.medium) {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 48))
                        .foregroundColor(OneBoxColors.criticalRed)

                    Text("Interactive Step")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)

                    Text("Redaction requires review to ensure accuracy.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(OneBoxSpacing.large)
            }

            OneBoxCard(style: .standard) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Label("What happens in workflow:", systemImage: "info.circle")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryGold)

                    Text("When this step runs, the Redaction View will open so you can:")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)

                    VStack(alignment: .leading, spacing: 4) {
                        Label("Review automatically detected sensitive data", systemImage: "brain")
                        Label("Select which items to redact", systemImage: "checkmark.circle")
                        Label("Add custom text patterns to redact", systemImage: "plus.circle")
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(OneBoxSpacing.medium)
            }
        }
    }

    private var simpleStepInfo: some View {
        OneBoxCard(style: .standard) {
            VStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(OneBoxColors.secureGreen)

                Text("No configuration needed")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)

                Text("This step will be applied automatically")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(OneBoxSpacing.large)
        }
    }
}

#Preview {
    WorkflowConciergeView()
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
}