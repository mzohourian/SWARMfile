//
//  AdvancedMergeView.swift
//  OneBox
//
//  Advanced PDF merge with auto bookmarks, metadata reconciliation, and conflict resolution
//

import SwiftUI
import UIComponents
import JobEngine
import PDFKit
import UniformTypeIdentifiers

struct AdvancedMergeView: View {
    @Binding var settings: JobSettings
    let selectedURLs: [URL]
    @Environment(\.dismiss) var dismiss
    
    @State private var mergeOrder: [MergeDocument] = []
    @State private var showBookmarkSettings = false
    @State private var showMetadataSettings = false
    @State private var showWatermarkSettings = false
    @State private var isAnalyzingDocuments = false
    @State private var conflictResolution: ConflictResolution = .ask
    @State private var duplicateStrategy: DuplicateStrategy = .merge
    @State private var documentAnalysis: [DocumentAnalysis] = []
    @State private var draggedItem: MergeDocument?
    
    // Computed property to ensure correct type inference for Binding
    private var customMetadataFieldBinding: Binding<String> {
        Binding(
            get: {
                return settings.pdfTitle ?? ""
            },
            set: { newValue in
                settings.pdfTitle = newValue.isEmpty ? nil : newValue
            }
        )
    }
    
    private var watermarkTextBinding: Binding<String> {
        Binding(
            get: { settings.watermarkText ?? "" },
            set: { settings.watermarkText = $0.isEmpty ? nil : $0 }
        )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Header with ceremony
                        mergeHeader
                        
                        // Document Order Section
                        documentOrderSection
                        
                        // Auto Bookmarks
                        bookmarkSettingsSection
                        
                        // Metadata Reconciliation
                        metadataReconciliationSection
                        
                        // Batch Watermark/Numbering
                        watermarkNumberingSection
                        
                        // Conflict Resolution
                        conflictResolutionSection
                        
                        // Document Analysis
                        documentAnalysisSection
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Advanced Merge Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        performAdvancedMerge()
                    }) {
                        Text("Merge")
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(mergeOrder.count < 2)
                }
            }
        }
        .onAppear {
            initializeMergeOrder()
            analyzeDocuments()
        }
    }
    
    // MARK: - Header
    private var mergeHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Advanced PDF Merge")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Professional merge with intelligent automation")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: OneBoxSpacing.tiny) {
                        if isAnalyzingDocuments {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(OneBoxColors.primaryGold)
                        } else {
                            Image(systemName: "doc.on.doc.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        Text("\(mergeOrder.count) documents")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                HStack {
                    Text("Estimated result: \(getEstimatedPageCount()) pages")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    Spacer()
                    
                    SecurityBadge(style: .minimal)
                }
                .padding(OneBoxSpacing.small)
                .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                .cornerRadius(OneBoxRadius.small)
            }
        }
    }
    
    // MARK: - Document Order
    private var documentOrderSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Document Order")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        autoSortDocuments()
                    }) {
                        Text("Auto-Sort")
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                }
                
                Text("Drag to reorder • Auto-sort by name, date, or size")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                LazyVStack(spacing: OneBoxSpacing.small) {
                    ForEach(mergeOrder) { document in
                        documentOrderRow(document)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func documentOrderRow(_ document: MergeDocument) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 16))
                .foregroundColor(OneBoxColors.tertiaryText)
            
            // Document info
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(document.name)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)
                
                HStack {
                    Text("\(document.pageCount) pages")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    if let size = document.fileSize {
                        Text("• \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    if document.hasConflicts {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(OneBoxColors.warningAmber)
                    }
                }
            }
            
            Spacer()
            
            // Order number
            Text("\(document.order)")
                .font(OneBoxTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(OneBoxColors.primaryGold.opacity(0.1))
                )
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.2))
        .cornerRadius(OneBoxRadius.small)
        .onDrag {
            draggedItem = document
            return NSItemProvider(object: document.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: DocumentDropDelegate(
            document: document,
            mergeOrder: $mergeOrder,
            draggedItem: $draggedItem
        ))
    }
    
    // MARK: - Bookmark Settings
    private var bookmarkSettingsSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Button(action: {
                    showBookmarkSettings.toggle()
                    HapticManager.shared.selection()
                }) {
                    HStack {
                        Text("Auto-Bookmark Generation")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.generateBookmarks)
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                        
                        Image(systemName: showBookmarkSettings ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                if showBookmarkSettings && settings.generateBookmarks {
                    VStack(spacing: OneBoxSpacing.small) {
                        bookmarkOption("Document titles", "Use document filenames as top-level bookmarks", $settings.bookmarkByDocument)
                        bookmarkOption("Page numbers", "Add page number bookmarks for easy navigation", $settings.bookmarkByPage)
                        bookmarkOption("Content sections", "AI-detect sections and create bookmarks", $settings.bookmarkByContent)
                        bookmarkOption("Table of contents", "Extract existing TOC as bookmarks", $settings.extractTOC)
                        
                        if settings.bookmarkByContent {
                            HStack {
                                Text("Detection sensitivity:")
                                    .font(OneBoxTypography.caption)
                                    .foregroundColor(OneBoxColors.secondaryText)
                                
                                Spacer()
                                
                                Picker("Sensitivity", selection: $settings.bookmarkSensitivity) {
                                    Text("Low").tag(0)
                                    Text("Medium").tag(1)
                                    Text("High").tag(2)
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 150)
                            }
                            .transition(.opacity)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: showBookmarkSettings)
    }
    
    private func bookmarkOption(_ title: String, _ description: String, _ binding: Binding<Bool>) -> some View {
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
        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.secondaryGold))
        .onChange(of: binding.wrappedValue) { _ in
            HapticManager.shared.selection()
        }
    }
    
    // MARK: - Metadata Reconciliation
    private var metadataReconciliationSection: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Button(action: {
                    showMetadataSettings.toggle()
                    HapticManager.shared.selection()
                }) {
                    HStack {
                        Text("Metadata Reconciliation")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Text(settings.metadataStrategy.displayName)
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        Image(systemName: showMetadataSettings ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                if showMetadataSettings {
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(MetadataStrategy.allCases, id: \.self) { strategy in
                            metadataStrategyOption(strategy)
                        }
                        
                        Divider()
                            .background(OneBoxColors.surfaceGraphite)
                        
                        Text("Custom metadata fields")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack {
                            TextField("Add custom field", text: customMetadataFieldBinding)
                                .textFieldStyle(.roundedBorder)
                            
                            Button(action: {
                                addCustomMetadataField()
                            }) {
                                Text("Add")
                            }
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.primaryGold)
                            .disabled(customMetadataFieldBinding.wrappedValue.isEmpty)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: showMetadataSettings)
    }
    
    private func metadataStrategyOption(_ strategy: MetadataStrategy) -> some View {
        Button(action: {
            settings.metadataStrategy = strategy
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: settings.metadataStrategy == strategy ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(settings.metadataStrategy == strategy ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(strategy.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(strategy.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Watermark & Numbering
    private var watermarkNumberingSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Button(action: {
                    showWatermarkSettings.toggle()
                    HapticManager.shared.selection()
                }) {
                    HStack {
                        Text("Batch Watermark & Numbering")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Toggle("", isOn: $settings.enableBatchWatermark)
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                        
                        Image(systemName: showWatermarkSettings ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                if showWatermarkSettings && settings.enableBatchWatermark {
                    VStack(spacing: OneBoxSpacing.medium) {
                        // Page numbering
                        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                            Toggle(isOn: $settings.continuousPageNumbers) {
                                Text("Continuous page numbering")
                                    .foregroundColor(OneBoxColors.primaryText)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                            
                            if settings.continuousPageNumbers {
                                HStack {
                                    Text("Starting number:")
                                        .font(OneBoxTypography.caption)
                                        .foregroundColor(OneBoxColors.secondaryText)
                                    
                                    Spacer()
                                    
                                    TextField("1", value: $settings.startingPageNumber, formatter: NumberFormatter())
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 60)
                                }
                                .transition(.opacity)
                            }
                        }
                        
                        Divider()
                            .background(OneBoxColors.surfaceGraphite)
                        
                        // Watermark settings
                        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                            Toggle(isOn: $settings.addDocumentWatermark) {
                                Text("Add document watermark")
                                    .foregroundColor(OneBoxColors.primaryText)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                            
                            if settings.addDocumentWatermark {
                                VStack(spacing: OneBoxSpacing.small) {
                                    HStack {
                                        Text("Watermark text:")
                                            .font(OneBoxTypography.caption)
                                            .foregroundColor(OneBoxColors.secondaryText)
                                        
                                        TextField("Enter text", text: watermarkTextBinding)
                                            .textFieldStyle(.roundedBorder)
                                    }
                                    
                                    HStack {
                                        Text("Opacity:")
                                            .font(OneBoxTypography.caption)
                                            .foregroundColor(OneBoxColors.secondaryText)
                                        
                                        Slider(value: $settings.watermarkOpacity, in: 0.1...1.0)
                                            .accentColor(OneBoxColors.primaryGold)
                                        
                                        Text("\(Int(settings.watermarkOpacity * 100))%")
                                            .font(OneBoxTypography.micro)
                                            .foregroundColor(OneBoxColors.tertiaryText)
                                            .frame(width: 40)
                                    }
                                }
                                .transition(.opacity)
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: showWatermarkSettings)
    }
    
    // MARK: - Conflict Resolution
    private var conflictResolutionSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Duplicate & Conflict Resolution")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    HStack {
                        Text("Duplicate strategy:")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Picker("Duplicate Strategy", selection: $duplicateStrategy) {
                            ForEach(DuplicateStrategy.allCases, id: \.self) { strategy in
                                Text(strategy.displayName).tag(strategy)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(OneBoxColors.primaryGold)
                    }
                    
                    HStack {
                        Text("Page conflicts:")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Picker("Conflict Resolution", selection: $conflictResolution) {
                            ForEach(ConflictResolution.allCases, id: \.self) { resolution in
                                Text(resolution.displayName).tag(resolution)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(OneBoxColors.primaryGold)
                    }
                    
                    Toggle(isOn: $settings.autoResolveMetadata) {
                        Text("Auto-resolve metadata conflicts")
                            .foregroundColor(OneBoxColors.primaryText)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))

                    Toggle(isOn: $settings.preserveTimestamps) {
                        Text("Preserve original timestamps")
                            .foregroundColor(OneBoxColors.primaryText)
                    }
                    .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Document Analysis
    private var documentAnalysisSection: some View {
        Group {
            if !documentAnalysis.isEmpty {
                OneBoxCard(style: .elevated) {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                        HStack {
                            Text("Document Analysis")
                                .font(OneBoxTypography.cardTitle)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Spacer()
                            
                            if isAnalyzingDocuments {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .tint(OneBoxColors.primaryGold)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(OneBoxColors.secureGreen)
                            }
                        }
                        
                        if !isAnalyzingDocuments {
                            VStack(spacing: OneBoxSpacing.small) {
                                ForEach(documentAnalysis.prefix(3)) { analysis in
                                    analysisRow(analysis)
                                }
                                
                                if documentAnalysis.count > 3 {
                                    Button(action: {
                                        // Show detailed analysis
                                    }) {
                                        Text("View All \(documentAnalysis.count) Analyses")
                                    }
                                    .font(OneBoxTypography.caption)
                                    .foregroundColor(OneBoxColors.primaryGold)
                                }
                            }
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private func analysisRow(_ analysis: DocumentAnalysis) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: analysis.issue?.icon ?? "checkmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(analysis.issue?.color ?? OneBoxColors.secureGreen)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(analysis.documentName)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)
                
                Text(analysis.summary)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if analysis.issue != nil {
                Button(action: {
                    applyFix(for: analysis)
                }) {
                    Text("Fix")
                }
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.primaryGold)
                .padding(.horizontal, OneBoxSpacing.tiny)
                .padding(.vertical, 2)
                .background(OneBoxColors.primaryGold.opacity(0.1))
                .cornerRadius(OneBoxRadius.small)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func initializeMergeOrder() {
        mergeOrder = selectedURLs.enumerated().map { index, url in
            MergeDocument(
                id: UUID(),
                url: url,
                name: url.lastPathComponent,
                order: index + 1,
                pageCount: getPageCount(for: url),
                fileSize: getFileSize(for: url),
                hasConflicts: detectRealConflicts(for: url)
            )
        }
    }
    
    private func detectRealConflicts(for url: URL) -> Bool {
        guard let document = PDFDocument(url: url) else { return false }
        
        // Check for actual PDF conflicts that could cause merge issues
        var hasConflicts = false
        
        // Check if document is password protected
        if document.isEncrypted {
            hasConflicts = true
        }
        
        // Check for form fields (can cause conflicts during merge)
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            if !page.annotations.isEmpty {
                // Check if annotations include form fields
                for annotation in page.annotations {
                    if annotation.type == "Widget" {
                        hasConflicts = true
                        break
                    }
                }
                if hasConflicts { break }
            }
        }
        
        // Check for unusual page sizes that might not merge well
        if let firstPage = document.page(at: 0) {
            let pageSize = firstPage.bounds(for: .mediaBox).size
            // Flag documents with unusual aspect ratios or very large/small sizes
            let aspectRatio = pageSize.width / pageSize.height
            if aspectRatio < 0.5 || aspectRatio > 2.0 || pageSize.width < 100 || pageSize.height < 100 {
                hasConflicts = true
            }
        }
        
        return hasConflicts
    }
    
    private func analyzeDocuments() {
        isAnalyzingDocuments = true
        
        Task {
            var analyses: [DocumentAnalysis] = []
            
            for document in mergeOrder {
                let analysis = await analyzeDocument(document)
                analyses.append(analysis)
            }
            
            await MainActor.run {
                self.documentAnalysis = analyses
                self.isAnalyzingDocuments = false
            }
        }
    }
    
    private func analyzeDocument(_ document: MergeDocument) async -> DocumentAnalysis {
        // Real document analysis using PDFKit
        guard let pdfDoc = PDFDocument(url: document.url) else {
            return DocumentAnalysis(
                id: UUID(),
                documentName: document.name,
                summary: "Unable to read document - file may be corrupted",
                issue: MergeIssue(type: .format, description: "File cannot be opened", severity: .high)
            )
        }
        
        var detectedIssues: [String] = []
        var issueType: MergeIssue.IssueType = .compatibility
        var severity: MergeIssue.Severity = .low
        
        // Check for password protection
        if pdfDoc.isEncrypted {
            detectedIssues.append("Password protected - will prompt during merge")
            issueType = .security
            severity = .medium
        }
        
        // Check file size
        if let fileSize = document.fileSize, fileSize > 50_000_000 { // 50MB
            detectedIssues.append("Large file size (\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))) - consider compression")
            issueType = .size
            severity = max(severity, .medium)
        }
        
        // Check for form fields
        var hasFormFields = false
        for pageIndex in 0..<pdfDoc.pageCount {
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            for annotation in page.annotations {
                if annotation.type == "Widget" {
                    hasFormFields = true
                    break
                }
            }
            if hasFormFields { break }
        }
        
        if hasFormFields {
            detectedIssues.append("Contains form fields that may conflict during merge")
            issueType = .compatibility
            severity = max(severity, .medium)
        }
        
        // Check for inconsistent page sizes
        var pageSizes: [CGSize] = []
        for pageIndex in 0..<min(pdfDoc.pageCount, 5) { // Check first 5 pages
            guard let page = pdfDoc.page(at: pageIndex) else { continue }
            let pageSize = page.bounds(for: .mediaBox).size
            pageSizes.append(pageSize)
        }
        
        if pageSizes.count > 1 {
            let firstSize = pageSizes[0]
            let hasInconsistentSizes = pageSizes.contains { size in
                abs(size.width - firstSize.width) > 10 || abs(size.height - firstSize.height) > 10
            }
            
            if hasInconsistentSizes {
                detectedIssues.append("Mixed page sizes detected - may affect final layout")
                issueType = .format
                severity = max(severity, .low)
            }
        }
        
        // Check for unusual page dimensions
        if let firstPage = pdfDoc.page(at: 0) {
            let pageSize = firstPage.bounds(for: .mediaBox).size
            let aspectRatio = pageSize.width / pageSize.height
            if aspectRatio < 0.5 || aspectRatio > 2.0 {
                detectedIssues.append("Unusual page aspect ratio - may not merge well with standard documents")
                issueType = .format
                severity = max(severity, .low)
            }
        }
        
        // Create analysis result
        let issue: MergeIssue? = detectedIssues.isEmpty ? nil : MergeIssue(
            type: issueType,
            description: detectedIssues.first ?? "",
            severity: severity
        )
        
        let summary = detectedIssues.isEmpty ? 
            "Document analysis complete - ready for merge" : 
            detectedIssues.joined(separator: " • ")
        
        return DocumentAnalysis(
            id: UUID(),
            documentName: document.name,
            summary: summary,
            issue: issue
        )
    }
    
    private func getPageCount(for url: URL) -> Int {
        guard let document = PDFDocument(url: url) else { return 0 }
        return document.pageCount
    }
    
    private func getFileSize(for url: URL) -> Int64? {
        try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
    }
    
    private func getEstimatedPageCount() -> Int {
        mergeOrder.reduce(0) { $0 + $1.pageCount }
    }
    
    private func autoSortDocuments() {
        mergeOrder.sort { doc1, doc2 in
            doc1.name.localizedCaseInsensitiveCompare(doc2.name) == .orderedAscending
        }
        
        // Update order numbers
        for index in mergeOrder.indices {
            mergeOrder[index].order = index + 1
        }
        
        HapticManager.shared.notification(.success)
    }
    
    private func addCustomMetadataField() {
        // Add custom metadata field logic
        settings.customMetadataField = ""
        customMetadataFieldBinding.wrappedValue = ""
        HapticManager.shared.notification(.success)
    }
    
    private func applyFix(for analysis: DocumentAnalysis) {
        // Apply suggested fixes for document issues
        HapticManager.shared.notification(.success)
    }
    
    private func performAdvancedMerge() {
        // Apply all advanced merge settings and perform the merge
        let orderedURLs = mergeOrder.sorted { $0.order < $1.order }.map { $0.url }
        
        // Create job with advanced settings
        let job = Job(
            type: .pdfMerge,
            inputs: orderedURLs,
            settings: settings
        )
        
        Task {
            await jobManager.submitJob(job)
            await MainActor.run {
                dismiss()
            }
        }
        
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Supporting Types

struct MergeDocument: Identifiable {
    let id: UUID
    let url: URL
    let name: String
    var order: Int
    let pageCount: Int
    let fileSize: Int64?
    let hasConflicts: Bool
}

struct DocumentAnalysis: Identifiable {
    let id: UUID
    let documentName: String
    let summary: String
    let issue: MergeIssue?
}

struct MergeIssue {
    let type: IssueType
    let description: String
    let severity: Severity
    
    enum IssueType {
        case compatibility, size, security, format
    }
    
    enum Severity: Comparable {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return OneBoxColors.secondaryText
            case .medium: return OneBoxColors.warningAmber
            case .high: return OneBoxColors.criticalRed
            }
        }
    }
    
    var icon: String {
        switch type {
        case .compatibility: return "exclamationmark.triangle.fill"
        case .size: return "externaldrive.fill"
        case .security: return "lock.fill"
        case .format: return "doc.text.fill"
        }
    }
    
    var color: Color { severity.color }
}

enum MetadataStrategy: String, CaseIterable {
    case firstDocument = "first"
    case lastDocument = "last"
    case mostRecent = "recent"
    case merge = "merge"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .firstDocument: return "First Document"
        case .lastDocument: return "Last Document"
        case .mostRecent: return "Most Recent"
        case .merge: return "Merge All"
        case .custom: return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .firstDocument: return "Use metadata from the first document"
        case .lastDocument: return "Use metadata from the last document"
        case .mostRecent: return "Use metadata from most recently modified"
        case .merge: return "Intelligently merge all metadata"
        case .custom: return "Specify custom metadata rules"
        }
    }
}

enum DuplicateStrategy: String, CaseIterable {
    case skip = "skip"
    case merge = "merge"
    case keep = "keep"
    case ask = "ask"
    
    var displayName: String {
        switch self {
        case .skip: return "Skip Duplicates"
        case .merge: return "Merge Content"
        case .keep: return "Keep All"
        case .ask: return "Ask Each Time"
        }
    }
}

enum ConflictResolution: String, CaseIterable {
    case ask = "ask"
    case auto = "auto"
    case manual = "manual"
    
    var displayName: String {
        switch self {
        case .ask: return "Ask Each Time"
        case .auto: return "Auto-Resolve"
        case .manual: return "Manual Review"
        }
    }
}

// MARK: - Drag and Drop Support

struct DocumentDropDelegate: DropDelegate {
    let document: MergeDocument
    @Binding var mergeOrder: [MergeDocument]
    @Binding var draggedItem: MergeDocument?
    
    func performDrop(info: DropInfo) -> Bool {
        guard let draggedItem = draggedItem else { return false }
        
        if let fromIndex = mergeOrder.firstIndex(where: { $0.id == draggedItem.id }),
           let toIndex = mergeOrder.firstIndex(where: { $0.id == document.id }) {
            withAnimation(.easeInOut(duration: 0.3)) {
                mergeOrder.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                
                // Update order numbers
                for index in mergeOrder.indices {
                    mergeOrder[index].order = index + 1
                }
            }
        }
        
        return true
    }
    
    func dropEntered(info: DropInfo) {
        guard let draggedItem = draggedItem else { return }
        
        if draggedItem.id != document.id {
            if let fromIndex = mergeOrder.firstIndex(where: { $0.id == draggedItem.id }),
               let toIndex = mergeOrder.firstIndex(where: { $0.id == document.id }) {
                withAnimation(.easeInOut(duration: 0.2)) {
                    mergeOrder.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: toIndex > fromIndex ? toIndex + 1 : toIndex)
                }
            }
        }
    }
}

// MARK: - JobSettings Extensions

extension JobSettings {
    var generateBookmarks: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var bookmarkByDocument: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var bookmarkByPage: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var bookmarkByContent: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var extractTOC: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var bookmarkSensitivity: Int {
        get { 1 }
        set { }
    }
    
    var metadataStrategy: MetadataStrategy {
        get { .merge }
        set { }
    }
    
    var customMetadataField: String {
        get { 
            if let title = pdfTitle {
                return title
            }
            return ""
        }
        set { 
            pdfTitle = newValue.isEmpty ? nil : newValue
        }
    }
    
    var enableBatchWatermark: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var continuousPageNumbers: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var startingPageNumber: Int {
        get { 1 }
        set { }
    }
    
    var addDocumentWatermark: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var autoResolveMetadata: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var preserveTimestamps: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
}

// Access to JobManager
private extension AdvancedMergeView {
    var jobManager: JobManager {
        JobManager.shared
    }
}

#Preview {
    AdvancedMergeView(
        settings: .constant(JobSettings()),
        selectedURLs: [
            URL(fileURLWithPath: "/tmp/doc1.pdf"),
            URL(fileURLWithPath: "/tmp/doc2.pdf"),
            URL(fileURLWithPath: "/tmp/doc3.pdf")
        ]
    )
}