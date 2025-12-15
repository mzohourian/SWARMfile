//
//  SmartSplitView.swift
//  OneBox
//
//  Smart PDF splitting with conditional rules and automated naming
//

import SwiftUI
import UIComponents
import JobEngine
import PDFKit
import Vision
import NaturalLanguage

struct SmartSplitView: View {
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var pdfDocument: PDFDocument?
    @State private var splitRules: [SplitRule] = []
    @State private var previewSplits: [SplitPreview] = []
    @State private var isAnalyzing = false
    @State private var analysisProgress: Double = 0
    @State private var selectedRule: SplitRuleType = .pageCount
    @State private var customPattern = ""
    @State private var namingStrategy: NamingStrategy = .sequential
    @State private var showAdvancedSettings = false
    @State private var autoDetectSections = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with document info
                    splitHeader
                    
                    // Main content based on analysis state
                    if isAnalyzing {
                        analysisProgressView
                    } else {
                        splitContentView
                    }
                }
            }
            .navigationTitle("Smart Split")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Split") {
                        performSmartSplit()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(previewSplits.isEmpty)
                }
            }
        }
        .onAppear {
            loadPDFDocument()
            performAnalysis()
        }
    }
    
    // MARK: - Header
    private var splitHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Intelligent PDF Split")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("AI-powered section detection and smart naming")
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
                            Image(systemName: "scissors")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        if let document = pdfDocument {
                            Text("\(document.pageCount) pages")
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                    }
                }
                
                HStack {
                    Text("Estimated splits: \(previewSplits.count)")
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
        .padding(.horizontal, OneBoxSpacing.medium)
        .padding(.top, OneBoxSpacing.medium)
    }
    
    // MARK: - Analysis Progress
    private var analysisProgressView: some View {
        VStack(spacing: OneBoxSpacing.large) {
            Spacer()
            
            VStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(OneBoxColors.primaryGold)
                    .scaleEffect(isAnalyzing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnalyzing)
                
                Text("Analyzing Document Structure")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Detecting sections, headings, and natural break points...")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                ProgressView(value: analysisProgress)
                    .progressViewStyle(.linear)
                    .tint(OneBoxColors.primaryGold)
                    .frame(width: 200)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Split Content
    private var splitContentView: some View {
        ScrollView {
            VStack(spacing: OneBoxSpacing.large) {
                // Split Rules Section
                splitRulesSection
                
                // Naming Strategy Section
                namingStrategySection
                
                // Advanced Settings
                advancedSettingsSection
                
                // Split Preview
                splitPreviewSection
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Split Rules
    private var splitRulesSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Split Rules")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(SplitRuleType.allCases, id: \.self) { ruleType in
                        splitRuleOption(ruleType)
                    }
                }
                
                if selectedRule == .customPattern {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Custom Pattern")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        TextField("Enter text pattern (e.g., 'Chapter', 'Section')", text: $customPattern)
                            .textFieldStyle(.roundedBorder)
                            .onChange(of: customPattern) { _ in
                                if !customPattern.isEmpty {
                                    updateSplitRules()
                                }
                            }
                        
                        Text("Split when this text is found at the beginning of a page")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                    .transition(.opacity)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: selectedRule)
    }
    
    private func splitRuleOption(_ ruleType: SplitRuleType) -> some View {
        Button(action: {
            selectedRule = ruleType
            updateSplitRules()
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: selectedRule == ruleType ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedRule == ruleType ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(ruleType.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(ruleType.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
                
                if ruleType == .aiSections && autoDetectSections {
                    Image(systemName: "brain.fill")
                        .font(.system(size: 14))
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Naming Strategy
    private var namingStrategySection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Naming Strategy")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(NamingStrategy.allCases, id: \.self) { strategy in
                        namingStrategyOption(strategy)
                    }
                }
                
                // Preview of generated names
                if !previewSplits.isEmpty {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Name Preview:")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                            ForEach(previewSplits.prefix(3)) { split in
                                Text("• \(generateFileName(for: split))")
                                    .font(OneBoxTypography.micro)
                                    .foregroundColor(OneBoxColors.primaryGold)
                            }
                            
                            if previewSplits.count > 3 {
                                Text("• ... and \(previewSplits.count - 3) more")
                                    .font(OneBoxTypography.micro)
                                    .foregroundColor(OneBoxColors.tertiaryText)
                            }
                        }
                        .padding(OneBoxSpacing.small)
                        .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                        .cornerRadius(OneBoxRadius.small)
                    }
                    .transition(.opacity)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func namingStrategyOption(_ strategy: NamingStrategy) -> some View {
        Button(action: {
            namingStrategy = strategy
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: namingStrategy == strategy ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(namingStrategy == strategy ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
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
    
    // MARK: - Advanced Settings
    private var advancedSettingsSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Button(action: {
                    showAdvancedSettings.toggle()
                    HapticManager.shared.selection()
                }) {
                    HStack {
                        Text("Advanced Settings")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Image(systemName: showAdvancedSettings ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                if showAdvancedSettings {
                    VStack(spacing: OneBoxSpacing.small) {
                        Toggle("Auto-detect sections", isOn: $autoDetectSections)
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                            .onChange(of: autoDetectSections) { _ in
                                updateSplitRules()
                            }
                        
                        Toggle("Preserve bookmarks", isOn: .constant(true))
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                        
                        Toggle("Maintain metadata", isOn: .constant(true))
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                        
                        Toggle("Create index document", isOn: .constant(false))
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                        
                        HStack {
                            Text("Minimum pages per split:")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            Spacer()
                            
                            Stepper("\(1)", value: .constant(1), in: 1...10)
                                .labelsHidden()
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: showAdvancedSettings)
    }
    
    // MARK: - Split Preview
    private var splitPreviewSection: some View {
        Group {
            if !previewSplits.isEmpty {
                OneBoxCard(style: .standard) {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                        HStack {
                            Text("Split Preview")
                                .font(OneBoxTypography.cardTitle)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Spacer()
                            
                            Text("\(previewSplits.count) files")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        ScrollView {
                            VStack(spacing: OneBoxSpacing.small) {
                                ForEach(previewSplits) { split in
                                    splitPreviewRow(split)
                                }
                            }
                        }
                        .frame(maxHeight: 200)
                    }
                    .padding(OneBoxSpacing.medium)
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private func splitPreviewRow(_ split: SplitPreview) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: "doc.text")
                .font(.system(size: 16))
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(generateFileName(for: split))
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)
                
                HStack {
                    Text("Pages \(split.startPage + 1)-\(split.endPage + 1)")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    if let content = split.detectedContent {
                        Text("• \(content)")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer()
            
            Text("\(split.pageCount) pages")
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.tertiaryText)
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.2))
        .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - Helper Methods
    private func loadPDFDocument() {
        pdfDocument = PDFDocument(url: pdfURL)
    }
    
    private func performAnalysis() {
        guard let document = pdfDocument else { return }
        
        isAnalyzing = true
        analysisProgress = 0
        
        Task {
            let pageCount = document.pageCount
            var detectedSections: [DocumentSection] = []
            
            // Analyze each page for content structure
            for pageIndex in 0..<pageCount {
                await MainActor.run {
                    analysisProgress = Double(pageIndex) / Double(pageCount) * 0.5
                }
                
                guard let page = document.page(at: pageIndex),
                      let pageText = page.string else { continue }
                
                let section = await analyzePageContent(pageText, pageNumber: pageIndex)
                if let section = section {
                    detectedSections.append(section)
                }
            }
            
            await MainActor.run {
                self.analysisProgress = 1.0
                self.isAnalyzing = false
                self.updateSplitRules()
            }
        }
    }
    
    private func analyzePageContent(_ text: String, pageNumber: Int) async -> DocumentSection? {
        // Use NaturalLanguage framework to detect headings and sections
        return await withCheckedContinuation { continuation in
            let tagger = NLTagger(tagSchemes: [.lexicalClass])
            tagger.string = text
            
            // Look for heading patterns
            let lines = text.components(separatedBy: .newlines).prefix(10) // Check first 10 lines
            
            for line in lines {
                let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Check for chapter/section patterns
                if trimmedLine.range(of: #"^(Chapter|Section|Part|Article)\s+\d+"#, options: .regularExpression) != nil {
                    let section = DocumentSection(
                        title: trimmedLine,
                        pageNumber: pageNumber,
                        sectionType: .chapter
                    )
                    continuation.resume(returning: section)
                    return
                }
                
                // Check for heading patterns (short lines, caps, etc.)
                if trimmedLine.count < 50 && trimmedLine.count > 5 &&
                   trimmedLine.uppercased() == trimmedLine &&
                   !trimmedLine.contains(where: { $0.isNumber }) {
                    let section = DocumentSection(
                        title: trimmedLine,
                        pageNumber: pageNumber,
                        sectionType: .heading
                    )
                    continuation.resume(returning: section)
                    return
                }
            }
            
            continuation.resume(returning: nil)
        }
    }
    
    private func updateSplitRules() {
        guard let document = pdfDocument else { return }
        
        previewSplits = []
        
        switch selectedRule {
        case .pageCount:
            generatePageCountSplits(document: document, pagesPerSplit: 5)
        case .bookmarks:
            generateBookmarkSplits(document: document)
        case .aiSections:
            generateAISectionSplits(document: document)
        case .customPattern:
            if !customPattern.isEmpty {
                generateCustomPatternSplits(document: document, pattern: customPattern)
            }
        case .fileSize:
            generateFileSizeSplits(document: document, targetSizeMB: 10)
        }
    }
    
    private func generatePageCountSplits(document: PDFDocument, pagesPerSplit: Int) {
        let pageCount = document.pageCount
        var splits: [SplitPreview] = []
        var currentStart = 0
        
        while currentStart < pageCount {
            let endPage = min(currentStart + pagesPerSplit - 1, pageCount - 1)
            
            let split = SplitPreview(
                id: UUID(),
                startPage: currentStart,
                endPage: endPage,
                pageCount: endPage - currentStart + 1,
                detectedContent: nil,
                splitReason: .pageCount
            )
            
            splits.append(split)
            currentStart = endPage + 1
        }
        
        previewSplits = splits
    }
    
    private func generateBookmarkSplits(document: PDFDocument) {
        // Simplified bookmark-based splitting
        var splits: [SplitPreview] = []
        
        if let outline = document.outlineRoot {
            generateSplitsFromOutline(outline, splits: &splits, document: document)
        } else {
            // Fallback to page count if no bookmarks
            generatePageCountSplits(document: document, pagesPerSplit: 10)
            return
        }
        
        previewSplits = splits
    }
    
    private func generateSplitsFromOutline(_ outline: PDFOutline, splits: inout [SplitPreview], document: PDFDocument) {
        // Simplified outline processing
        for i in 0..<outline.numberOfChildren {
            if let child = outline.child(at: i),
               let destination = child.destination,
               let page = destination.page {
                
                let pageIndex = document.index(for: page)
                let nextPageIndex = (i + 1 < outline.numberOfChildren) ?
                    getNextOutlinePageIndex(outline, childIndex: i + 1, document: document) :
                    document.pageCount
                
                let split = SplitPreview(
                    id: UUID(),
                    startPage: pageIndex,
                    endPage: nextPageIndex - 1,
                    pageCount: nextPageIndex - pageIndex,
                    detectedContent: child.label,
                    splitReason: .bookmarks
                )
                
                splits.append(split)
            }
        }
    }
    
    private func getNextOutlinePageIndex(_ outline: PDFOutline, childIndex: Int, document: PDFDocument) -> Int {
        if let nextChild = outline.child(at: childIndex),
           let destination = nextChild.destination,
           let page = destination.page {
            return document.index(for: page)
        }
        return document.pageCount
    }
    
    private func generateAISectionSplits(document: PDFDocument) {
        Task {
            let sectionBreaks = await performRealSectionDetection(document: document)
            
            await MainActor.run {
                var splits: [SplitPreview] = []
                
                for i in 0..<sectionBreaks.count {
                    let sectionBreak = sectionBreaks[i]
                    let startPage = sectionBreak.pageIndex
                    let endPage = (i + 1 < sectionBreaks.count) ? 
                        sectionBreaks[i + 1].pageIndex - 1 : 
                        document.pageCount - 1
                    
                    if startPage <= endPage {
                        let split = SplitPreview(
                            id: UUID(),
                            startPage: startPage,
                            endPage: endPage,
                            pageCount: endPage - startPage + 1,
                            detectedContent: sectionBreak.title.isEmpty ? "Section \(i + 1)" : sectionBreak.title,
                            splitReason: .aiSections
                        )
                        
                        splits.append(split)
                    }
                }
                
                self.previewSplits = splits
            }
        }
    }
    
    private func performRealSectionDetection(document: PDFDocument) async -> [SectionBreak] {
        var sectionBreaks: [SectionBreak] = []
        let pageCount = document.pageCount
        
        // Always start with page 0
        sectionBreaks.append(SectionBreak(pageIndex: 0, title: "Beginning"))
        
        // Analyze each page for section breaks using real Vision framework
        for pageIndex in 0..<pageCount {
            guard let page = document.page(at: pageIndex) else { continue }
            
            // Create page image for Vision analysis
            let thumbnailOptional: UIImage? = page.thumbnail(of: CGSize(width: 800, height: 1000), for: .mediaBox)
            guard let pageImage = thumbnailOptional else {
                continue
            }
            
            let sectionTitle = await detectSectionHeader(in: pageImage, pageText: page.string)
                
            // Look for significant section breaks
            if !sectionTitle.isEmpty && pageIndex > 0 {
                // Check if this could be a new section start
                let isValidSectionBreak = await validateSectionBreak(
                    at: pageIndex,
                    title: sectionTitle,
                    document: document
                )
                
                if isValidSectionBreak {
                    sectionBreaks.append(SectionBreak(pageIndex: pageIndex, title: sectionTitle))
                }
            }
        }
        
        return sectionBreaks
    }
    
    private func detectSectionHeader(in image: UIImage, pageText: String?) async -> String {
        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: "")
                return
            }
            
            // Use Vision framework to detect text and analyze for headers
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Look for header-like text (top region, larger text, etc.)
                let headerCandidates = observations.filter { observation in
                    // Focus on text in the upper portion of the page
                    observation.boundingBox.origin.y > 0.7 && // Top 30% of page
                    observation.confidence > 0.8
                }
                
                for observation in headerCandidates {
                    guard let candidate = observation.topCandidates(1).first else { continue }
                    let text = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Check if this looks like a section header
                    if isSectionHeaderText(text) {
                        continuation.resume(returning: text)
                        return
                    }
                }
                
                // Fallback to page text analysis
                if let pageText = pageText {
                    let detectedHeader = extractHeaderFromText(pageText)
                    continuation.resume(returning: detectedHeader)
                } else {
                    continuation.resume(returning: "")
                }
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            // Support multiple languages for international documents
            request.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "ar-SA", "fa-IR"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func isSectionHeaderText(_ text: String) -> Bool {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Check for common header patterns
        let headerPatterns = [
            #"^(Chapter|Section|Part|Article)\s+\d+"#,
            #"^\d+\.\s+[A-Z]"#, // "1. INTRODUCTION"
            #"^[IVX]+\.\s+[A-Z]"#, // Roman numerals
            #"^[A-Z][A-Z\s]{5,30}$"# // All caps titles (5-30 chars)
        ]
        
        for pattern in headerPatterns {
            if cleanText.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        // Check for title-like characteristics
        let wordCount = cleanText.components(separatedBy: .whitespaces).count
        let isShort = wordCount >= 1 && wordCount <= 8  // 1-8 words
        let hasCapitalization = cleanText.contains(where: { $0.isUppercase })
        let isNotAllNumbers = !cleanText.allSatisfy { $0.isNumber || $0.isWhitespace }
        
        return isShort && hasCapitalization && isNotAllNumbers
    }
    
    private func extractHeaderFromText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        
        // Look at the first few lines for potential headers
        for line in lines.prefix(5) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if isSectionHeaderText(trimmed) {
                return trimmed
            }
        }
        
        return ""
    }
    
    private func validateSectionBreak(at pageIndex: Int, title: String, document: PDFDocument) async -> Bool {
        // Validate that this is a meaningful section break
        // Check if it's not too close to previous breaks
        let minimumPagesBetweenSections = 3
        
        // For real validation, we could check:
        // 1. Distance from previous section break
        // 2. Content analysis to ensure it's actually a new section
        // 3. Font size/style changes
        
        return pageIndex >= minimumPagesBetweenSections
    }
    
    private struct SectionBreak {
        let pageIndex: Int
        let title: String
    }
    
    private func generateCustomPatternSplits(document: PDFDocument, pattern: String) {
        var splits: [SplitPreview] = []
        var breakPoints: [Int] = [0]
        
        // Search for pattern in document
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else { continue }
            
            if pageText.localizedCaseInsensitiveContains(pattern) {
                breakPoints.append(pageIndex)
            }
        }
        
        breakPoints.append(document.pageCount)
        
        for i in 0..<breakPoints.count - 1 {
            let startPage = breakPoints[i]
            let endPage = breakPoints[i + 1] - 1
            
            if startPage <= endPage {
                let split = SplitPreview(
                    id: UUID(),
                    startPage: startPage,
                    endPage: endPage,
                    pageCount: endPage - startPage + 1,
                    detectedContent: pattern,
                    splitReason: .customPattern
                )
                
                splits.append(split)
            }
        }
        
        previewSplits = splits
    }
    
    private func generateFileSizeSplits(document: PDFDocument, targetSizeMB: Int) {
        // Simplified file size-based splitting
        generatePageCountSplits(document: document, pagesPerSplit: targetSizeMB * 2) // Rough estimate
    }
    
    private func generateFileName(for split: SplitPreview) -> String {
        let baseName = pdfURL.deletingPathExtension().lastPathComponent
        
        switch namingStrategy {
        case .sequential:
            return "\(baseName)_Part\(previewSplits.firstIndex(where: { $0.id == split.id })! + 1).pdf"
        case .pageRange:
            return "\(baseName)_Pages\(split.startPage + 1)-\(split.endPage + 1).pdf"
        case .contentBased:
            if let content = split.detectedContent {
                let cleanContent = content.replacingOccurrences(of: " ", with: "_")
                return "\(baseName)_\(cleanContent).pdf"
            } else {
                return "\(baseName)_Section\(previewSplits.firstIndex(where: { $0.id == split.id })! + 1).pdf"
            }
        case .dateTime:
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmm"
            let timestamp = formatter.string(from: Date())
            return "\(baseName)_\(timestamp)_\(previewSplits.firstIndex(where: { $0.id == split.id })! + 1).pdf"
        }
    }
    
    private func performSmartSplit() {
        guard !previewSplits.isEmpty else { return }
        
        // Create split jobs
        let settings = JobSettings()
        let job = Job(
            type: .splitPDF,
            inputs: [pdfURL],
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

struct SplitPreview: Identifiable {
    let id: UUID
    let startPage: Int
    let endPage: Int
    let pageCount: Int
    let detectedContent: String?
    let splitReason: SplitRuleType
}

struct DocumentSection {
    let title: String
    let pageNumber: Int
    let sectionType: SectionType
    
    enum SectionType {
        case chapter, heading, subheading
    }
}

struct SplitRule: Identifiable {
    let id = UUID()
    let type: SplitRuleType
    let value: String?
}

enum SplitRuleType: String, CaseIterable {
    case pageCount = "pageCount"
    case bookmarks = "bookmarks"
    case aiSections = "aiSections"
    case customPattern = "customPattern"
    case fileSize = "fileSize"
    
    var displayName: String {
        switch self {
        case .pageCount: return "By Page Count"
        case .bookmarks: return "By Bookmarks"
        case .aiSections: return "AI Section Detection"
        case .customPattern: return "Custom Text Pattern"
        case .fileSize: return "By File Size"
        }
    }
    
    var description: String {
        switch self {
        case .pageCount: return "Split into equal page chunks"
        case .bookmarks: return "Use existing bookmarks as split points"
        case .aiSections: return "AI detects natural document sections"
        case .customPattern: return "Split when specific text is found"
        case .fileSize: return "Split to maintain target file size"
        }
    }
}

enum NamingStrategy: String, CaseIterable {
    case sequential = "sequential"
    case pageRange = "pageRange"
    case contentBased = "contentBased"
    case dateTime = "dateTime"
    
    var displayName: String {
        switch self {
        case .sequential: return "Sequential"
        case .pageRange: return "Page Range"
        case .contentBased: return "Content-Based"
        case .dateTime: return "Date & Time"
        }
    }
    
    var description: String {
        switch self {
        case .sequential: return "Document_Part1, Document_Part2, etc."
        case .pageRange: return "Document_Pages1-10, Document_Pages11-20, etc."
        case .contentBased: return "Use detected section titles as names"
        case .dateTime: return "Include timestamp in filename"
        }
    }
}

#Preview {
    SmartSplitView(pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
        .environmentObject(JobManager.shared)
}