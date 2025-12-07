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
    @State private var isWorkflowRunning = false
    @State private var workflowError: String?
    @State private var currentStepIndex = 0
    @State private var totalSteps = 0

    // Success state
    @State private var workflowSucceeded = false
    @State private var completedOutputURLs: [URL] = []
    @State private var showingShareSheet = false

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
                .environmentObject(jobManager)
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
                steps: data.steps,
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
                steps: workflow.steps,
                lastUsed: workflow.lastUsed
            )
        }
        
        if let encoded = try? JSONEncoder().encode(data) {
            defaults.set(encoded, forKey: "saved_custom_workflows")
        }
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
            // Create new CustomWorkflow with updated lastUsed date, preserving the original id
            customWorkflows[index] = CustomWorkflow(
                id: workflow.id,
                name: workflow.name,
                steps: workflow.steps,
                lastUsed: Date()
            )
            saveCustomWorkflows()
        }
        
        // Convert CustomWorkflow to WorkflowTemplate (temporary) to run
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
        showingFilePicker = true
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let template = activeTemplate else { return }

            // Access security scoped resources
            let secureURLs = urls.map { url -> URL in
                if url.startAccessingSecurityScopedResource() {
                    return url
                }
                return url
            }

            Task {
                isWorkflowRunning = true
                totalSteps = template.steps.count
                currentStepIndex = 0

                // Start monitoring progress (faster polling for responsive UI)
                let progressTask = Task {
                    while isWorkflowRunning {
                        await MainActor.run {
                            currentStepIndex = WorkflowExecutionService.shared.currentStepIndex
                        }
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s for responsive UI
                    }
                }

                await WorkflowExecutionService.shared.executeWorkflow(
                    template: template,
                    inputURLs: secureURLs,
                    jobManager: jobManager
                )

                progressTask.cancel()
                isWorkflowRunning = false

                // Check for errors or success
                if let error = WorkflowExecutionService.shared.error {
                    workflowError = error
                } else {
                    // Success! Get the output files from the last completed job
                    if let lastJob = jobManager.completedJobs.last,
                       !lastJob.outputURLs.isEmpty {
                        completedOutputURLs = lastJob.outputURLs
                        workflowSucceeded = true
                    } else {
                        workflowSucceeded = true
                        completedOutputURLs = []
                    }
                }

                // Release resources after processing
                for url in secureURLs {
                    url.stopAccessingSecurityScopedResource()
                }
            }

        case .failure(let error):
            print("File selection failed: \(error.localizedDescription)")
        }
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
            description: "HIPAA-compliant: redact PHI, add processing date, watermark, flatten, compress",
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
    let steps: [WorkflowStep]
    let lastUsed: Date
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
}

// MARK: - Workflow Builder View
struct WorkflowBuilderView: View {
    let template: WorkflowTemplate?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    @State private var workflowName = ""
    @State private var selectedSteps: [WorkflowStep] = []
    @State private var availableSteps: [WorkflowStep] = WorkflowStep.allCases
    
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
                        
                        // Selected Steps
                        selectedStepsSection
                        
                        // Available Steps (always show so user can add steps)
                        availableStepsSection

                        // Add Step Button (shows after steps are selected)
                        if !selectedSteps.isEmpty {
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
                    .disabled(workflowName.isEmpty || selectedSteps.isEmpty)
                }
            }
        }
        .onAppear {
            if let template = template {
                workflowName = template.title
                selectedSteps = template.steps
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
            if !selectedSteps.isEmpty {
                Text("Workflow Steps")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                ForEach(Array(selectedSteps.enumerated()), id: \.offset) { index, step in
                    stepRow(step, index: index)
                }
            }
        }
    }
    
    private func stepRow(_ step: WorkflowStep, index: Int) -> some View {
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
                
                // Step info
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(step.title)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text("Step \(index + 1) of \(selectedSteps.count)")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
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
                    
                    if index < selectedSteps.count - 1 {
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

            Text("Tap a step to add it to your workflow")
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.secondaryText)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: OneBoxSpacing.small) {
                ForEach(availableSteps.filter { !selectedSteps.contains($0) }, id: \.id) { step in
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
        selectedSteps.append(step)
        HapticManager.shared.selection()
    }
    
    private func removeStep(at index: Int) {
        selectedSteps.remove(at: index)
        HapticManager.shared.impact(.light)
    }
    
    private func moveStep(from: Int, to: Int) {
        guard from >= 0 && from < selectedSteps.count,
              to >= 0 && to < selectedSteps.count else { return }
        
        let step = selectedSteps.remove(at: from)
        selectedSteps.insert(step, at: to)
        HapticManager.shared.impact(.light)
    }
    
    private func saveWorkflow() {
        guard !workflowName.isEmpty && !selectedSteps.isEmpty else { return }
        
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
            steps: selectedSteps,
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
    let steps: [WorkflowStep]
    let lastUsed: Date
}

#Preview {
    WorkflowConciergeView()
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
}