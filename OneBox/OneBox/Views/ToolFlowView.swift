//
//  ToolFlowView.swift
//  OneBox
//
//  Universal tool flow: Select Input → Configure → Process → Result
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CommonTypes
import JobEngine
import UIComponents
import PDFKit
import Foundation
import UIKit

// Wrapper for URL to make it Identifiable
struct IdentifiableURL: Identifiable {
    let id = UUID()
    let url: URL
}

struct ToolFlowView: View {
    let tool: ToolType

    @Environment(\.dismiss) var dismiss
    @Environment(\.scenePhase) var scenePhase
    @EnvironmentObject var jobManager: JobManager
    @EnvironmentObject var paymentsManager: PaymentsManager

    @State private var step: FlowStep = .selectInput
    @State private var selectedURLs: [URL] = []
    @State private var settings = JobSettings()
    @State private var currentJob: Job?
    @State private var showPaywall = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var pageOrganizerURL: IdentifiableURL?
    @State private var showRedactionView = false
    @State private var showComplimentaryExportModal = false
    @State private var showViewOnlyModeAlert = false
    @State private var showInteractiveSigning = false
    @State private var showRestorationAlert = false

    enum FlowStep {
        case selectInput
        case configure
        case processing
        case exportPreview
        case result
    }

    var body: some View {
        NavigationStack {
            mainContent
        }
        .navigationTitle(tool.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(OneBoxColors.primaryGraphite, for: .navigationBar)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(item: $pageOrganizerURL) { identifiableURL in
            PageOrganizerView(pdfURL: identifiableURL.url)
                .environmentObject(jobManager)
                .environmentObject(paymentsManager)
        }
        .fullScreenCover(isPresented: $showInteractiveSigning) {
            InteractiveSignPDFViewWrapper(
                pdfURL: selectedURLs.first,
                jobManager: jobManager,
                onDismiss: {
                    showInteractiveSigning = false
                },
                onJobSubmitted: { job in
                    // Job was submitted, advance to processing step
                    showInteractiveSigning = false
                    currentJob = job
                    step = .processing
                    paymentsManager.consumeExport()
                    // Observe job completion with error handling
                    observeJobCompletion(job)
                }
            )
        }
        .onChange(of: showInteractiveSigning) { newValue in
            print("🔵 ToolFlowView: showInteractiveSigning changed to \(newValue)")
        }
        .onChange(of: showRedactionView) { newValue in
            print("🔵 ToolFlowView: showRedactionView changed to \(newValue)")
            print("🔵 ToolFlowView: selectedURLs.count at change = \(selectedURLs.count)")
            if let url = selectedURLs.first {
                print("🔵 ToolFlowView: URL at change = \(url.absoluteString)")
            }
        }
        .fullScreenCover(isPresented: $showRedactionView) {
            Group {
                if let url = selectedURLs.first {
                    RedactionView(pdfURL: url)
                        .environmentObject(jobManager)
                        .environmentObject(paymentsManager)
                        .onAppear {
                            print("🔵 ToolFlowView: RedactionView appeared with URL: \(url.absoluteString)")
                        }
                } else {
                    // Fallback view if URL is missing
                    VStack(spacing: OneBoxSpacing.large) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 48))
                            .foregroundColor(OneBoxColors.warningAmber)

                        Text("Error: No PDF selected")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)

                        Text("Please go back and select a PDF file")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.secondaryText)

                        Button("Dismiss") {
                            showRedactionView = false
                        }
                        .foregroundColor(OneBoxColors.primaryGold)
                        .padding(.top, OneBoxSpacing.medium)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(OneBoxColors.primaryGraphite.ignoresSafeArea())
                    .onAppear {
                        print("❌ ToolFlowView: RedactionView fullScreenCover triggered but selectedURLs.first is nil!")
                        print("❌ ToolFlowView: selectedURLs.count = \(selectedURLs.count)")
                    }
                }
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showComplimentaryExportModal) {
            ComplimentaryExportModal(
                onContinue: {
                    showComplimentaryExportModal = false
                    proceedWithExportAfterComplimentary()
                },
                onUpgrade: {
                    showComplimentaryExportModal = false
                    showPaywall = true
                }
            )
        }
        .alert("View-Only Mode", isPresented: $showViewOnlyModeAlert) {
            Button("Upgrade to Pro", role: .none) {
                showPaywall = true
            }
            Button("OK", role: .cancel) {}
        } message: {
            Text("You've reached your daily free export limit. Upgrade to Pro for unlimited exports, or wait until tomorrow. You can still view and manage your existing files.")
        }
        .alert("Continue Where You Left Off?", isPresented: $showRestorationAlert) {
            Button("Continue", role: .none) {
                restoreState()
            }
            Button("Start Fresh", role: .cancel) {
                WorkflowStateManager.shared.clearState()
            }
        } message: {
            Text("You have unsaved work from a previous session. Would you like to continue?")
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background || newPhase == .inactive {
                // Save state when going to background
                saveCurrentState()
            }
        }
        .onAppear {
            // Check for restored state on appear
            checkForRestoredState()
            // Mark session as active
            WorkflowStateManager.shared.markSessionActive()
        }
        .onDisappear {
            // Clear state when view is dismissed normally (task complete)
            if step == .result {
                WorkflowStateManager.shared.markSessionComplete()
            }
        }
    }

    // MARK: - State Persistence

    private func saveCurrentState() {
        // Only save if we have meaningful state to restore
        guard !selectedURLs.isEmpty || step != .selectInput else { return }

        let stepName: String
        switch step {
        case .selectInput: stepName = "selectInput"
        case .configure: stepName = "configure"
        case .processing: stepName = "processing"
        case .exportPreview: stepName = "exportPreview"
        case .result: stepName = "result"
        }

        WorkflowStateManager.shared.saveToolFlowState(
            tool: tool.rawValue,
            selectedURLs: selectedURLs,
            step: stepName
        )
    }

    private func checkForRestoredState() {
        guard let state = WorkflowStateManager.shared.restoreToolFlowState(),
              state.toolType == tool.rawValue else {
            return
        }

        // Only offer restoration if there's meaningful state
        let urls = state.selectedURLPaths.compactMap { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        if !urls.isEmpty {
            showRestorationAlert = true
        }
    }

    private func restoreState() {
        guard let state = WorkflowStateManager.shared.restoreToolFlowState() else { return }

        // Restore selected URLs
        selectedURLs = state.selectedURLPaths.compactMap { URL(fileURLWithPath: $0) }
            .filter { FileManager.default.fileExists(atPath: $0.path) }

        // Restore step (only restore to selectInput or configure, not processing states)
        switch state.currentStep {
        case "configure":
            if !selectedURLs.isEmpty {
                step = .configure
            }
        default:
            // Stay on selectInput for other states
            break
        }

        print("♻️ ToolFlowView: Restored state with \(selectedURLs.count) files")
    }
    
    private var mainContent: some View {
        ZStack {
            OneBoxColors.primaryGraphite.ignoresSafeArea()
            stepContent
        }
    }
    
    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .selectInput:
            InputSelectionView(
                tool: tool,
                selectedURLs: $selectedURLs,
                onContinue: handleContinue
            )
        case .configure:
            ConfigurationView(
                tool: tool,
                settings: $settings,
                selectedURLs: selectedURLs,
                onProcess: processFiles
            )
        case .processing:
            ProcessingView(job: currentJob)
        case .exportPreview:
            if let job = currentJob, !job.outputURLs.isEmpty {
                ExportPreviewView(
                    outputURLs: job.outputURLs,
                    exportTitle: tool.displayName,
                    originalSize: calculateOriginalSize(),
                    onConfirm: {
                        step = .result
                    },
                    onCancel: {
                        dismiss()
                    }
                )
            }
        case .result:
            if let job = currentJob {
                JobResultView(job: job)
            }
        }
    }
    
    private func handleContinue() {
        print("🔵 ToolFlowView: onContinue called")
        print("🔵 ToolFlowView: tool = \(tool)")
        print("🔵 ToolFlowView: selectedURLs.count = \(selectedURLs.count)")
        if let firstURL = selectedURLs.first {
            print("🔵 ToolFlowView: First URL = \(firstURL.absoluteString)")
            print("🔵 ToolFlowView: File exists = \(FileManager.default.fileExists(atPath: firstURL.path))")
        }

        if tool == .pdfOrganize {
            if let url = selectedURLs.first {
                pageOrganizerURL = IdentifiableURL(url: url)
            }
        } else if tool == .pdfRedact {
            if !selectedURLs.isEmpty {
                print("🔵 ToolFlowView: Setting showRedactionView = true")
                showRedactionView = true
            }
        } else if tool == .pdfSign {
            if !selectedURLs.isEmpty {
                print("🔵 ToolFlowView: Setting showInteractiveSigning = true")
                print("🔵 ToolFlowView: selectedURLs.count = \(selectedURLs.count)")
                print("🔵 ToolFlowView: First URL = \(selectedURLs.first?.absoluteString ?? "nil")")
                showInteractiveSigning = true
            } else {
                print("❌ ToolFlowView: No URLs selected for PDF signing")
            }
        } else {
            step = .configure
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            leadingToolbarItem
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingToolbarItem
        }
    }
    
    @ViewBuilder
    private var leadingToolbarItem: some View {
        if step == .selectInput {
            Button("Cancel") {
                dismiss()
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }
            .foregroundColor(OneBoxColors.primaryText)
        } else if step == .configure {
            Button(action: {
                step = .selectInput
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
            }) {
                HStack(spacing: OneBoxSpacing.tiny) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .medium))
                    Text("Back")
                        .font(OneBoxTypography.caption)
                }
                .foregroundColor(OneBoxColors.primaryText)
            }
        } else if step == .exportPreview {
            EmptyView()
        }
    }
    
    @ViewBuilder
    private var trailingToolbarItem: some View {
        if step == .selectInput || step == .configure {
            SecurityBadge(style: .minimal)
        }
    }

    func processFiles() {
        // Check if user is in view-only mode
        if paymentsManager.canViewOnly {
            showViewOnlyModeAlert = true
            return
        }
        
        // Check if this is the last free export - show complimentary modal
        if paymentsManager.isLastFreeExport {
            showComplimentaryExportModal = true
            return
        }
        
        // Check if user can export
        guard paymentsManager.canExport else {
            showPaywall = true
            return
        }
        
        proceedWithProcessing()
    }
    
    func proceedWithProcessing() {
        // Create job immediately (non-blocking)
        let jobType: JobType
        switch tool {
        case .imagesToPDF: jobType = .imagesToPDF
        case .pdfToImages: jobType = .pdfToImages
        case .pdfMerge: jobType = .pdfMerge
        case .pdfSplit: jobType = .pdfSplit
        case .pdfCompress: jobType = .pdfCompress
        case .pdfWatermark: jobType = .pdfWatermark
        case .pdfSign: jobType = .pdfSign
        case .pdfOrganize: jobType = .pdfOrganize
        case .imageResize: jobType = .imageResize
        case .pdfRedact: jobType = .pdfRedact
        }

        let job = Job(
            type: jobType,
            inputs: selectedURLs,
            settings: settings
        )

        currentJob = job
        Task {
            await jobManager.submitJob(job)
        }
        paymentsManager.consumeExport()
        step = .processing
        observeJobCompletion(job)
        
        // Validate file sizes in background (non-blocking, for warnings only)
        Task(priority: .utility) {
            var hasLargeFileWarning = false
            var validationErrors: [String] = []
            
            // Determine operation type for memory validation
            let operationType: OperationType
            switch tool {
            case .pdfCompress, .pdfWatermark, .pdfSign, .pdfRedact:
                operationType = .pdfCompress
            case .pdfMerge:
                operationType = .pdfMerge
            case .pdfSplit, .pdfToImages, .pdfOrganize:
                operationType = .pdfRead
            case .imagesToPDF, .imageResize:
                operationType = .imageProcess
            }
            
            // Validate each file (quick check, don't block)
            for url in selectedURLs {
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let fileSize = attributes[.size] as? Int64 {
                    let validation = await MainActor.run {
                        MemoryManager.shared.validateFileSize(fileSize: fileSize, operationType: operationType)
                    }
                    
                    if !validation.canProcess {
                        validationErrors.append("\(url.lastPathComponent): \(validation.recommendation)")
                    } else if validation.warningLevel == .high || validation.warningLevel == .critical {
                        hasLargeFileWarning = true
                    }
                }
            }
            
            // Only show errors if critical (processing will fail anyway)
            if !validationErrors.isEmpty {
                await MainActor.run {
                    // Log warning but don't block - processing will fail with better error from CorePDF
                    print("⚠️ ToolFlowView: Memory validation warning: \(validationErrors.joined(separator: ", "))")
                }
            } else if hasLargeFileWarning {
                await MainActor.run {
                    print("⚠️ ToolFlowView: Large file warning - proceeding with caution")
                }
            }
        }
    }
    
    func proceedWithExportAfterComplimentary() {
        // User confirmed they want to use their last free export
        proceedWithProcessing()
    }

    func observeJobCompletion(_ job: Job) {
        Task {
            while step == .processing {
                if let updatedJob = jobManager.jobs.first(where: { $0.id == job.id }) {
                    currentJob = updatedJob

                    if updatedJob.status == .success {
                        // JobEngine now handles saving to Documents/Exports automatically
                        await MainActor.run {
                            step = .exportPreview
                        }
                        break
                    } else if updatedJob.status == .failed {
                        await MainActor.run {
                            errorMessage = updatedJob.error ?? "Unknown error"
                            showError = true
                            // Don't dismiss on error - let user see the error and retry
                            step = .selectInput // Go back to input selection
                        }
                        break
                    } else if updatedJob.progress >= 1.0 && updatedJob.status == .running {
                        // Handle case where progress reaches 100% but status hasn't updated yet
                        // Wait a bit longer for status to update to .success
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0s additional wait
                        if let finalJob = jobManager.jobs.first(where: { $0.id == job.id }),
                           finalJob.status == .success {
                            await MainActor.run {
                                currentJob = finalJob
                                step = .exportPreview
                            }
                            break
                        }
                    }
                }

                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
            }
        }
    }

    func calculateOriginalSize() -> Int64 {
        var totalSize: Int64 = 0
        for url in selectedURLs {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let size = attributes[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }
}

// MARK: - Interactive Sign PDF View Wrapper
struct InteractiveSignPDFViewWrapper: View {
    let pdfURL: URL?
    let jobManager: JobManager
    let onDismiss: () -> Void
    let onJobSubmitted: (Job) -> Void
    
    var body: some View {
        Group {
            if let pdfURL = pdfURL {
                InteractiveSignPDFView(
                    pdfURL: pdfURL,
                    onJobSubmitted: onJobSubmitted
                )
                .environmentObject(jobManager)
                .onAppear {
                    print("🔵 ToolFlowView: fullScreenCover presenting InteractiveSignPDFView with URL: \(pdfURL)")
                }
            } else {
                // Fallback view if URL is missing
                VStack {
                    Text("Error: No PDF selected")
                        .foregroundColor(OneBoxColors.primaryText)
                    Button("Dismiss") {
                        onDismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(OneBoxColors.primaryGraphite)
                .onAppear {
                    print("❌ ToolFlowView: fullScreenCover triggered but selectedURLs.first is nil!")
                }
            }
        }
    }
}

// MARK: - Input Selection View
struct InputSelectionView: View {
    let tool: ToolType
    @Binding var selectedURLs: [URL]
    let onContinue: () -> Void

    @State private var showImagePicker = false
    @State private var showFilePicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var preflightInsights: [PreflightInsight] = []
    @State private var showingWorkflowHooks = false
    @State private var isEditingOrder = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        VStack(spacing: 20) {
            if selectedURLs.isEmpty {
                emptyState
            } else {
                filesList
            }

            Spacer()

            continueButton
        }
        .padding()
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotos,
            maxSelectionCount: maxSelectionCount,
            matching: photosFilter
        )
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: allowedFileTypes,
            allowsMultipleSelection: allowsMultipleSelection
        ) { result in
            handleFileImport(result)
        }
        .onChange(of: selectedPhotos) { newPhotos in
            loadPhotos(newPhotos)
        }
        .onChange(of: selectedURLs) { _ in
            analyzeSelectedFiles() // Analyze files when selection changes
        }
        .onAppear {
            analyzeSelectedFiles() // Initial analysis
        }
        .sheet(isPresented: $showingWorkflowHooks) {
            WorkflowHooksView(selectedURLs: selectedURLs, tool: tool)
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let errorMessage = errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Pre-flight Insights
    private var preflightInsightsBanner: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
            ForEach(preflightInsights) { insight in
                OneBoxCard(style: insight.severity == .high ? .security : .standard) {
                    HStack(spacing: OneBoxSpacing.medium) {
                        Image(systemName: insight.icon)
                            .foregroundColor(insight.severity.color)
                            .frame(width: 24)
                        
                        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                            Text(insight.title)
                                .font(OneBoxTypography.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Text(insight.message)
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        if let action = insight.action {
                            Button(action: action) {
                                Text(insight.actionTitle ?? "Fix")
                                    .font(OneBoxTypography.micro)
                                    .foregroundColor(OneBoxColors.primaryGold)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private var workflowHooksBanner: some View {
        OneBoxCard(style: .interactive) {
            HStack {
                Image(systemName: "gear.badge.checkmark")
                    .foregroundColor(OneBoxColors.primaryGold)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text("Create Workflow")
                        .font(OneBoxTypography.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text("Bundle these files into a multi-step workflow")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
                
                Button(action: {
                    showingWorkflowHooks = true
                }) {
                    Text("Open")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
    }
    
    private func moveImages(from source: IndexSet, to destination: Int) {
        selectedURLs.move(fromOffsets: source, toOffset: destination)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
    
    private func analyzeSelectedFiles() {
        var insights: [PreflightInsight] = []
        
        // Analyze each selected file (on-device only)
        for url in selectedURLs {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
               let fileSize = attributes[.size] as? Int64 {
                
                // Large file detection
                if fileSize > 20_000_000 { // >20MB
                    insights.append(PreflightInsight(
                        id: "large-\(url.lastPathComponent)",
                        title: "Large File Detected",
                        message: "\(url.lastPathComponent) is \(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)). Consider compression.",
                        icon: "arrow.down.circle.fill",
                        severity: .medium,
                        actionTitle: "Compress",
                        action: {
                            // Navigate to compression tool
                            // This would need navigation context
                        }
                    ))
                }
                
                // Check file type compatibility
                let pathExtension = url.pathExtension.lowercased()
                if tool == .pdfCompress && pathExtension != "pdf" {
                    insights.append(PreflightInsight(
                        id: "incompatible-\(url.lastPathComponent)",
                        title: "Incompatible File Type",
                        message: "\(url.lastPathComponent) is not a PDF file.",
                        icon: "exclamationmark.triangle.fill",
                        severity: .high,
                        actionTitle: nil,
                        action: nil
                    ))
                }
            }
        }
        
        // Multiple files insight
        if selectedURLs.count > 5 {
            insights.append(PreflightInsight(
                id: "multiple-files",
                title: "Multiple Files Selected",
                message: "You've selected \(selectedURLs.count) files. Consider using a workflow for batch processing.",
                icon: "doc.on.doc.fill",
                severity: .low,
                actionTitle: "Create Workflow",
                action: {
                    showingWorkflowHooks = true
                }
            ))
        }
        
        preflightInsights = insights
    }

    private var emptyState: some View {
        OneBoxCard(style: .elevated) {
            VStack(spacing: OneBoxSpacing.xxl) {
                // Hero Icon with Ceremony
                VStack(spacing: OneBoxSpacing.medium) {
                    ZStack {
                        Circle()
                            .fill(OneBoxColors.primaryGold.opacity(0.1))
                            .frame(width: 120, height: 120)
                        
                        Circle()
                            .stroke(OneBoxColors.primaryGold.opacity(0.3), lineWidth: 2)
                            .frame(width: 120, height: 120)
                        
                        Image(systemName: tool.icon)
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                    
                    // Security Badge Integration
                    HStack(spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(OneBoxColors.secureGreen)
                        
                        Text("On-Device Processing")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secureGreen)
                    }
                    .padding(.horizontal, OneBoxSpacing.small)
                    .padding(.vertical, OneBoxSpacing.tiny)
                    .background(OneBoxColors.secureGreen.opacity(0.1))
                    .cornerRadius(OneBoxRadius.small)
                }

                // Luxury Title Section
                VStack(spacing: OneBoxSpacing.small) {
                    Text(emptyStateTitle)
                        .font(OneBoxTypography.heroTitle)
                        .fontWeight(.bold)
                        .foregroundColor(OneBoxColors.primaryText)
                        .tracking(1.0)

                    Text(emptyStateMessage)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, OneBoxSpacing.medium)
                }
                
                // Privacy Assurance
                VStack(spacing: OneBoxSpacing.small) {
                    HStack(spacing: OneBoxSpacing.medium) {
                        privacyFeature("shield.fill", "Private")
                        privacyFeature("lock.fill", "Secure")
                        privacyFeature("eye.slash.fill", "No Tracking")
                    }
                    
                    Text("Your files never leave your device")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.tertiaryText)
                        .italic()
                }

                // Premium Selection Button
                premiumSelectButton
            }
            .padding(OneBoxSpacing.large)
        }
        .frame(maxHeight: .infinity)
    }
    
    private func privacyFeature(_ icon: String, _ title: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(OneBoxColors.primaryGold)
            
            Text(title)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }

    private var filesList: some View {
        Group {
            if tool == .pdfMerge {
                // Use reorderable list for PDF merge
                ReorderableFileListView(
                    urls: $selectedURLs,
                    onRemove: { index in
                        selectedURLs.remove(at: index)
                    },
                    onAddFiles: {
                        if requiresPhotoPicker {
                            showImagePicker = true
                        } else {
                            showFilePicker = true
                        }
                    }
                )
            } else {
                // Use luxury file cards for other tools
                VStack(spacing: OneBoxSpacing.medium) {
                    // File header with security message
                    if !selectedURLs.isEmpty {
                        HStack {
                            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                                Text(tool == .imagesToPDF ? "Images for PDF" : "Selected Files")
                                    .font(OneBoxTypography.cardTitle)
                                    .foregroundColor(OneBoxColors.primaryText)
                                
                                Text("Ready for on-device processing")
                                    .font(OneBoxTypography.caption)
                                    .foregroundColor(OneBoxColors.secureGreen)
                            }
                            
                            Spacer()
                            
                            SecurityBadge(style: .minimal)
                        }
                        .padding(.horizontal, OneBoxSpacing.medium)
                    }
                    
                    // Pre-flight insights banner
                    if !preflightInsights.isEmpty {
                        preflightInsightsBanner
                            .padding(.horizontal, OneBoxSpacing.medium)
                    }
                    
                    // Workflow hooks banner (only show if no preflight insights already show workflow option)
                    if !preflightInsights.contains(where: { $0.actionTitle == "Create Workflow" }) {
                        workflowHooksBanner
                            .padding(.horizontal, OneBoxSpacing.medium)
                    }
                    
                    // Header with edit button for Images to PDF
                    if tool == .imagesToPDF && !selectedURLs.isEmpty {
                        HStack {
                            Spacer()
                            
                            Button(isEditingOrder ? "Done" : "Edit Order") {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isEditingOrder.toggle()
                                }
                                let generator = UISelectionFeedbackGenerator()
                                generator.selectionChanged()
                            }
                            .foregroundColor(OneBoxColors.primaryGold)
                            .font(OneBoxTypography.caption)
                        }
                        .padding(.horizontal, OneBoxSpacing.medium)
                    }
                    
                    // Use List for Image to PDF to enable drag-and-drop, ScrollView for others
                    if tool == .imagesToPDF {
                        List {
                            ForEach(Array(selectedURLs.enumerated()), id: \.offset) { index, url in
                                luxuryFileCard(url: url, index: index) {
                                    selectedURLs.remove(at: index)
                                    let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                                    analyzeSelectedFiles() // Re-analyze after removal
                                }
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(EdgeInsets())
                            }
                            .onMove(perform: isEditingOrder ? moveImages : nil)
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .environment(\.editMode, .constant(isEditingOrder ? .active : .inactive))
                    } else {
                        ScrollView {
                            VStack(spacing: OneBoxSpacing.medium) {
                                ForEach(Array(selectedURLs.enumerated()), id: \.offset) { index, url in
                                    luxuryFileCard(url: url, index: index) {
                                        selectedURLs.remove(at: index)
                                        let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                                        analyzeSelectedFiles() // Re-analyze after removal
                                    }
                                }
                            }
                            .padding(.vertical, OneBoxSpacing.medium)
                        }
                    }
                    
                    selectButton
                        .padding(.horizontal, OneBoxSpacing.medium)
                }
            }
        }
    }

    private var premiumSelectButton: some View {
        OneBoxButton(
            selectedURLs.isEmpty ? "Select Files" : "Add More Files",
            icon: selectedURLs.isEmpty ? "plus.circle.fill" : "plus",
            style: .security
        ) {
            if requiresPhotoPicker {
                showImagePicker = true
            } else {
                showFilePicker = true
            }
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        }
    }
    
    private var selectButton: some View {
        OneBoxButton(
            selectedURLs.isEmpty ? "Select Files" : "Add More",
            icon: "plus.circle.fill",
            style: .primary
        ) {
            if requiresPhotoPicker {
                showImagePicker = true
            } else {
                showFilePicker = true
            }
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }

    private var continueButton: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            if !selectedURLs.isEmpty {
                // File count summary
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(OneBoxColors.secureGreen)
                    
                    Text("\(selectedURLs.count) file\(selectedURLs.count == 1 ? "" : "s") ready for secure processing")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    Spacer()
                }
                .padding(OneBoxSpacing.small)
                .background(OneBoxColors.secureGreen.opacity(0.1))
                .cornerRadius(OneBoxRadius.small)
            }
            
            OneBoxButton(
                "Continue Securely",
                icon: "arrow.right.circle.fill",
                style: .security,
                isDisabled: selectedURLs.isEmpty
            ) {
                onContinue()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    private func luxuryFileCard(url: URL, index: Int, onRemove: @escaping () -> Void) -> some View {
        OneBoxCard(style: .interactive) {
            HStack(spacing: OneBoxSpacing.medium) {
                // File type icon with ceremony OR page number for Image to PDF
                ZStack {
                    Circle()
                        .fill(OneBoxColors.primaryGold.opacity(0.15))
                        .frame(width: 48, height: 48)
                    
                    if tool == .imagesToPDF {
                        // Show page number prominently for Image to PDF
                        ZStack {
                            Circle()
                                .fill(OneBoxColors.primaryGold)
                                .frame(width: 44, height: 44)
                            
                            Text("\(index + 1)")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.white)
                        }
                    } else {
                        Image(systemName: fileIcon(url))
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                // File details
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    HStack {
                        Text(url.lastPathComponent)
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        if tool != .imagesToPDF {
                            Text("#\(index + 1)")
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.tertiaryText)
                                .padding(.horizontal, OneBoxSpacing.tiny)
                                .padding(.vertical, 2)
                                .background(OneBoxColors.surfaceGraphite)
                                .cornerRadius(OneBoxRadius.small)
                        }
                    }
                    
                    HStack(spacing: OneBoxSpacing.small) {
                        Text(fileSizeString(url))
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Security status - simplified to just shield icon for space
                        HStack(spacing: OneBoxSpacing.tiny) {
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 12))
                                .foregroundColor(OneBoxColors.secureGreen)
                        }
                        .padding(.horizontal, OneBoxSpacing.tiny)
                        .padding(.vertical, 2)
                        .background(OneBoxColors.secureGreen.opacity(0.1))
                        .cornerRadius(OneBoxRadius.small)
                    }
                }
                
                // Remove button only
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(OneBoxColors.tertiaryText)
                        .background(Circle().fill(OneBoxColors.primaryGraphite))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .padding(.horizontal, OneBoxSpacing.medium)
    }

    // Helpers
    private var requiresPhotoPicker: Bool {
        tool == .imagesToPDF || tool == .imageResize
    }

    private var allowsMultipleSelection: Bool {
        tool != .pdfSplit && tool != .pdfSign && tool != .pdfOrganize && tool != .pdfToImages && tool != .pdfRedact
    }

    private var maxSelectionCount: Int? {
        if !allowsMultipleSelection {
            return 1
        }
        // Limit image selection to prevent memory crashes
        if tool == .imageResize || tool == .imagesToPDF {
            return 100 // Reasonable limit for batch processing
        }
        return nil
    }

    private var photosFilter: PHPickerFilter {
        .images
    }

    private var allowedFileTypes: [UTType] {
        switch tool {
        case .imagesToPDF, .imageResize:
            return [.image]
        case .pdfMerge, .pdfSplit, .pdfCompress, .pdfWatermark, .pdfSign, .pdfOrganize, .pdfToImages, .pdfRedact:
            return [.pdf]
        }
    }

    private var emptyStateTitle: String {
        switch tool {
        case .imagesToPDF: return "Select Images"
        case .pdfToImages: return "Select PDF"
        case .pdfMerge: return "Select PDFs"
        case .pdfOrganize: return "Select PDF"
        case .imageResize: return "Select Images"
        case .pdfRedact: return "Select PDF"
        default: return "Select Files"
        }
    }

    private var emptyStateMessage: String {
        switch tool {
        case .imagesToPDF: return "Choose one or more images to convert to PDF"
        case .pdfToImages: return "Choose a PDF to extract pages as images"
        case .pdfMerge: return "Choose multiple PDFs to combine"
        case .pdfSplit: return "Choose a PDF to split"
        case .pdfCompress: return "Choose a PDF to compress"
        case .pdfOrganize: return "Choose a PDF to organize pages"
        case .pdfRedact: return "Choose a PDF to redact sensitive data"
        default: return "Choose files to process"
        }
    }

    private func loadPhotos(_ photos: [PhotosPickerItem]) {
        Task { @MainActor in
            // Check if adding these photos would exceed the limit
            let maxAllowed = maxSelectionCount ?? Int.max
            let currentCount = selectedURLs.count
            let newPhotosCount = photos.count
            
            if currentCount + newPhotosCount > maxAllowed {
                let remaining = maxAllowed - currentCount
                if remaining > 0 {
                    errorMessage = "You can only select up to \(maxAllowed) images. \(currentCount) already selected. Please select \(remaining) or fewer images."
                } else {
                    errorMessage = "You have already selected the maximum of \(maxAllowed) images. Please remove some images before adding more."
                }
                showError = true
                return
            }
            
            var successCount = 0
            var failureCount = 0
            
            // Limit concurrent photo loading to prevent memory issues
            let maxConcurrentLoads = 3
            
            for photoBatch in photos.chunked(into: maxConcurrentLoads) {
                await withTaskGroup(of: (Bool, URL?, String?).self) { group in
                    for photo in photoBatch {
                        group.addTask {
                            do {
                                guard let data = try await photo.loadTransferable(type: Data.self) else {
                                    return (false, nil, "Failed to load photo data")
                                }
                                
                                // Validate image data and format
                                guard let image = UIImage(data: data) else {
                                    return (false, nil, "Invalid image data")
                                }
                                
                                // Check image dimensions to prevent memory issues
                                let maxDimension: CGFloat = 8192
                                guard image.size.width <= maxDimension && image.size.height <= maxDimension else {
                                    return (false, nil, "Image too large (\(Int(image.size.width))x\(Int(image.size.height)))")
                                }
                                
                                let fileExtension = detectImageFormat(data: data)
                                let tempURL = FileManager.default.temporaryDirectory
                                    .appendingPathComponent(UUID().uuidString)
                                    .appendingPathExtension(fileExtension)
                                try data.write(to: tempURL)
                                return (true, tempURL, nil)
                            } catch {
                                return (false, nil, error.localizedDescription)
                            }
                        }
                    }
                    
                    for await result in group {
                        if result.0, let url = result.1 {
                            selectedURLs.append(url)
                            successCount += 1
                        } else {
                            failureCount += 1
                            if let errorMessage = result.2 {
                                print("Photo loading error: \(errorMessage)")
                            }
                        }
                    }
                }
            }
            
            // Show feedback if there were failures
            if failureCount > 0 {
                let message = failureCount == 1 ? "1 image failed to load" : "\(failureCount) images failed to load"
                print("Photo loading: \(message). \(successCount) images loaded successfully.")
                // Show user-friendly error message
                errorMessage = "\(message). \(successCount) image\(successCount == 1 ? "" : "s") loaded successfully."
                showError = true
            }
            
            analyzeSelectedFiles()
        }
    }
    
    private func detectImageFormat(data: Data) -> String {
        guard data.count > 8 else { return "jpg" }
        
        // Check image format headers
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "jpg" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "png" }
        if data.starts(with: [0x00, 0x00, 0x00, 0x20, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63]) { return "heic" }
        
        return "jpg" // Default fallback
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedURLs.append(contentsOf: urls)
        case .failure(let error):
            print("File import error: \(error)")
        }
    }

    private func fileSizeString(_ url: URL) -> String {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
              let size = attrs[.size] as? Int64 else {
            return ""
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private func fileIcon(_ url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.text"
        case "jpg", "jpeg", "png", "heic": return "photo"
        default: return "doc"
        }
    }
}

// MARK: - Configuration View
struct ConfigurationView: View {
    let tool: ToolType
    @Binding var settings: JobSettings
    let selectedURLs: [URL]
    let onProcess: () -> Void

    @State private var showAdvanced = false
    @State private var showContextualHelp = false

    private var isConfigurationValid: Bool {
        switch tool {
        case .pdfWatermark:
            return settings.watermarkText != nil && !settings.watermarkText!.isEmpty
        case .pdfSign:
            return (settings.signatureText != nil && !settings.signatureText!.isEmpty) || 
                   (settings.signatureImageData != nil)
        default:
            return true
        }
    }

    private var validationMessage: String? {
        switch tool {
        case .pdfWatermark:
            if settings.watermarkText == nil || settings.watermarkText!.isEmpty {
                return "Please enter watermark text"
            }
        case .pdfSign:
            if (settings.signatureText == nil || settings.signatureText!.isEmpty) && settings.signatureImageData == nil {
                return "Please enter signature text or draw a signature"
            }
        default:
            break
        }
        return nil
    }

    var body: some View {
        ZStack {
            OneBoxColors.primaryGraphite.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: OneBoxSpacing.large) {
                    // Configuration Header
                    configurationHeader
                    
                    // Tool-specific settings
                    toolSettingsSection
                    
                    // Advanced Settings with Ceremony
                    advancedSettingsSection
                    
                    // Privacy & Security Options
                    privacySettingsSection
                    
                    // Validation message
                    if let message = validationMessage {
                        validationWarning(message)
                    }
                    
                    Spacer(minLength: OneBoxSpacing.large)
                    
                    // Premium Process Button
                    processButton
                }
                .padding(OneBoxSpacing.medium)
            }
        }
        .sheet(isPresented: $showContextualHelp) {
            contextualHelpSheet
        }
    }
    
    private var configurationHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Configuration")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Customize your \(tool.displayName.lowercased()) settings")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        showContextualHelp = true
                        let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
                    }) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 20))
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                // Files Summary
                HStack {
                    HStack(spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        Text("\(selectedURLs.count) file\(selectedURLs.count == 1 ? "" : "s") selected")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    SecurityBadge(style: .minimal)
                }
                .padding(OneBoxSpacing.small)
                .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                .cornerRadius(OneBoxRadius.small)
            }
        }
    }
    
    private var toolSettingsSection: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            if hasToolSpecificSettings {
                OneBoxCard(style: .standard) {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                        HStack {
                            Text("Settings")
                                .font(OneBoxTypography.cardTitle)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Spacer()
                            
                            Image(systemName: tool.icon)
                                .font(.system(size: 16))
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        toolSettings
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
        }
    }
    
    private var advancedSettingsSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(spacing: OneBoxSpacing.medium) {
                Button {
                    showAdvanced.toggle()
                    let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
                } label: {
                    HStack {
                        HStack(spacing: OneBoxSpacing.small) {
                            Image(systemName: "gearshape.2")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                            
                            Text("Advanced Settings")
                                .font(OneBoxTypography.cardTitle)
                                .foregroundColor(OneBoxColors.primaryText)
                        }
                        
                        Spacer()
                        
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                if showAdvanced {
                    advancedSettings
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: showAdvanced)
    }
    
    private var privacySettingsSection: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Privacy & Security")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 16))
                        .foregroundColor(OneBoxColors.secureGreen)
                }
                
                VStack(spacing: OneBoxSpacing.small) {
                    privacyOption("Strip Metadata", "Remove personal information from files", $settings.stripMetadata)
                    
                    if tool != .imageResize {
                        privacyOption("Secure Vault", "Store output in encrypted vault", $settings.enableSecureVault)
                        privacyOption("Zero Trace", "No processing history saved", $settings.enableZeroTrace)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func privacyOption(_ title: String, _ description: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(title)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(description)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
        .onChange(of: binding.wrappedValue) { _ in
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }
    
    private func validationWarning(_ message: String) -> some View {
        OneBoxCard(style: .standard) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: "exclamationmark.triangle")
                    .foregroundColor(OneBoxColors.warningAmber)
                
                Text(message)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
            }
            .padding(OneBoxSpacing.medium)
        }
        .overlay(
            RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                .stroke(OneBoxColors.warningAmber.opacity(0.5), lineWidth: 1)
        )
    }
    
    private var processButton: some View {
        VStack(spacing: OneBoxSpacing.small) {
            // Processing preview
            HStack {
                Image(systemName: "shield.checkered")
                    .foregroundColor(OneBoxColors.secureGreen)
                
                Text("Files will be processed securely on your device")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Spacer()
            }
            .padding(OneBoxSpacing.small)
            .background(OneBoxColors.secureGreen.opacity(0.1))
            .cornerRadius(OneBoxRadius.small)
            
            OneBoxButton(
                "Begin Secure Processing",
                icon: "bolt.shield.fill",
                style: .security,
                isDisabled: !isConfigurationValid
            ) {
                onProcess()
                let generator = UINotificationFeedbackGenerator()
                generator.notificationOccurred(.success)
            }
        }
    }
    
    private var contextualHelpSheet: some View {
        NavigationStack {
            VStack(spacing: OneBoxSpacing.large) {
                Text("Configuration Help")
                    .font(OneBoxTypography.heroTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(getContextualHelp())
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.leading)
                
                Spacer()
            }
            .padding(OneBoxSpacing.large)
            .background(OneBoxColors.primaryGraphite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        showContextualHelp = false
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
    }
    
    private var hasToolSpecificSettings: Bool {
        switch tool {
        case .imagesToPDF, .pdfToImages, .pdfCompress, .pdfSplit, .pdfWatermark, .pdfSign, .imageResize:
            return true
        default:
            return false
        }
    }
    
    private func getContextualHelp() -> String {
        switch tool {
        case .imagesToPDF:
            return "Convert your images to PDF with custom page sizes and orientations. Use A4 for standard documents or Letter for US formats. Portrait orientation is recommended for most documents."
        case .pdfToImages:
            return "Extract pages from PDF as individual images. Choose between JPEG and PNG format, and select quality from Lowest to Best. Toggle 'Select All Pages' to convert the entire PDF, or turn it off to specify custom page ranges. All converted images are automatically saved to your photo gallery."
        case .pdfCompress:
            return "Reduce your PDF file size while maintaining quality. Choose compression quality based on your needs - Maximum for archival, Medium for sharing, Low for fastest processing."
        case .pdfWatermark:
            return "Add text watermarks to protect your documents. Position your watermark strategically - corners for subtle branding, center for maximum visibility, or tiled for security."
        case .pdfSign:
            return "Add your signature to PDF documents securely. You can type your name or draw a signature. The signature will be added to the last page by default."
        default:
            return "Configure your settings to optimize the processing for your specific needs. All processing happens securely on your device."
        }
    }

    @ViewBuilder
    private var toolSettings: some View {
        VStack(spacing: 16) {
            switch tool {
            case .imagesToPDF:
                pdfSettings
            case .pdfToImages:
                pdfToImagesSettings
            case .pdfCompress:
                compressionSettings
            case .pdfSplit:
                pdfSplitSettings
            case .pdfWatermark:
                watermarkSettings
            case .pdfSign:
                signatureSettings
            case .imageResize:
                imageSettings
            default:
                Text("Ready to process")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var pdfSettings: some View {
        VStack(spacing: 16) {
            // Page Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Page Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(OneBoxColors.primaryText)
                Picker("Page Size", selection: $settings.pageSize) {
                    ForEach(PDFPageSize.allCases, id: \.self) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Orientation
            VStack(alignment: .leading, spacing: 8) {
                Text("Orientation")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(OneBoxColors.primaryText)
                Picker("Orientation", selection: $settings.orientation) {
                    Text("Portrait").tag(PDFOrientation.portrait)
                    Text("Landscape").tag(PDFOrientation.landscape)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var pdfToImagesSettings: some View {
        VStack(spacing: 16) {
            // Image Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Format", selection: $settings.imageFormat) {
                    Text("JPEG (Smaller)").tag(ImageFormat.jpeg)
                    Text("PNG (Larger)").tag(ImageFormat.png)
                }
                .pickerStyle(.segmented)
                
                if settings.imageFormat == .png {
                    Text("PNG format ignores quality settings and creates larger files")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            // Image Quality (only for JPEG)
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Quality", selection: $settings.imageQualityPreset) {
                    ForEach(ImageQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.menu)
                .disabled(settings.imageFormat == .png)
                .onChange(of: settings.imageQualityPreset) { newPreset in
                    // Sync with old imageQuality value for backward compatibility
                    settings.imageQuality = newPreset.compressionValue
                }
                
                if settings.imageFormat == .png {
                    Text("Quality setting not available for PNG")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Resolution with size estimate
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Resolution: \(Int(settings.imageResolution)) DPI")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Text(estimatedSizeText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Slider(value: $settings.imageResolution, in: 72...150, step: 12)
                
                HStack {
                    Text("72 DPI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Web Quality")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("150 DPI")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Select All Pages Toggle
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Select All Pages", isOn: $settings.selectAllPages)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    .onChange(of: settings.selectAllPages) { isOn in
                        if isOn {
                            // Clear page ranges when selecting all pages
                            settings.splitRanges = []
                        }
                        let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
                    }
                
                if !settings.selectAllPages {
                    Text("Convert specific pages only")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Page Selection (only show if not selecting all pages)
            if !settings.selectAllPages {
                PDFSplitRangeSelector(settings: $settings, pdfURL: selectedURLs.first)
            }
        }
        .onAppear {
            // Ensure quality preset is synced with quality value
            settings.imageQuality = settings.imageQualityPreset.compressionValue
        }
    }
    
    private var estimatedSizeText: String {
        guard let pdfURL = selectedURLs.first,
              let pdf = PDFDocument(url: pdfURL) else {
            return ""
        }
        
        let pageCount = settings.selectAllPages ? pdf.pageCount : max(settings.splitRanges.flatMap { $0 }.count, 1)
        let estimatedSizePerPage = Int(settings.imageResolution * settings.imageResolution * 3 * settings.imageQuality / 1024 / 1024)
        let totalSize = estimatedSizePerPage * pageCount
        
        if totalSize > 1000 {
            return "~\(totalSize / 1000)GB"
        } else {
            return "~\(totalSize)MB"
        }
    }

    private var compressionSettings: some View {
        PDFCompressionSettings(settings: $settings, pdfURL: selectedURLs.first)
    }

    private var imageSettings: some View {
        VStack(spacing: 16) {
            // Format
            VStack(alignment: .leading, spacing: 8) {
                Text("Format")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(OneBoxColors.primaryText)
                Picker("Format", selection: $settings.imageFormat) {
                    Text("JPEG").tag(ImageFormat.jpeg)
                    Text("PNG").tag(ImageFormat.png)
                    Text("HEIC").tag(ImageFormat.heic)
                }
                .pickerStyle(.segmented)
                
                // Show format-specific info
                if settings.imageFormat == .png {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("PNG is lossless - quality setting does not apply")
                            .font(.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        Text("⚠️ Converting from JPEG to PNG will create larger files")
                            .font(.caption)
                            .foregroundColor(OneBoxColors.criticalRed.opacity(0.8))
                    }
                    .padding(.top, 4)
                } else if settings.imageFormat == .heic {
                    Text("HEIC provides better compression than JPEG")
                        .font(.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .padding(.top, 4)
                }
            }

            // Quality (only for lossy formats: JPEG and HEIC)
            if settings.imageFormat != .png {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Quality: \(Int(settings.imageQuality * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(OneBoxColors.primaryText)
                    Slider(value: $settings.imageQuality, in: 0.1...1.0, step: 0.1)
                        .tint(OneBoxColors.primaryGold)
                }
            } else {
                // Show info for PNG instead of quality slider
                VStack(alignment: .leading, spacing: 8) {
                    Text("Compression")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(OneBoxColors.primaryText)
                    Text("PNG uses lossless compression. Quality setting is not available.")
                        .font(.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(OneBoxColors.primaryGraphite.opacity(0.3))
                        .cornerRadius(OneBoxRadius.small)
                }
            }

            // Max Dimension
            if let maxDim = settings.maxDimension {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Size: \(maxDim)px")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(OneBoxColors.primaryText)
                    Slider(value: Binding(
                        get: { Double(maxDim) },
                        set: { settings.maxDimension = Int($0) }
                    ), in: 512...4096, step: 256)
                        .tint(OneBoxColors.primaryGold)
                }
            } else {
                Button("Set Max Size") {
                    settings.maxDimension = 2048
                }
                .foregroundColor(OneBoxColors.primaryGold)
            }
            
            // Show image count if images are selected
            if !selectedURLs.isEmpty {
                Text("\(selectedURLs.count) image\(selectedURLs.count == 1 ? "" : "s") selected")
                    .font(.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
        }
    }

    private var pdfSplitSettings: some View {
        PDFSplitRangeSelector(settings: $settings, pdfURL: selectedURLs.first)
    }

    private var watermarkSettings: some View {
        VStack(spacing: 16) {
            // Watermark Text
            VStack(alignment: .leading, spacing: 8) {
                Text("Watermark Text")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Enter watermark text", text: Binding(
                    get: { settings.watermarkText ?? "" },
                    set: { settings.watermarkText = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            // Position
            VStack(alignment: .leading, spacing: 8) {
                Text("Position")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Position", selection: $settings.watermarkPosition) {
                    ForEach(WatermarkPosition.allCases, id: \.self) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .pickerStyle(.menu)
            }

            // Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Size: \(Int(settings.watermarkSize * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Slider(value: $settings.watermarkSize, in: 0.1...0.5, step: 0.05)
            }
            
            // Tile Density (only for tiled watermarks)
            if settings.watermarkPosition == .tiled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tile Density: \(Int(settings.watermarkTileDensity * 100))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: $settings.watermarkTileDensity, in: 0.1...0.8, step: 0.1)
                }
                .transition(.opacity)
            }

            // Opacity
            VStack(alignment: .leading, spacing: 8) {
                Text("Opacity: \(Int(settings.watermarkOpacity * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Slider(value: $settings.watermarkOpacity, in: 0.1...1.0, step: 0.1)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: settings.watermarkPosition)
    }

    private var signatureSettings: some View {
        VStack(spacing: 16) {
            // Info text with better visibility
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(OneBoxColors.primaryGold)
                Text("The signature will be added to the last page of the PDF by default")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            .padding(OneBoxSpacing.small)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(OneBoxColors.surfaceGraphite.opacity(0.5))
            .cornerRadius(OneBoxRadius.small)

            // Signature Input (Text or Drawing)
            SignatureInputView(
                signatureText: $settings.signatureText,
                signatureImageData: $settings.signatureImageData
            )
            .accessibilityLabel("Signature input")
            .accessibilityHint("Enter text or draw your signature")

            // Validation feedback
            if !isConfigurationValid {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(OneBoxColors.warningAmber)
                    Text(validationMessage ?? "Please provide a signature")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.warningAmber)
                }
                .padding(OneBoxSpacing.small)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(OneBoxColors.warningAmber.opacity(0.1))
                .cornerRadius(OneBoxRadius.small)
                .accessibilityLabel("Validation error: \(validationMessage ?? "Please provide a signature")")
            }

            // Position
            VStack(alignment: .leading, spacing: 8) {
                Text("Position")
                    .font(OneBoxTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(OneBoxColors.primaryText)
                Picker("Position", selection: $settings.signaturePosition) {
                    ForEach(WatermarkPosition.allCases.filter { $0 != .tiled }, id: \.self) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .pickerStyle(.menu)
                .accentColor(OneBoxColors.primaryGold)
                .accessibilityLabel("Signature position")
            }

            // Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Size: \(Int(settings.signatureSize * 100))%")
                    .font(OneBoxTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(OneBoxColors.primaryText)
                Slider(value: $settings.signatureSize, in: 0.1...0.3, step: 0.05)
                    .tint(OneBoxColors.primaryGold)
                    .accessibilityLabel("Signature size")
                    .accessibilityValue("\(Int(settings.signatureSize * 100)) percent")
            }
        }
    }

    private var advancedSettings: some View {
        VStack(spacing: 16) {
            Toggle("Strip Metadata", isOn: $settings.stripMetadata)

            if tool == .imagesToPDF || tool.rawValue.contains("pdf") {
                TextField("PDF Title", text: Binding(
                    get: { settings.pdfTitle ?? "" },
                    set: { settings.pdfTitle = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)

                TextField("PDF Author", text: Binding(
                    get: { settings.pdfAuthor ?? "" },
                    set: { settings.pdfAuthor = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Processing View
struct ProcessingView: View {
    let job: Job?
    @State private var securityPulse = false

    var body: some View {
        ZStack {
            OneBoxColors.primaryGraphite.ignoresSafeArea()
            
            VStack(spacing: OneBoxSpacing.xxl) {
                Spacer()
                
                // Ceremony of Security Processing
                VStack(spacing: OneBoxSpacing.large) {
                    // Security Shield Animation
                    ZStack {
                        // Outer security rings
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(OneBoxColors.primaryGold.opacity(0.3), lineWidth: 2)
                                .frame(width: 120 + CGFloat(index * 30), height: 120 + CGFloat(index * 30))
                                .scaleEffect(securityPulse ? 1.1 : 1.0)
                                .opacity(securityPulse ? 0.3 : 0.6)
                                .animation(
                                    .easeInOut(duration: 2.0)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(index) * 0.3),
                                    value: securityPulse
                                )
                        }
                        
                        // Central shield
                        ZStack {
                            Circle()
                                .fill(OneBoxColors.primaryGold.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "shield.checkered")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                                .scaleEffect(securityPulse ? 1.05 : 1.0)
                                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: securityPulse)
                        }
                    }
                    
                    // Processing Status
                    VStack(spacing: OneBoxSpacing.medium) {
                        Text("Secure Processing")
                            .font(OneBoxTypography.heroTitle)
                            .fontWeight(.bold)
                            .foregroundColor(OneBoxColors.primaryText)
                            .tracking(1.0)
                        
                        Text("Your files are being processed entirely\non your device - never uploaded")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.secondaryText)
                            .multilineTextAlignment(.center)
                            .lineSpacing(4)
                    }
                    
                    // Progress Section
                    VStack(spacing: OneBoxSpacing.medium) {
                        // Custom progress bar
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(OneBoxColors.surfaceGraphite)
                                .frame(height: 8)
                                .cornerRadius(4)
                            
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        colors: [OneBoxColors.primaryGold, OneBoxColors.secondaryGold],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, (job?.progress ?? 0) * 280), height: 8)
                                .cornerRadius(4)
                                .animation(.easeInOut(duration: 0.3), value: job?.progress)
                        }
                        .frame(width: 280)
                        
                        if let job = job {
                            // Guard against NaN/infinity that crashes Int conversion
                            let progressPercent = job.progress.isNaN || job.progress.isInfinite ? 0 : Int(job.progress * 100)
                            Text("\(progressPercent)% Complete")
                                .font(OneBoxTypography.cardTitle)
                                .foregroundColor(OneBoxColors.primaryGold)
                                .fontWeight(.semibold)
                        }
                    }
                    
                    // Security Guarantees
                    HStack(spacing: OneBoxSpacing.large) {
                        securityFeature("lock.fill", "Encrypted")
                        securityFeature("eye.slash.fill", "Private")
                        securityFeature("shield.fill", "Secure")
                    }
                    .padding(.top, OneBoxSpacing.medium)
                }
                
                Spacer()
            }
            .padding(OneBoxSpacing.large)
            .onAppear {
                securityPulse = true
            }
        }
    }
    
    private func securityFeature(_ icon: String, _ title: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(OneBoxColors.secureGreen)
            
            Text(title)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
        .opacity(0.8)
    }
}

// MARK: - PDF Split Range Selector
struct PDFSplitRangeSelector: View {
    @Binding var settings: JobSettings
    let pdfURL: URL?

    @State private var startPage: String = "1"
    @State private var endPage: String = "1"
    @State private var pageRanges: [[Int]] = []
    @State private var totalPages: Int = 0
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Text("Select Page Ranges")
                .font(.headline)

            if totalPages > 0 {
                Text("PDF has \(totalPages) page\(totalPages == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundColor(.accentColor)
                    .fontWeight(.medium)
            }

            Text("Add page ranges to convert (e.g., 1-3, 5, 7-10)")
                .font(.subheadline)
                .foregroundColor(.secondary)

            // Add range controls
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("1", text: $startPage)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("1", text: $endPage)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.numberPad)
                        .frame(width: 80)
                }

                Button(action: addRange) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
            }

            // Error message
            if let error = errorMessage {
                Text(error)
                    .font(.subheadline)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            // Display added ranges
            if !pageRanges.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ranges:")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    ForEach(Array(pageRanges.enumerated()), id: \.offset) { index, range in
                        HStack {
                            if let first = range.first, let last = range.last {
                                Text("Pages \(first)-\(last)")
                                    .font(.subheadline)
                            }
                            Spacer()
                            Button(action: { removeRange(at: index) }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                    }
                }
            }
        }
        .onAppear {
            loadPDFInfo()
            pageRanges = settings.splitRanges
        }
        .onChange(of: pageRanges) { newValue in
            settings.splitRanges = newValue
        }
    }

    private func loadPDFInfo() {
        guard let url = pdfURL, let pdf = PDFDocument(url: url) else {
            totalPages = 0
            return
        }
        totalPages = pdf.pageCount
    }

    private func addRange() {
        // Clear previous error
        errorMessage = nil

        guard let start = Int(startPage), let end = Int(endPage) else {
            errorMessage = "Please enter valid page numbers"
            return
        }

        // Validate page numbers
        if start < 1 {
            errorMessage = "Page numbers must be at least 1"
            return
        }

        if start > end {
            errorMessage = "Start page must be less than or equal to end page"
            return
        }

        if totalPages > 0 && end > totalPages {
            errorMessage = "Page \(end) doesn't exist. PDF only has \(totalPages) page\(totalPages == 1 ? "" : "s")"
            return
        }

        let range = Array(start...end)
        pageRanges.append(range)

        // Reset fields to next available page
        startPage = "\(end + 1)"
        endPage = "\(end + 1)"
    }

    private func removeRange(at index: Int) {
        pageRanges.remove(at: index)
    }
}

// MARK: - PDF Compression Settings
struct PDFCompressionSettings: View {
    @Binding var settings: JobSettings
    let pdfURL: URL?

    @State private var originalSizeMB: Double = 0
    @State private var minAchievableMB: Double = 0.5
    @State private var maxAchievableMB: Double = 50

    var body: some View {
        VStack(spacing: 16) {
            // Show original size
            if originalSizeMB > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Original Size: \(String(format: "%.1f", originalSizeMB)) MB")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("Achievable range: \(String(format: "%.1f", minAchievableMB)) - \(String(format: "%.1f", maxAchievableMB)) MB")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Quality")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Quality", selection: $settings.compressionQuality) {
                    ForEach(CompressionQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let targetSize = settings.targetSizeMB {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Target Size: \(String(format: "%.1f", targetSize)) MB")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Slider(value: Binding(
                        get: { targetSize },
                        set: { settings.targetSizeMB = $0 }
                    ), in: minAchievableMB...maxAchievableMB, step: 0.5)

                    HStack {
                        Text("\(String(format: "%.1f", minAchievableMB)) MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(String(format: "%.1f", maxAchievableMB)) MB")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button("Clear Target Size") {
                    settings.targetSizeMB = nil
                }
                .font(.subheadline)
                .foregroundColor(.red)
            } else {
                Button("Set Target Size") {
                    settings.targetSizeMB = minAchievableMB + 1.0
                }
            }
        }
        .onAppear {
            loadPDFInfo()
        }
    }

    private func loadPDFInfo() {
        guard let url = pdfURL else { return }

        // Get original file size
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let fileSize = attributes[.size] as? Int64 {
            originalSizeMB = Double(fileSize) / 1_000_000.0

            // Estimate minimum achievable size with enhanced compression (resolution downsampling + JPEG quality)
            // With 0.5x resolution scale + aggressive JPEG compression, can achieve ~5-8% of original
            minAchievableMB = max(0.1, originalSizeMB * 0.07)

            // Estimate maximum useful size (90% of original - not worth compressing beyond this)
            maxAchievableMB = max(minAchievableMB + 0.5, originalSizeMB * 0.9)

            // Round values for better UX
            minAchievableMB = (minAchievableMB * 10).rounded() / 10
            maxAchievableMB = (maxAchievableMB * 10).rounded() / 10

            // If target size is set but out of range, adjust it
            if let currentTarget = settings.targetSizeMB {
                if currentTarget < minAchievableMB {
                    settings.targetSizeMB = minAchievableMB
                } else if currentTarget > maxAchievableMB {
                    settings.targetSizeMB = maxAchievableMB
                }
            }
        }
    }
}

// MARK: - Array Extension for Chunking
extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

// MARK: - ToolFlowView Preview
#Preview {
    ToolFlowView(tool: ToolType.imagesToPDF)
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
}
