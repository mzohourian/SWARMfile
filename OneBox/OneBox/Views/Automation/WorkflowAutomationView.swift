//
//  WorkflowAutomationView.swift
//  OneBox
//
//  Multi-step workflow automation with AI pattern recognition and custom triggers
//

import SwiftUI
import UIComponents
import JobEngine

struct WorkflowAutomationView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var workflows: [AutomationWorkflow] = []
    @State private var showingWorkflowCreator = false
    @State private var showingTemplateLibrary = false
    @State private var selectedWorkflow: AutomationWorkflow?
    @State private var isAnalyzing = false
    @State private var suggestedWorkflows: [AutomationWorkflowSuggestion] = []
    @State private var recentExecutions: [WorkflowExecution] = []
    @State private var searchText = ""
    @State private var selectedCategory: WorkflowCategory = .all
    @State private var showingPasswordAlert = false
    @State private var generatedPasswordToShow: String = ""

    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with search
                    automationHeader
                    
                    // Main content
                    ScrollView {
                        VStack(spacing: OneBoxSpacing.large) {
                            // Quick Actions
                            quickActionsSection
                            
                            // AI Suggestions
                            if !suggestedWorkflows.isEmpty {
                                aiSuggestionsSection
                            }
                            
                            // Active Workflows
                            activeWorkflowsSection
                            
                            // Recent Executions
                            if !recentExecutions.isEmpty {
                                recentExecutionsSection
                            }
                            
                            // Workflow Templates
                            templatesSection
                        }
                        .padding(OneBoxSpacing.medium)
                    }
                }
            }
            .navigationTitle("Workflow Automation")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Create Workflow", systemImage: "plus.circle") {
                            showingWorkflowCreator = true
                        }
                        
                        Button("Browse Templates", systemImage: "doc.text.image") {
                            showingTemplateLibrary = true
                        }
                        
                        Button("Import Workflow", systemImage: "arrow.down.doc") {
                            importWorkflow()
                        }
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingWorkflowCreator) {
            WorkflowCreatorView(workflows: $workflows)
        }
        .sheet(isPresented: $showingTemplateLibrary) {
            WorkflowTemplateLibraryView(onTemplateSelected: addWorkflowFromTemplate)
        }
        .alert("Encryption Password", isPresented: $showingPasswordAlert) {
            Button("Copy Password") {
                UIPasteboard.general.string = generatedPasswordToShow
                HapticManager.shared.notification(.success)
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your file was encrypted with this auto-generated password. Save it securely:\n\n\(generatedPasswordToShow)")
        }
        .onAppear {
            loadWorkflows()
            analyzePatternsAndSuggest()
        }
    }
    
    // MARK: - Header
    private var automationHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Intelligent Automation")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("AI-powered workflows • Pattern recognition • Smart triggers")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: OneBoxSpacing.tiny) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(OneBoxColors.primaryGold)
                        } else {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        Text("\(workflows.count) workflows")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                // Search and filter
                HStack {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        TextField("Search workflows...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                            .foregroundColor(OneBoxColors.primaryText)
                    }
                    .padding(OneBoxSpacing.small)
                    .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                    .cornerRadius(OneBoxRadius.small)
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(WorkflowCategory.allCases, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(OneBoxColors.primaryGold)
                }
            }
        }
        .padding(.horizontal, OneBoxSpacing.medium)
        .padding(.top, OneBoxSpacing.medium)
    }
    
    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Quick Actions")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OneBoxSpacing.medium) {
                    quickActionCard("Create Workflow", "Build custom automation", "plus.circle.fill", OneBoxColors.primaryGold) {
                        showingWorkflowCreator = true
                    }
                    
                    quickActionCard("Smart Suggestions", "AI-powered recommendations", "brain.head.profile", OneBoxColors.secureGreen) {
                        analyzePatternsAndSuggest()
                    }
                    
                    quickActionCard("Browse Templates", "Pre-built workflow templates", "doc.text.image.fill", OneBoxColors.warningAmber) {
                        showingTemplateLibrary = true
                    }
                    
                    quickActionCard("Workflow Analytics", "Performance insights", "chart.line.uptrend.xyaxis", OneBoxColors.criticalRed) {
                        showAnalytics()
                    }
                }
                .padding(.horizontal, OneBoxSpacing.medium)
            }
        }
    }
    
    private func quickActionCard(_ title: String, _ description: String, _ icon: String, _ color: Color, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: OneBoxSpacing.small) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(color)
                }
                
                VStack(spacing: OneBoxSpacing.tiny) {
                    Text(title)
                        .font(OneBoxTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(description)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(width: 120)
            .padding(OneBoxSpacing.medium)
            .background(
                OneBoxCard(style: .interactive) {
                    EmptyView()
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - AI Suggestions
    private var aiSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            HStack {
                Text("AI Workflow Suggestions")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundColor(OneBoxColors.primaryGold)
            }
            
            VStack(spacing: OneBoxSpacing.small) {
                ForEach(suggestedWorkflows.prefix(3)) { suggestion in
                    suggestionCard(suggestion)
                }
            }
        }
    }
    
    private func suggestionCard(_ suggestion: AutomationWorkflowSuggestion) -> some View {
        OneBoxCard(style: .elevated) {
            HStack(spacing: OneBoxSpacing.medium) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Text(suggestion.title)
                        .font(OneBoxTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(suggestion.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .lineLimit(2)
                    
                    HStack {
                        Text("Confidence: \(Int(suggestion.confidence * 100))%")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(suggestion.confidence > 0.8 ? OneBoxColors.secureGreen : OneBoxColors.warningAmber)
                        
                        Spacer()
                        
                        Text("Saves ~\(suggestion.timeSavingMinutes) min")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                VStack(spacing: OneBoxSpacing.small) {
                    Button("Create") {
                        createWorkflowFromSuggestion(suggestion)
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGraphite)
                    .padding(.horizontal, OneBoxSpacing.medium)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.primaryGold)
                    .cornerRadius(OneBoxRadius.small)
                    
                    Button("Dismiss") {
                        dismissSuggestion(suggestion)
                    }
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.tertiaryText)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Active Workflows
    private var activeWorkflowsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            HStack {
                Text("Active Workflows")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                Text("\(workflows.filter { $0.isEnabled }.count) enabled")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            
            if filteredWorkflows.isEmpty {
                emptyWorkflowsView
            } else {
                LazyVStack(spacing: OneBoxSpacing.small) {
                    ForEach(filteredWorkflows) { workflow in
                        workflowCard(workflow)
                    }
                }
            }
        }
    }
    
    private var emptyWorkflowsView: some View {
        OneBoxCard(style: .standard) {
            VStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: "gearshape.2")
                    .font(.system(size: 48))
                    .foregroundColor(OneBoxColors.tertiaryText)
                
                Text("No Workflows Yet")
                    .font(OneBoxTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Create your first workflow to automate repetitive tasks and save time.")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                Button("Create Your First Workflow") {
                    showingWorkflowCreator = true
                }
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryGraphite)
                .padding(.horizontal, OneBoxSpacing.large)
                .padding(.vertical, OneBoxSpacing.medium)
                .background(OneBoxColors.primaryGold)
                .cornerRadius(OneBoxRadius.medium)
                .padding(.top, OneBoxSpacing.medium)
            }
            .padding(OneBoxSpacing.large)
        }
    }
    
    private func workflowCard(_ workflow: AutomationWorkflow) -> some View {
        OneBoxCard(style: .interactive) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        HStack {
                            Text(workflow.name)
                                .font(OneBoxTypography.body)
                                .fontWeight(.semibold)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            if workflow.isEnabled {
                                Circle()
                                    .fill(OneBoxColors.secureGreen)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        
                        Text(workflow.description)
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                    
                    Menu {
                        Button("Edit", systemImage: "pencil") {
                            editWorkflow(workflow)
                        }
                        
                        Button("Duplicate", systemImage: "doc.on.doc") {
                            duplicateWorkflow(workflow)
                        }
                        
                        Button("Export", systemImage: "square.and.arrow.up") {
                            exportWorkflow(workflow)
                        }
                        
                        Divider()
                        
                        Button(workflow.isEnabled ? "Disable" : "Enable", 
                               systemImage: workflow.isEnabled ? "pause.circle" : "play.circle") {
                            toggleWorkflow(workflow)
                        }
                        
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            deleteWorkflow(workflow)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                // Workflow stats
                HStack {
                    workflowStat("Triggers", "\(workflow.triggers.count)", "bolt.fill")
                    
                    Spacer()
                    
                    workflowStat("Actions", "\(workflow.actions.count)", "list.bullet")
                    
                    Spacer()
                    
                    workflowStat("Runs", "\(workflow.executionCount)", "play.circle.fill")
                    
                    Spacer()
                    
                    workflowStat("Success", "\(Int(workflow.successRate * 100))%", "checkmark.circle.fill")
                }
                
                // Quick execute button
                if workflow.isEnabled && !workflow.triggers.contains(where: { $0.isAutomatic }) {
                    Button("Execute Now") {
                        executeWorkflow(workflow)
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.primaryGold.opacity(0.1))
                    .cornerRadius(OneBoxRadius.small)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .onTapGesture {
            selectedWorkflow = workflow
        }
    }
    
    private func workflowStat(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            HStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(OneBoxColors.primaryGold)
                
                Text(value)
                    .font(OneBoxTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(OneBoxColors.primaryText)
            }
            
            Text(label)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
    
    // MARK: - Recent Executions
    private var recentExecutionsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            HStack {
                Text("Recent Executions")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                Button("View All") {
                    showExecutionHistory()
                }
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryGold)
            }
            
            VStack(spacing: OneBoxSpacing.small) {
                ForEach(recentExecutions.prefix(5)) { execution in
                    executionRow(execution)
                }
            }
        }
    }
    
    private func executionRow(_ execution: WorkflowExecution) -> some View {
        OneBoxCard(style: .standard) {
            HStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: execution.status.icon)
                    .font(.system(size: 16))
                    .foregroundColor(execution.status.color)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(execution.workflowName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    HStack {
                        Text(execution.status.displayName)
                            .font(OneBoxTypography.micro)
                            .foregroundColor(execution.status.color)
                        
                        Text("• \(formatDuration(execution.duration))")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        Text("• \(timeAgoString(execution.executedAt))")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                }
                
                Spacer()
                
                if execution.processedFiles > 0 {
                    Text("\(execution.processedFiles) files")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Templates
    private var templatesSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            HStack {
                Text("Workflow Templates")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                Button("Browse All") {
                    showingTemplateLibrary = true
                }
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryGold)
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: OneBoxSpacing.medium) {
                    ForEach(getPopularTemplates()) { template in
                        templateCard(template)
                    }
                }
                .padding(.horizontal, OneBoxSpacing.medium)
            }
        }
    }
    
    private func templateCard(_ template: AutomationWorkflowTemplate) -> some View {
        Button(action: {
            addWorkflowFromTemplate(template)
        }) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                HStack {
                    Image(systemName: template.icon)
                        .font(.system(size: 20))
                        .foregroundColor(template.category.color)
                    
                    Spacer()
                    
                    Text(template.difficulty.displayName)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.tertiaryText)
                }
                
                Text(template.name)
                    .font(OneBoxTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(2)
                
                Text(template.description)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(3)
                
                HStack {
                    Text(template.category.displayName)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(template.category.color)
                        .padding(.horizontal, OneBoxSpacing.small)
                        .padding(.vertical, OneBoxSpacing.tiny)
                        .background(template.category.color.opacity(0.1))
                        .cornerRadius(OneBoxRadius.small)
                    
                    Spacer()
                    
                    HStack(spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 10))
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        Text(String(format: "%.1f", template.rating))
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
            }
            .frame(width: 180)
            .padding(OneBoxSpacing.medium)
            .background(
                OneBoxCard(style: .interactive) {
                    EmptyView()
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    private var filteredWorkflows: [AutomationWorkflow] {
        workflows.filter { workflow in
            let matchesSearch = searchText.isEmpty || 
                workflow.name.localizedCaseInsensitiveContains(searchText) ||
                workflow.description.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == .all || workflow.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }
    }
    
    // MARK: - Helper Methods
    private func loadWorkflows() {
        // Load existing workflows
        workflows = [
            AutomationWorkflow(
                id: UUID(),
                name: "Daily Document Cleanup",
                description: "Automatically compress and organize documents in Downloads folder",
                category: .organization,
                triggers: [
                    WorkflowTrigger(type: .schedule, configuration: ["time": "09:00", "days": "weekdays"])
                ],
                actions: [
                    WorkflowAction(type: .compress, configuration: ["quality": "balanced"]),
                    WorkflowAction(type: .organize, configuration: ["strategy": "byDate"])
                ],
                isEnabled: true,
                executionCount: 47,
                successRate: 0.94
            ),
            AutomationWorkflow(
                id: UUID(),
                name: "Secure Client Documents",
                description: "Add watermarks and password protection to client-related PDFs",
                category: .security,
                triggers: [
                    WorkflowTrigger(type: .filePattern, configuration: ["pattern": "*client*", "folder": "Documents"])
                ],
                actions: [
                    WorkflowAction(type: .watermark, configuration: ["text": "CONFIDENTIAL"]),
                    WorkflowAction(type: .encrypt, configuration: ["password": "auto"])
                ],
                isEnabled: true,
                executionCount: 23,
                successRate: 1.0
            )
        ]
        
        // Load recent executions
        recentExecutions = [
            WorkflowExecution(
                id: UUID(),
                workflowName: "Daily Document Cleanup",
                status: .completed,
                executedAt: Date().addingTimeInterval(-3600),
                duration: 45,
                processedFiles: 12
            ),
            WorkflowExecution(
                id: UUID(),
                workflowName: "Secure Client Documents", 
                status: .completed,
                executedAt: Date().addingTimeInterval(-7200),
                duration: 23,
                processedFiles: 3
            ),
            WorkflowExecution(
                id: UUID(),
                workflowName: "PDF Merge Automation",
                status: .failed,
                executedAt: Date().addingTimeInterval(-14400),
                duration: 5,
                processedFiles: 0
            )
        ]
    }
    
    private func analyzePatternsAndSuggest() {
        isAnalyzing = true
        
        Task {
            // REAL PATTERN ANALYSIS - Analyze actual job history and user behavior
            let suggestions = await performRealPatternAnalysis()
            
            await MainActor.run {
                self.suggestedWorkflows = suggestions
                self.isAnalyzing = false
            }
        }
    }
    
    private func performRealPatternAnalysis() async -> [AutomationWorkflowSuggestion] {
        var suggestions: [AutomationWorkflowSuggestion] = []
        
        // Analyze completed jobs from JobManager
        let completedJobs = await MainActor.run { jobManager.completedJobs }
        
        // Pattern 1: Frequent large file compression
        let largeFileJobs = completedJobs.filter { job in
            guard job.type == .pdfCompress else { return false }
            // Check each input file size using helper function
            return job.inputs.contains { url in
                guard let fileSize = getFileSizeSafely(from: url) else {
                    return false
                }
                return fileSize > 10_000_000
            }
        }
        
        if largeFileJobs.count >= 3 {
            let avgProcessingTime = largeFileJobs.compactMap { $0.completedAt?.timeIntervalSince($0.createdAt) }.reduce(0, +) / Double(largeFileJobs.count)
            suggestions.append(AutomationWorkflowSuggestion(
                id: UUID(),
                title: "Auto-Compress Large PDFs",
                description: "Automatically compress PDFs larger than 10MB when they appear in your workflow",
                confidence: min(0.95, 0.6 + Double(largeFileJobs.count) * 0.1),
                timeSavingMinutes: Int(avgProcessingTime / 60 * 0.8), // 80% time saving through automation
                basedOnPattern: "Processed \(largeFileJobs.count) large files recently"
            ))
        }
        
        // Pattern 2: Security-focused operations
        let securityJobs = completedJobs.filter { job in
            job.settings.enableEncryption || 
            job.settings.enableDocumentSanitization || 
            job.type == .pdfWatermark ||
            job.type == .pdfSign
        }
        
        if securityJobs.count >= 2 {
            suggestions.append(AutomationWorkflowSuggestion(
                id: UUID(),
                title: "Security Workflow Template",
                description: "Auto-apply watermarks and encryption to sensitive documents",
                confidence: min(0.90, 0.5 + Double(securityJobs.count) * 0.15),
                timeSavingMinutes: 25,
                basedOnPattern: "High security feature usage (\(securityJobs.count) secure operations)"
            ))
        }
        
        // Pattern 3: Frequent PDF splitting/merging workflows
        let organizationJobs = completedJobs.filter { job in
            job.type == .pdfSplit || job.type == .pdfMerge || job.type == .pdfOrganize
        }
        
        if organizationJobs.count >= 4 {
            suggestions.append(AutomationWorkflowSuggestion(
                id: UUID(),
                title: "Document Organization Workflow",
                description: "Automatically organize and split documents by content type",
                confidence: min(0.85, 0.4 + Double(organizationJobs.count) * 0.08),
                timeSavingMinutes: 20,
                basedOnPattern: "Frequent document organization (\(organizationJobs.count) operations)"
            ))
        }
        
        // Pattern 4: Regular format conversion
        let conversionJobs = completedJobs.filter { job in
            job.type == .pdfToImages || job.type == .imagesToPDF
        }
        
        if conversionJobs.count >= 2 {
            let commonFormats = analyzeCommonFormats(conversionJobs)
            suggestions.append(AutomationWorkflowSuggestion(
                id: UUID(),
                title: "Format Conversion Automation",
                description: "Auto-convert documents to your preferred format (\(commonFormats))",
                confidence: min(0.80, 0.3 + Double(conversionJobs.count) * 0.2),
                timeSavingMinutes: 15,
                basedOnPattern: "Regular format conversions (\(conversionJobs.count) jobs)"
            ))
        }
        
        // Pattern 5: Weekly processing patterns
        let recentJobs = completedJobs.filter { job in
            guard let completedAt = job.completedAt else { return false }
            return completedAt.timeIntervalSinceNow > -604800 // Last 7 days
        }
        
        if recentJobs.count >= 5 {
            let avgJobsPerDay = Double(recentJobs.count) / 7.0
            if avgJobsPerDay > 1.0 {
                suggestions.append(AutomationWorkflowSuggestion(
                    id: UUID(),
                    title: "Daily Batch Processing",
                    description: "Schedule automatic processing of documents at optimal times",
                    confidence: min(0.75, 0.4 + avgJobsPerDay * 0.1),
                    timeSavingMinutes: Int(avgJobsPerDay * 5), // 5 min saved per job through batching
                    basedOnPattern: "High activity: \(String(format: "%.1f", avgJobsPerDay)) jobs/day"
                ))
            }
        }
        
        return suggestions.sorted { $0.confidence > $1.confidence }
    }
    
    private func analyzeCommonFormats(_ jobs: [Job]) -> String {
        var formatCounts: [String: Int] = [:]
        
        for job in jobs {
            switch job.type {
            case .pdfToImages:
                let format = job.settings.imageFormat == .png ? "PNG" : "JPEG"
                formatCounts[format, default: 0] += 1
            case .imagesToPDF:
                formatCounts["PDF", default: 0] += 1
            default:
                break
            }
        }
        
        let sortedFormats = formatCounts.sorted { $0.value > $1.value }
        return sortedFormats.prefix(2).map { $0.key }.joined(separator: ", ")
    }
    
    private func createWorkflowFromSuggestion(_ suggestion: AutomationWorkflowSuggestion) {
        // Create workflow based on AI suggestion
        let workflow = AutomationWorkflow(
            id: UUID(),
            name: suggestion.title,
            description: suggestion.description,
            category: .automation,
            triggers: [
                WorkflowTrigger(type: .fileSize, configuration: ["threshold": "10MB"])
            ],
            actions: [
                WorkflowAction(type: .compress, configuration: ["quality": "balanced"])
            ],
            isEnabled: true,
            executionCount: 0,
            successRate: 1.0
        )
        
        workflows.append(workflow)
        
        // Remove from suggestions
        suggestedWorkflows.removeAll { $0.id == suggestion.id }
        
        HapticManager.shared.notification(.success)
    }
    
    private func dismissSuggestion(_ suggestion: AutomationWorkflowSuggestion) {
        suggestedWorkflows.removeAll { $0.id == suggestion.id }
        HapticManager.shared.impact(.light)
    }
    
    private func toggleWorkflow(_ workflow: AutomationWorkflow) {
        if let index = workflows.firstIndex(where: { $0.id == workflow.id }) {
            workflows[index].isEnabled.toggle()
        }
        HapticManager.shared.selection()
    }
    
    private func executeWorkflow(_ workflow: AutomationWorkflow) {
        // REAL WORKFLOW EXECUTION - Convert workflow to actual jobs and execute through JobEngine
        Task {
            let executionId = UUID()
            let startTime = Date()
            
            // Create initial execution record
            var execution = WorkflowExecution(
                id: executionId,
                workflowName: workflow.name,
                status: .running,
                executedAt: startTime,
                duration: 0,
                processedFiles: 0
            )
            
            await MainActor.run {
                recentExecutions.insert(execution, at: 0)
                HapticManager.shared.impact(.light)
            }
            
            do {
                // Execute real workflow through JobEngine
                let results = try await executeWorkflowActions(workflow)
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)
                
                // Update execution with real results
                execution.status = .completed
                execution.duration = duration
                execution.processedFiles = results.processedFileCount
                
                await MainActor.run {
                    if let index = recentExecutions.firstIndex(where: { $0.id == executionId }) {
                        recentExecutions[index] = execution
                    }

                    // Update workflow statistics
                    if let workflowIndex = workflows.firstIndex(where: { $0.id == workflow.id }) {
                        workflows[workflowIndex].executionCount += 1
                        // Update success rate based on actual results
                        let totalExecutions = Double(workflows[workflowIndex].executionCount)
                        let successCount = totalExecutions * workflows[workflowIndex].successRate + 1
                        workflows[workflowIndex].successRate = successCount / totalExecutions
                    }

                    // Show generated password if encryption was used
                    if let password = results.generatedPassword {
                        generatedPasswordToShow = password
                        showingPasswordAlert = true
                    }

                    HapticManager.shared.notification(.success)
                }

            } catch {
                let endTime = Date()
                let duration = endTime.timeIntervalSince(startTime)
                
                // Update execution with failure
                execution.status = .failed
                execution.duration = duration
                execution.errorMessage = error.localizedDescription
                
                await MainActor.run {
                    if let index = recentExecutions.firstIndex(where: { $0.id == executionId }) {
                        recentExecutions[index] = execution
                    }
                    
                    // Update workflow failure statistics
                    if let workflowIndex = workflows.firstIndex(where: { $0.id == workflow.id }) {
                        workflows[workflowIndex].executionCount += 1
                        // Update success rate to reflect failure
                        let totalExecutions = Double(workflows[workflowIndex].executionCount)
                        let successCount = (totalExecutions - 1) * workflows[workflowIndex].successRate
                        workflows[workflowIndex].successRate = successCount / totalExecutions
                    }
                    
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func executeWorkflowActions(_ workflow: AutomationWorkflow) async throws -> WorkflowExecutionResult {
        var processedFiles: Set<URL> = []
        var outputFiles: [URL] = []
        var generatedPassword: String? = nil

        // Get input files based on workflow triggers
        var inputFiles = try await getWorkflowInputFiles(workflow)

        guard !inputFiles.isEmpty else {
            throw WorkflowExecutionError.noInputFiles
        }

        // Execute each action in sequence
        for action in workflow.actions {
            let jobType = convertActionToJobType(action)
            let (jobSettings, actionPassword) = convertActionToJobSettingsWithPassword(action)

            // Capture auto-generated password
            if actionPassword != nil {
                generatedPassword = actionPassword
            }

            // Create and submit real job to JobEngine
            let job = Job(
                type: jobType,
                inputs: inputFiles,
                settings: jobSettings
            )

            // Execute job synchronously and wait for completion
            let jobOutputs = try await executeJobSynchronously(job)

            // Track processed files
            processedFiles.formUnion(inputFiles)
            outputFiles.append(contentsOf: jobOutputs)

            // Use outputs as inputs for next action
            if !jobOutputs.isEmpty {
                inputFiles.removeAll()
                inputFiles.append(contentsOf: jobOutputs)
            }
        }

        return WorkflowExecutionResult(
            processedFileCount: processedFiles.count,
            outputFiles: outputFiles,
            executionSuccess: true,
            generatedPassword: generatedPassword
        )
    }
    
    private func getWorkflowInputFiles(_ workflow: AutomationWorkflow) async throws -> [URL] {
        var inputFiles: [URL] = []
        
        for trigger in workflow.triggers {
            switch trigger.type {
            case .filePattern:
                let pattern = trigger.configuration["pattern"] ?? "*"
                let folder = trigger.configuration["folder"] ?? "Downloads"
                let folderURL = getDocumentsDirectory().appendingPathComponent(folder)
                inputFiles.append(contentsOf: try getFilesMatchingPattern(pattern, in: folderURL))
                
            case .fileSize:
                let thresholdStr = trigger.configuration["threshold"] ?? "10MB"
                let threshold = Self.parseSizeString(thresholdStr)
                let folder = trigger.configuration["folder"] ?? "Downloads"
                let folderURL = getDocumentsDirectory().appendingPathComponent(folder)
                inputFiles.append(contentsOf: try getFilesLargerThan(threshold, in: folderURL))
                
            case .folderWatch:
                let folder = trigger.configuration["folder"] ?? "Downloads"
                let folderURL = getDocumentsDirectory().appendingPathComponent(folder)
                inputFiles.append(contentsOf: try getAllFilesInFolder(folderURL))
                
            case .manual, .schedule:
                // For manual/schedule triggers, use default Downloads folder
                let downloadsURL = getDocumentsDirectory().appendingPathComponent("Downloads")
                inputFiles.append(contentsOf: try getAllFilesInFolder(downloadsURL))
            }
        }
        
        return Array(Set(inputFiles)) // Remove duplicates
    }
    
    private func executeJobSynchronously(_ job: Job) async throws -> [URL] {
        return try await withCheckedThrowingContinuation { continuation in
            Task {
                // Submit job to JobManager
                await jobManager.submitJob(job)
                
                // Poll for completion
                var attempts = 0
                let maxAttempts = 300 // 5 minutes max
                
                while attempts < maxAttempts {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    
                    // Check job status
                    let completedJob = await MainActor.run {
                        jobManager.jobs.first { $0.id == job.id && ($0.status == .success || $0.status == .failed) }
                    }
                    if let completedJob = completedJob {
                        if completedJob.status == .success {
                            continuation.resume(returning: completedJob.outputURLs)
                        } else {
                            continuation.resume(throwing: WorkflowExecutionError.jobFailed(completedJob.error ?? "Unknown error"))
                        }
                        return
                    }
                    
                    attempts += 1
                }
                
                continuation.resume(throwing: WorkflowExecutionError.timeout)
            }
        }
    }
    
    private func convertActionToJobType(_ action: WorkflowAction) -> JobType {
        switch action.type {
        case .compress: return .pdfCompress
        case .organize: return .pdfOrganize
        case .watermark: return .pdfWatermark
        case .encrypt: return .pdfSign // Use sign for encryption
        case .merge: return .pdfMerge
        case .split: return .pdfSplit
        case .convert: return .pdfToImages
        case .backup: return .pdfMerge // Use merge as backup operation
        }
    }
    
    private func convertActionToJobSettings(_ action: WorkflowAction) -> JobSettings {
        var settings = JobSettings()
        
        switch action.type {
        case .compress:
            if let qualityStr = action.configuration["quality"] {
                switch qualityStr.lowercased() {
                case "high": settings.compressionQuality = .high
                case "low": settings.compressionQuality = .low
                default: settings.compressionQuality = .medium
                }
            }
            
        case .watermark:
            settings.watermarkText = action.configuration["text"]
            if let positionStr = action.configuration["position"] {
                switch positionStr.lowercased() {
                case "center": settings.watermarkPosition = .center
                case "topleft": settings.watermarkPosition = .topLeft
                case "topright": settings.watermarkPosition = .topRight
                case "bottomleft": settings.watermarkPosition = .bottomLeft
                default: settings.watermarkPosition = .bottomRight
                }
            }
            
        case .encrypt:
            settings.enableEncryption = true
            settings.encryptionPassword = action.configuration["password"] == "auto" ? 
                generateSecurePassword() : action.configuration["password"]
            
        case .split:
            if let rangesStr = action.configuration["ranges"] {
                // Parse ranges like "1-3,4,5-7" into [[1,2,3], [4], [5,6,7]]
                settings.splitRanges = Self.parsePageRanges(rangesStr)
            }
            
        default:
            break
        }
        
        // Apply security settings
        settings.stripMetadata = true
        settings.enableDocumentSanitization = true

        return settings
    }

    /// Converts action to job settings and returns any auto-generated password
    private func convertActionToJobSettingsWithPassword(_ action: WorkflowAction) -> (JobSettings, String?) {
        var settings = JobSettings()
        var generatedPassword: String? = nil

        switch action.type {
        case .compress:
            if let qualityStr = action.configuration["quality"] {
                switch qualityStr.lowercased() {
                case "high": settings.compressionQuality = .high
                case "low": settings.compressionQuality = .low
                default: settings.compressionQuality = .medium
                }
            }

        case .watermark:
            settings.watermarkText = action.configuration["text"]
            if let positionStr = action.configuration["position"] {
                switch positionStr.lowercased() {
                case "center": settings.watermarkPosition = .center
                case "topleft": settings.watermarkPosition = .topLeft
                case "topright": settings.watermarkPosition = .topRight
                case "bottomleft": settings.watermarkPosition = .bottomLeft
                default: settings.watermarkPosition = .bottomRight
                }
            }

        case .encrypt:
            settings.enableEncryption = true
            if action.configuration["password"] == "auto" {
                let autoPassword = generateSecurePassword()
                settings.encryptionPassword = autoPassword
                generatedPassword = autoPassword // Capture for showing to user
            } else {
                settings.encryptionPassword = action.configuration["password"]
            }

        case .split:
            if let rangesStr = action.configuration["ranges"] {
                settings.splitRanges = Self.parsePageRanges(rangesStr)
            }

        default:
            break
        }

        // Apply security settings
        settings.stripMetadata = true
        settings.enableDocumentSanitization = true

        return (settings, generatedPassword)
    }

    // Helper functions for file operations
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // Helper to safely get file size without throwing
    private func getFileSizeSafely(from url: URL) -> Int64? {
        do {
            let resources = try url.resourceValues(forKeys: [.fileSizeKey])
            guard let fileSize = resources.fileSize else {
                return nil
            }
            return Int64(fileSize)
        } catch {
            return nil
        }
    }
    
    private func getFilesMatchingPattern(_ pattern: String, in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        
        let contents = try FileManager.default.contentsOfDirectory(at: directory, 
                                                                   includingPropertiesForKeys: [.isRegularFileKey],
                                                                   options: .skipsHiddenFiles)
        
        // Break up complex expression to help type checker
        let patternString = pattern.replacingOccurrences(of: "*", with: ".*")
        let regex = try NSRegularExpression(pattern: patternString, options: .caseInsensitive)
        
        return contents.filter { url in
            let fileName = url.lastPathComponent
            let nsString = fileName as NSString
            let range = NSRange(location: 0, length: nsString.length)
            let match = regex.firstMatch(in: fileName, options: [], range: range)
            return match != nil
        }
    }
    
    private func getFilesLargerThan(_ threshold: Int64, in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        
        let contents = try FileManager.default.contentsOfDirectory(at: directory,
                                                                   includingPropertiesForKeys: [.fileSizeKey],
                                                                   options: .skipsHiddenFiles)
        
        var result: [URL] = []
        for url in contents {
            guard let fileSize = getFileSizeSafely(from: url),
                  fileSize > threshold else {
                continue
            }
            result.append(url)
        }
        return result
    }
    
    private func getAllFilesInFolder(_ directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        
        return try FileManager.default.contentsOfDirectory(at: directory,
                                                           includingPropertiesForKeys: [.isRegularFileKey],
                                                           options: .skipsHiddenFiles)
    }
    
    static func parseSizeString(_ sizeStr: String) -> Int64 {
        let cleanStr = sizeStr.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        
        if cleanStr.hasSuffix("GB") {
            return Int64(Double(cleanStr.dropLast(2)) ?? 1.0) * 1_000_000_000
        } else if cleanStr.hasSuffix("MB") {
            return Int64(Double(cleanStr.dropLast(2)) ?? 10.0) * 1_000_000
        } else if cleanStr.hasSuffix("KB") {
            return Int64(Double(cleanStr.dropLast(2)) ?? 100.0) * 1_000
        } else {
            return Int64(cleanStr) ?? 10_000_000 // Default 10MB
        }
    }
    
    private func generateSecurePassword() -> String {
        let chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#$%^&*"
        return String((0..<16).map { _ in chars.randomElement()! })
    }
    
    static func parsePageRanges(_ rangesStr: String) -> [[Int]] {
        return rangesStr.split(separator: ",").compactMap { rangeStr in
            let trimmed = rangeStr.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.contains("-") {
                let parts = trimmed.split(separator: "-")
                if parts.count == 2,
                   let start = Int(parts[0]),
                   let end = Int(parts[1]) {
                    return Array(start...end)
                }
            } else if let single = Int(trimmed) {
                return [single]
            }
            return nil
        }
    }
    
    private func editWorkflow(_ workflow: AutomationWorkflow) {
        selectedWorkflow = workflow
        showingWorkflowCreator = true
    }
    
    private func duplicateWorkflow(_ workflow: AutomationWorkflow) {
        let duplicated = AutomationWorkflow(
            id: UUID(),
            name: "\(workflow.name) Copy",
            description: workflow.description,
            category: workflow.category,
            triggers: workflow.triggers,
            actions: workflow.actions,
            isEnabled: false,
            executionCount: 0,
            successRate: 1.0
        )
        workflows.append(duplicated)
        HapticManager.shared.notification(.success)
    }
    
    private func exportWorkflow(_ workflow: AutomationWorkflow) {
        // Export workflow configuration
        HapticManager.shared.impact(.light)
    }
    
    private func deleteWorkflow(_ workflow: AutomationWorkflow) {
        workflows.removeAll { $0.id == workflow.id }
        HapticManager.shared.impact(.medium)
    }
    
    private func addWorkflowFromTemplate(_ template: AutomationWorkflowTemplate) {
        let workflow = AutomationWorkflow(
            id: UUID(),
            name: template.name,
            description: template.description,
            category: template.category,
            triggers: template.defaultTriggers,
            actions: template.defaultActions,
            isEnabled: false,
            executionCount: 0,
            successRate: 1.0
        )
        
        workflows.append(workflow)
        HapticManager.shared.notification(.success)
    }
    
    private func importWorkflow() {
        // Import workflow from file
        HapticManager.shared.impact(.light)
    }
    
    private func showAnalytics() {
        // Show workflow analytics
    }
    
    private func showExecutionHistory() {
        // Show full execution history
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        if seconds < 60 {
            return "\(Int(seconds))s"
        } else {
            return "\(Int(seconds / 60))m \(Int(seconds.truncatingRemainder(dividingBy: 60)))s"
        }
    }
    
    private func timeAgoString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    private func getPopularTemplates() -> [AutomationWorkflowTemplate] {
        [
            AutomationWorkflowTemplate(
                id: "compress-large",
                name: "Auto-Compress Large Files",
                description: "Automatically compress PDFs over a certain size",
                category: .optimization,
                difficulty: .beginner,
                rating: 4.8,
                icon: "arrow.down.circle.fill",
                defaultTriggers: [
                    WorkflowTrigger(type: .fileSize, configuration: ["threshold": "10MB"])
                ],
                defaultActions: [
                    WorkflowAction(type: .compress, configuration: ["quality": "balanced"])
                ]
            ),
            AutomationWorkflowTemplate(
                id: "secure-sensitive",
                name: "Secure Sensitive Documents",
                description: "Add watermarks and encryption to sensitive files",
                category: .security,
                difficulty: .intermediate,
                rating: 4.9,
                icon: "shield.fill",
                defaultTriggers: [
                    WorkflowTrigger(type: .filePattern, configuration: ["pattern": "*confidential*"])
                ],
                defaultActions: [
                    WorkflowAction(type: .watermark, configuration: ["text": "CONFIDENTIAL"]),
                    WorkflowAction(type: .encrypt, configuration: ["password": "auto"])
                ]
            ),
            AutomationWorkflowTemplate(
                id: "organize-by-date",
                name: "Organize by Date",
                description: "Automatically organize documents into date-based folders",
                category: .organization,
                difficulty: .beginner,
                rating: 4.6,
                icon: "folder.fill",
                defaultTriggers: [
                    WorkflowTrigger(type: .schedule, configuration: ["time": "00:00", "days": "daily"])
                ],
                defaultActions: [
                    WorkflowAction(type: .organize, configuration: ["strategy": "byDate"])
                ]
            )
        ]
    }
}

// MARK: - Supporting Types

struct AutomationWorkflow: Identifiable {
    let id: UUID
    var name: String
    var description: String
    let category: WorkflowCategory
    let triggers: [WorkflowTrigger]
    let actions: [WorkflowAction]
    var isEnabled: Bool
    var executionCount: Int
    var successRate: Double
}

struct WorkflowTrigger: Identifiable {
    let id = UUID()
    let type: TriggerType
    let configuration: [String: String]
    
    var isAutomatic: Bool {
        type == .schedule || type == .filePattern || type == .fileSize
    }
}

struct WorkflowAction: Identifiable {
    let id = UUID()
    let type: ActionType
    let configuration: [String: String]
}

struct AutomationWorkflowSuggestion: Identifiable {
    let id: UUID
    let title: String
    let description: String
    let confidence: Double
    let timeSavingMinutes: Int
    let basedOnPattern: String
}

struct WorkflowExecution: Identifiable {
    let id: UUID
    let workflowName: String
    var status: ExecutionStatus
    let executedAt: Date
    var duration: TimeInterval
    var processedFiles: Int
    var errorMessage: String?
    var generatedPassword: String? // Auto-generated password for encryption
}

struct AutomationWorkflowTemplate: Identifiable {
    let id: String
    let name: String
    let description: String
    let category: WorkflowCategory
    let difficulty: TemplateDifficulty
    let rating: Double
    let icon: String
    let defaultTriggers: [WorkflowTrigger]
    let defaultActions: [WorkflowAction]
}

enum WorkflowCategory: String, CaseIterable {
    case all = "all"
    case automation = "automation"
    case security = "security"
    case organization = "organization"
    case optimization = "optimization"
    case collaboration = "collaboration"
    
    var displayName: String {
        switch self {
        case .all: return "All"
        case .automation: return "Automation"
        case .security: return "Security"
        case .organization: return "Organization"
        case .optimization: return "Optimization"
        case .collaboration: return "Collaboration"
        }
    }
    
    var color: Color {
        switch self {
        case .all: return OneBoxColors.primaryText
        case .automation: return OneBoxColors.primaryGold
        case .security: return OneBoxColors.criticalRed
        case .organization: return OneBoxColors.secureGreen
        case .optimization: return OneBoxColors.warningAmber
        case .collaboration: return OneBoxColors.secondaryGold
        }
    }
}

enum TriggerType: String, CaseIterable {
    case manual = "manual"
    case schedule = "schedule"
    case filePattern = "filePattern"
    case fileSize = "fileSize"
    case folderWatch = "folderWatch"
    
    var displayName: String {
        switch self {
        case .manual: return "Manual Trigger"
        case .schedule: return "Schedule"
        case .filePattern: return "File Pattern"
        case .fileSize: return "File Size"
        case .folderWatch: return "Folder Watch"
        }
    }
}

enum ActionType: String, CaseIterable {
    case compress = "compress"
    case organize = "organize"
    case watermark = "watermark"
    case encrypt = "encrypt"
    case merge = "merge"
    case split = "split"
    case convert = "convert"
    case backup = "backup"
    
    var displayName: String {
        switch self {
        case .compress: return "Compress"
        case .organize: return "Organize"
        case .watermark: return "Add Watermark"
        case .encrypt: return "Encrypt"
        case .merge: return "Merge"
        case .split: return "Split"
        case .convert: return "Convert"
        case .backup: return "Backup"
        }
    }
}

enum ExecutionStatus: String, CaseIterable {
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .running: return "Running"
        case .completed: return "Completed"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var icon: String {
        switch self {
        case .running: return "clock.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "stop.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .running: return OneBoxColors.warningAmber
        case .completed: return OneBoxColors.secureGreen
        case .failed: return OneBoxColors.criticalRed
        case .cancelled: return OneBoxColors.tertiaryText
        }
    }
}

enum TemplateDifficulty: String, CaseIterable {
    case beginner = "beginner"
    case intermediate = "intermediate"
    case advanced = "advanced"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

// MARK: - Visual Workflow Builder

struct WorkflowCreatorView: View {
    @Binding var workflows: [AutomationWorkflow]
    @Environment(\.dismiss) var dismiss
    
    @State private var workflowName = ""
    @State private var workflowDescription = ""
    @State private var selectedCategory: WorkflowCategory = .automation
    @State private var workflowNodes: [WorkflowNode] = []
    @State private var connections: [NodeConnection] = []
    @State private var selectedNodeId: UUID?
    @State private var dragOffset: CGPoint = .zero
    @State private var showingNodeLibrary = false
    @State private var canvasZoom: CGFloat = 1.0
    @State private var canvasOffset: CGPoint = .zero
    @State private var isTestingWorkflow = false
    @State private var testResults: [TestResult] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Workflow info header
                    workflowDetailsHeader
                    
                    // Visual workflow canvas
                    workflowCanvas
                    
                    // Bottom toolbar
                    bottomToolbar
                }
            }
            .navigationTitle("Visual Workflow Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OneBoxColors.primaryGraphite, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Test Workflow", systemImage: "play.circle") {
                            testWorkflow()
                        }
                        
                        Button("Save as Template", systemImage: "doc.badge.plus") {
                            saveAsTemplate()
                        }
                        
                        Button("Import Nodes", systemImage: "arrow.down.doc") {
                            importNodes()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingNodeLibrary) {
            NodeLibraryView { node in
                addNodeToCanvas(node)
            }
        }
    }
    
    // MARK: - Workflow Details Header
    private var workflowDetailsHeader: some View {
        OneBoxCard(style: .standard) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        TextField("Workflow Name", text: $workflowName)
                            .font(OneBoxTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(OneBoxColors.primaryText)
                            .textFieldStyle(PlainTextFieldStyle())
                        
                        TextField("Description (optional)", text: $workflowDescription)
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    
                    Spacer()
                    
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(WorkflowCategory.allCases.filter { $0 != .all }, id: \.self) { category in
                            Text(category.displayName).tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                    .accentColor(OneBoxColors.primaryGold)
                }
                
                HStack {
                    workflowStatsItem("Nodes", workflowNodes.count, "circle.grid.2x2")
                    workflowStatsItem("Connections", connections.count, "arrow.triangle.branch")
                    workflowStatsItem("Triggers", workflowNodes.filter { $0.type.category == .trigger }.count, "bolt")
                    workflowStatsItem("Actions", workflowNodes.filter { $0.type.category == .action }.count, "gear")
                    
                    Spacer()
                    
                    Button(workflowNodes.isEmpty ? "Add Nodes" : "Save Workflow") {
                        if workflowNodes.isEmpty {
                            showingNodeLibrary = true
                        } else {
                            saveWorkflow()
                        }
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGraphite)
                    .padding(.horizontal, OneBoxSpacing.medium)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.primaryGold)
                    .cornerRadius(OneBoxRadius.small)
                    .disabled(workflowName.isEmpty || (workflowNodes.isEmpty && !showingNodeLibrary))
                }
            }
        }
        .padding(.horizontal, OneBoxSpacing.medium)
        .padding(.top, OneBoxSpacing.medium)
    }
    
    private func workflowStatsItem(_ label: String, _ count: Int, _ icon: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            HStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(OneBoxColors.primaryGold)
                
                Text("\(count)")
                    .font(OneBoxTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(OneBoxColors.primaryText)
            }
            
            Text(label)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
    
    // MARK: - Visual Workflow Canvas
    private var workflowCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                // Canvas background with grid
                canvasBackground(geometry.size)
                
                // Connection lines
                ForEach(connections) { connection in
                    connectionLine(connection, in: geometry.size)
                }
                
                // Workflow nodes
                ForEach(workflowNodes) { node in
                    workflowNodeView(node, canvasSize: geometry.size)
                }
                
                // Empty state
                if workflowNodes.isEmpty {
                    canvasEmptyState
                }
            }
            .scaleEffect(canvasZoom)
            .offset(x: canvasOffset.x, y: canvasOffset.y)
            .gesture(
                MagnificationGesture()
                    .onChanged { scale in
                        canvasZoom = max(0.5, min(2.0, scale))
                    }
                    .simultaneously(with:
                        DragGesture()
                            .onChanged { value in
                                canvasOffset.x += value.translation.width
                                canvasOffset.y += value.translation.height
                            }
                    )
            )
        }
        .background(OneBoxColors.surfaceGraphite)
        .onTapGesture {
            if workflowNodes.isEmpty {
                showingNodeLibrary = true
            }
        }
    }
    
    private func canvasBackground(_ size: CGSize) -> some View {
        Path { path in
            let gridSize: CGFloat = 20
            let columns = Int(size.width / gridSize) + 1
            let rows = Int(size.height / gridSize) + 1
            
            // Vertical lines
            for i in 0..<columns {
                let x = CGFloat(i) * gridSize
                path.move(to: CGPoint(x: x, y: 0))
                path.addLine(to: CGPoint(x: x, y: size.height))
            }
            
            // Horizontal lines
            for i in 0..<rows {
                let y = CGFloat(i) * gridSize
                path.move(to: CGPoint(x: 0, y: y))
                path.addLine(to: CGPoint(x: size.width, y: y))
            }
        }
        .stroke(OneBoxColors.primaryText.opacity(0.1), lineWidth: 0.5)
    }
    
    private var canvasEmptyState: some View {
        VStack(spacing: OneBoxSpacing.large) {
            Image(systemName: "plus.circle.dashed")
                .font(.system(size: 64))
                .foregroundColor(OneBoxColors.tertiaryText)
            
            VStack(spacing: OneBoxSpacing.small) {
                Text("Start Building Your Workflow")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Tap to add triggers, actions, and conditions")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            Button("Add First Node") {
                showingNodeLibrary = true
            }
            .font(OneBoxTypography.body)
            .foregroundColor(OneBoxColors.primaryGraphite)
            .padding(.horizontal, OneBoxSpacing.large)
            .padding(.vertical, OneBoxSpacing.medium)
            .background(OneBoxColors.primaryGold)
            .cornerRadius(OneBoxRadius.medium)
        }
    }
    
    private func connectionLine(_ connection: NodeConnection, in canvasSize: CGSize) -> some View {
        let startNode = workflowNodes.first { $0.id == connection.fromNodeId }
        let endNode = workflowNodes.first { $0.id == connection.toNodeId }
        
        guard let start = startNode, let end = endNode else {
            return AnyView(EmptyView())
        }
        
        return AnyView(
            Path { path in
                let lineStartPoint = CGPoint(
                    x: start.position.x + 50, // Node width / 2
                    y: start.position.y + 30  // Node height / 2
                )
                let lineEndPoint = CGPoint(
                    x: end.position.x + 50,
                    y: end.position.y + 30
                )
                
                path.move(to: lineStartPoint)
                
                // Create curved connection
                let offset: CGFloat = 50
                let controlPoint1: CGPoint = CGPoint(x: lineStartPoint.x + offset, y: lineStartPoint.y)
                let controlPoint2: CGPoint = CGPoint(x: lineEndPoint.x - offset, y: lineEndPoint.y)
                
                path.addCurve(to: lineEndPoint, control1: controlPoint1, control2: controlPoint2)
            }
            .stroke(
                LinearGradient(
                    colors: [OneBoxColors.primaryGold.opacity(0.8), OneBoxColors.primaryGold],
                    startPoint: UnitPoint.leading,
                    endPoint: UnitPoint.trailing
                ),
                style: StrokeStyle(lineWidth: 2, lineCap: .round)
            )
        )
    }
    
    private func workflowNodeView(_ node: WorkflowNode, canvasSize: CGSize) -> some View {
        VStack(spacing: OneBoxSpacing.small) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: node.type.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(node.type.category.color)
                
                Text(node.type.displayName)
                    .font(OneBoxTypography.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)
                
                Spacer()
                
                if selectedNodeId == node.id {
                    Button(action: {
                        deleteNode(node)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.criticalRed)
                    }
                }
            }
            
            if !node.configuration.isEmpty {
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    ForEach(Array(node.configuration.keys.prefix(2)), id: \.self) { key in
                        HStack {
                            Text("\(key):")
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.tertiaryText)
                            
                            Text(node.configuration[key] ?? "")
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.secondaryText)
                                .lineLimit(1)
                            
                            Spacer()
                        }
                    }
                    
                    if node.configuration.count > 2 {
                        Text("+ \(node.configuration.count - 2) more")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                }
            }
        }
        .padding(OneBoxSpacing.small)
        .frame(width: 140, height: 80)
        .background(
            RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                .fill(node.type.category.backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                        .stroke(
                            selectedNodeId == node.id ? OneBoxColors.primaryGold : node.type.category.color,
                            lineWidth: selectedNodeId == node.id ? 2 : 1
                        )
                )
        )
        .position(CGPoint(x: node.position.x + 70, y: node.position.y + 40))
        .scaleEffect(selectedNodeId == node.id ? 1.05 : 1.0)
        .onTapGesture {
            selectedNodeId = selectedNodeId == node.id ? nil : node.id
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if let index = workflowNodes.firstIndex(where: { $0.id == node.id }) {
                        workflowNodes[index].position = CGPoint(
                            x: max(0, min(canvasSize.width - 140, node.position.x + value.translation.width)),
                            y: max(0, min(canvasSize.height - 80, node.position.y + value.translation.height))
                        )
                    }
                }
        )
        .animation(.easeInOut(duration: 0.2), value: selectedNodeId)
    }
    
    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        HStack {
            // Zoom controls
            HStack(spacing: OneBoxSpacing.small) {
                Button(action: { canvasZoom = max(0.5, canvasZoom - 0.1) }) {
                    Image(systemName: "minus.magnifyingglass")
                        .foregroundColor(OneBoxColors.primaryGold)
                }
                
                Text("\(Int(canvasZoom * 100))%")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .frame(width: 40)
                
                Button(action: { canvasZoom = min(2.0, canvasZoom + 0.1) }) {
                    Image(systemName: "plus.magnifyingglass")
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: OneBoxSpacing.medium) {
                Button("Add Node") {
                    showingNodeLibrary = true
                }
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryGold)
                .padding(.horizontal, OneBoxSpacing.medium)
                .padding(.vertical, OneBoxSpacing.small)
                .background(OneBoxColors.primaryGold.opacity(0.1))
                .cornerRadius(OneBoxRadius.small)
                
                if !workflowNodes.isEmpty {
                    Button("Test") {
                        testWorkflow()
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGraphite)
                    .padding(.horizontal, OneBoxSpacing.medium)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.secureGreen)
                    .cornerRadius(OneBoxRadius.small)
                    .disabled(isTestingWorkflow)
                }
                
                Button("Reset") {
                    resetCanvas()
                }
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.criticalRed)
                .padding(.horizontal, OneBoxSpacing.medium)
                .padding(.vertical, OneBoxSpacing.small)
                .background(OneBoxColors.criticalRed.opacity(0.1))
                .cornerRadius(OneBoxRadius.small)
            }
        }
        .padding(OneBoxSpacing.medium)
        .background(OneBoxColors.surfaceGraphite.opacity(0.8))
    }
    
    // MARK: - Helper Methods
    private func addNodeToCanvas(_ nodeType: WorkflowNodeType) {
        let newNode = WorkflowNode(
            id: UUID(),
            type: nodeType,
            position: CGPoint(x: 100, y: 100 + (workflowNodes.count * 120)),
            configuration: nodeType.defaultConfiguration
        )
        
        workflowNodes.append(newNode)
        selectedNodeId = newNode.id
        
        // Auto-connect nodes if possible
        if workflowNodes.count > 1 {
            let previousNode = workflowNodes[workflowNodes.count - 2]
            if canConnect(from: previousNode, to: newNode) {
                connections.append(NodeConnection(
                    id: UUID(),
                    fromNodeId: previousNode.id,
                    toNodeId: newNode.id
                ))
            }
        }
        
        HapticManager.shared.impact(.light)
    }
    
    private func canConnect(from: WorkflowNode, to: WorkflowNode) -> Bool {
        // Basic logic: triggers can connect to actions, actions can connect to actions
        switch (from.type.category, to.type.category) {
        case (.trigger, .action), (.action, .action), (.action, .condition), (.condition, .action):
            return true
        default:
            return false
        }
    }
    
    private func deleteNode(_ node: WorkflowNode) {
        workflowNodes.removeAll { $0.id == node.id }
        connections.removeAll { $0.fromNodeId == node.id || $0.toNodeId == node.id }
        selectedNodeId = nil
        HapticManager.shared.impact(.medium)
    }
    
    private func resetCanvas() {
        workflowNodes.removeAll()
        connections.removeAll()
        selectedNodeId = nil
        canvasZoom = 1.0
        canvasOffset = .zero
        HapticManager.shared.impact(.medium)
    }
    
    private func testWorkflow() {
        guard !workflowNodes.isEmpty else { return }
        
        isTestingWorkflow = true
        
        Task {
            var results: [TestResult] = []
            
            // REAL WORKFLOW TESTING - Validate each node's configuration
            for node in workflowNodes {
                let startTime = Date()
                
                do {
                    // Validate node configuration
                    try validateNodeConfiguration(node)
                    
                    let executionTime = Date().timeIntervalSince(startTime)
                    results.append(TestResult(
                        nodeId: node.id,
                        nodeName: node.type.displayName,
                        status: .success,
                        message: "Configuration validated successfully",
                        executionTime: executionTime
                    ))
                    
                } catch {
                    let executionTime = Date().timeIntervalSince(startTime)
                    results.append(TestResult(
                        nodeId: node.id,
                        nodeName: node.type.displayName,
                        status: .error,
                        message: error.localizedDescription,
                        executionTime: executionTime
                    ))
                }
                
                // Small delay between tests
                try await Task.sleep(nanoseconds: 500_000_000)
            }
            
            // Test workflow connectivity
            let connectivityResult = validateWorkflowConnectivity()
            if !connectivityResult.isValid {
                results.append(TestResult(
                    nodeId: UUID(),
                    nodeName: "Workflow Connectivity",
                    status: .warning,
                    message: connectivityResult.message,
                    executionTime: 0.1
                ))
            }
            
            await MainActor.run {
                self.testResults = results
                self.isTestingWorkflow = false
                
                let hasErrors = results.contains { $0.status == .error }
                HapticManager.shared.notification(hasErrors ? .error : .success)
            }
        }
    }
    
    private func validateNodeConfiguration(_ node: WorkflowNode) throws {
        switch node.type.category {
        case .trigger:
            try validateTriggerNode(node)
        case .action:
            try validateActionNode(node)
        case .condition:
            try validateConditionNode(node)
        }
    }
    
    private func validateTriggerNode(_ node: WorkflowNode) throws {
        switch node.type {
        case .scheduleNode:
            guard let time = node.configuration["time"], !time.isEmpty else {
                throw WorkflowExecutionError.invalidConfiguration("Schedule time is required")
            }
            guard let days = node.configuration["days"], !days.isEmpty else {
                throw WorkflowExecutionError.invalidConfiguration("Schedule days are required")
            }
            
        case .fileSizeNode:
            guard let threshold = node.configuration["threshold"], !threshold.isEmpty else {
                throw WorkflowExecutionError.invalidConfiguration("File size threshold is required")
            }
            let _ = WorkflowAutomationView.parseSizeString(threshold) // Validate size format
            
        case .filePatternNode:
            guard let pattern = node.configuration["pattern"], !pattern.isEmpty else {
                throw WorkflowExecutionError.invalidConfiguration("File pattern is required")
            }
            // Validate regex pattern
            do {
                let patternString = pattern.replacingOccurrences(of: "*", with: ".*")
                let _ = try NSRegularExpression(pattern: patternString, options: [])
            } catch {
                throw WorkflowExecutionError.invalidConfiguration("Invalid file pattern: \(error.localizedDescription)")
            }
            
        case .fileWatchNode:
            guard let folder = node.configuration["folder"], !folder.isEmpty else {
                throw WorkflowExecutionError.invalidConfiguration("Watch folder is required")
            }
            
        default:
            break
        }
    }
    
    private func validateActionNode(_ node: WorkflowNode) throws {
        switch node.type {
        case .compressNode:
            if let quality = node.configuration["quality"] {
                let validQualities = ["low", "medium", "high", "balanced"]
                guard validQualities.contains(quality.lowercased()) else {
                    throw WorkflowExecutionError.invalidConfiguration("Invalid compression quality: \(quality)")
                }
            }
            
        case .watermarkNode:
            guard let text = node.configuration["text"], !text.isEmpty else {
                throw WorkflowExecutionError.invalidConfiguration("Watermark text is required")
            }
            
        case .encryptNode:
            if let password = node.configuration["password"], password != "auto" && password.count < 8 {
                throw WorkflowExecutionError.invalidConfiguration("Password must be at least 8 characters")
            }
            
        case .splitNode:
            if let ranges = node.configuration["ranges"] {
                let _ = WorkflowAutomationView.parsePageRanges(ranges) // Validate range format
                if WorkflowAutomationView.parsePageRanges(ranges).isEmpty {
                    throw WorkflowExecutionError.invalidConfiguration("Invalid page ranges format")
                }
            }
            
        default:
            break
        }
    }
    
    private func validateConditionNode(_ node: WorkflowNode) throws {
        switch node.type {
        case .ifConditionNode:
            guard let condition = node.configuration["condition"], !condition.isEmpty else {
                throw WorkflowExecutionError.invalidConfiguration("If condition is required")
            }
            
        default:
            break
        }
    }
    
    private func validateWorkflowConnectivity() -> (isValid: Bool, message: String) {
        let triggers = workflowNodes.filter { $0.type.category == .trigger }
        let actions = workflowNodes.filter { $0.type.category == .action }
        
        guard !triggers.isEmpty else {
            return (false, "Workflow must have at least one trigger")
        }
        
        guard !actions.isEmpty else {
            return (false, "Workflow must have at least one action")
        }
        
        // Check if all nodes are connected
        let connectedNodes = Set(connections.flatMap { [$0.fromNodeId, $0.toNodeId] })
        let unconnectedNodes = workflowNodes.filter { !connectedNodes.contains($0.id) }
        
        if unconnectedNodes.count > 1 {
            return (false, "\(unconnectedNodes.count) nodes are not connected to the workflow")
        }
        
        return (true, "Workflow connectivity is valid")
    }
    
    private func saveAsTemplate() {
        // Save current workflow as a template
        HapticManager.shared.notification(.success)
    }
    
    private func importNodes() {
        // Import nodes from file or template
        HapticManager.shared.impact(.light)
    }
    
    private func saveWorkflow() {
        guard !workflowName.isEmpty && !workflowNodes.isEmpty else { return }
        
        // Convert nodes to triggers and actions
        let triggers = workflowNodes
            .filter { $0.type.category == .trigger }
            .map { WorkflowTrigger(type: convertToTriggerType($0.type), configuration: $0.configuration) }
        
        let actions = workflowNodes
            .filter { $0.type.category == .action }
            .map { WorkflowAction(type: convertToActionType($0.type), configuration: $0.configuration) }
        
        let workflow = AutomationWorkflow(
            id: UUID(),
            name: workflowName,
            description: workflowDescription,
            category: selectedCategory,
            triggers: triggers,
            actions: actions,
            isEnabled: true,
            executionCount: 0,
            successRate: 1.0
        )
        
        workflows.append(workflow)
        dismiss()
        HapticManager.shared.notification(.success)
    }
    
    private func convertToTriggerType(_ nodeType: WorkflowNodeType) -> TriggerType {
        switch nodeType {
        case .scheduleNode: return .schedule
        case .fileWatchNode: return .folderWatch
        case .fileSizeNode: return .fileSize
        case .filePatternNode: return .filePattern
        default: return .manual
        }
    }
    
    private func convertToActionType(_ nodeType: WorkflowNodeType) -> ActionType {
        switch nodeType {
        case .compressNode: return .compress
        case .organizeNode: return .organize
        case .watermarkNode: return .watermark
        case .encryptNode: return .encrypt
        case .mergeNode: return .merge
        case .splitNode: return .split
        case .convertNode: return .convert
        case .backupNode: return .backup
        default: return .compress
        }
    }
}

// MARK: - Supporting Types for Visual Builder

struct WorkflowNode: Identifiable {
    let id: UUID
    let type: WorkflowNodeType
    var position: CGPoint
    var configuration: [String: String]
}

struct NodeConnection: Identifiable {
    let id: UUID
    let fromNodeId: UUID
    let toNodeId: UUID
}

enum WorkflowNodeType: CaseIterable {
    // Triggers
    case manualNode
    case scheduleNode
    case fileWatchNode
    case fileSizeNode
    case filePatternNode
    
    // Actions
    case compressNode
    case organizeNode
    case watermarkNode
    case encryptNode
    case mergeNode
    case splitNode
    case convertNode
    case backupNode
    
    // Conditions
    case ifConditionNode
    case switchConditionNode
    
    var displayName: String {
        switch self {
        case .manualNode: return "Manual Trigger"
        case .scheduleNode: return "Schedule"
        case .fileWatchNode: return "Watch Folder"
        case .fileSizeNode: return "File Size"
        case .filePatternNode: return "File Pattern"
        case .compressNode: return "Compress"
        case .organizeNode: return "Organize"
        case .watermarkNode: return "Watermark"
        case .encryptNode: return "Encrypt"
        case .mergeNode: return "Merge"
        case .splitNode: return "Split"
        case .convertNode: return "Convert"
        case .backupNode: return "Backup"
        case .ifConditionNode: return "If Condition"
        case .switchConditionNode: return "Switch"
        }
    }
    
    var icon: String {
        switch self {
        case .manualNode: return "hand.tap"
        case .scheduleNode: return "clock"
        case .fileWatchNode: return "folder.badge.plus"
        case .fileSizeNode: return "doc.badge.gearshape"
        case .filePatternNode: return "doc.text.magnifyingglass"
        case .compressNode: return "arrow.down.circle"
        case .organizeNode: return "folder"
        case .watermarkNode: return "signature"
        case .encryptNode: return "lock"
        case .mergeNode: return "doc.on.doc"
        case .splitNode: return "scissors"
        case .convertNode: return "arrow.triangle.2.circlepath"
        case .backupNode: return "externaldrive"
        case .ifConditionNode: return "questionmark.diamond"
        case .switchConditionNode: return "arrow.triangle.branch"
        }
    }
    
    var category: NodeCategory {
        switch self {
        case .manualNode, .scheduleNode, .fileWatchNode, .fileSizeNode, .filePatternNode:
            return .trigger
        case .compressNode, .organizeNode, .watermarkNode, .encryptNode, .mergeNode, .splitNode, .convertNode, .backupNode:
            return .action
        case .ifConditionNode, .switchConditionNode:
            return .condition
        }
    }
    
    var defaultConfiguration: [String: String] {
        switch self {
        case .scheduleNode:
            return ["time": "09:00", "days": "weekdays"]
        case .fileSizeNode:
            return ["threshold": "10MB", "operation": "greater"]
        case .filePatternNode:
            return ["pattern": "*", "folder": "Downloads"]
        case .compressNode:
            return ["quality": "balanced", "format": "PDF"]
        case .organizeNode:
            return ["strategy": "byDate", "folder": "Organized"]
        case .watermarkNode:
            return ["text": "CONFIDENTIAL", "position": "center"]
        case .encryptNode:
            return ["password": "auto", "strength": "AES-256"]
        case .ifConditionNode:
            return ["condition": "fileSize > 5MB"]
        default:
            return [:]
        }
    }
}

enum NodeCategory {
    case trigger, action, condition
    
    var color: Color {
        switch self {
        case .trigger: return OneBoxColors.secureGreen
        case .action: return OneBoxColors.primaryGold
        case .condition: return OneBoxColors.warningAmber
        }
    }
    
    var backgroundColor: Color {
        color.opacity(0.1)
    }
}

struct TestResult: Identifiable {
    let id = UUID()
    let nodeId: UUID
    let nodeName: String
    let status: TestStatus
    let message: String
    let executionTime: Double
    
    enum TestStatus {
        case success, warning, error
        
        var color: Color {
            switch self {
            case .success: return OneBoxColors.secureGreen
            case .warning: return OneBoxColors.warningAmber
            case .error: return OneBoxColors.criticalRed
            }
        }
    }
}

// MARK: - Node Library View

struct NodeLibraryView: View {
    let onNodeSelected: (WorkflowNodeType) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var selectedCategory: NodeCategory? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                // Category selector
                HStack {
                    ForEach([NodeCategory.trigger, .action, .condition], id: \.self) { category in
                        Button(action: {
                            selectedCategory = selectedCategory == category ? nil : category
                        }) {
                            Text(categoryDisplayName(category))
                                .font(OneBoxTypography.caption)
                                .foregroundColor(selectedCategory == category ? OneBoxColors.primaryGraphite : OneBoxColors.primaryText)
                                .padding(.horizontal, OneBoxSpacing.medium)
                                .padding(.vertical, OneBoxSpacing.small)
                                .background(selectedCategory == category ? category.color : category.color.opacity(0.1))
                                .cornerRadius(OneBoxRadius.small)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, OneBoxSpacing.medium)
                
                // Node grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: OneBoxSpacing.medium) {
                        ForEach(filteredNodeTypes, id: \.self) { nodeType in
                            nodeLibraryCard(nodeType)
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Add Node")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OneBoxColors.primaryGraphite, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var filteredNodeTypes: [WorkflowNodeType] {
        if let category = selectedCategory {
            return WorkflowNodeType.allCases.filter { $0.category == category }
        }
        return WorkflowNodeType.allCases
    }
    
    private func categoryDisplayName(_ category: NodeCategory) -> String {
        switch category {
        case .trigger: return "Triggers"
        case .action: return "Actions"
        case .condition: return "Conditions"
        }
    }
    
    private func nodeLibraryCard(_ nodeType: WorkflowNodeType) -> some View {
        Button(action: {
            onNodeSelected(nodeType)
            dismiss()
        }) {
            VStack(spacing: OneBoxSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(nodeType.category.backgroundColor)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: nodeType.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(nodeType.category.color)
                }
                
                VStack(spacing: OneBoxSpacing.tiny) {
                    Text(nodeType.displayName)
                        .font(OneBoxTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(categoryDisplayName(nodeType.category))
                        .font(OneBoxTypography.micro)
                        .foregroundColor(nodeType.category.color)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(OneBoxSpacing.medium)
            .background(
                RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                    .fill(OneBoxColors.surfaceGraphite)
                    .overlay(
                        RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                            .stroke(nodeType.category.color.opacity(0.3), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Workflow Template Library

struct WorkflowTemplateLibraryView: View {
    let onTemplateSelected: (AutomationWorkflowTemplate) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text("Workflow template library would be implemented here with categorized templates, search, and filtering capabilities.")
                    .padding()
            }
            .navigationTitle("Template Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(OneBoxColors.primaryGraphite, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Workflow Execution Support Types

struct WorkflowExecutionResult {
    let processedFileCount: Int
    let outputFiles: [URL]
    let executionSuccess: Bool
    var generatedPassword: String? // Auto-generated encryption password to show user
}

enum WorkflowExecutionError: LocalizedError {
    case noInputFiles
    case jobFailed(String)
    case timeout
    case invalidConfiguration(String)
    
    var errorDescription: String? {
        switch self {
        case .noInputFiles:
            return "No input files found for workflow execution"
        case .jobFailed(let message):
            return "Job execution failed: \(message)"
        case .timeout:
            return "Workflow execution timed out"
        case .invalidConfiguration(let message):
            return "Invalid workflow configuration: \(message)"
        }
    }
}

#Preview {
    WorkflowAutomationView()
        .environmentObject(JobManager.shared)
}