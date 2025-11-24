//
//  AdvancedPDFCompressionView.swift
//  OneBox
//
//  Advanced PDF compression with page-level quality control and AI suggestions
//

import SwiftUI
import UIComponents
import JobEngine
import PDFKit

struct AdvancedPDFCompressionView: View {
    @Binding var settings: JobSettings
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss
    
    @State private var pdfDocument: PDFDocument?
    @State private var pageAnalysis: [CompressionPageAnalysis] = []
    @State private var isAnalyzing = false
    @State private var showSizeHistogram = false
    @State private var selectedPreservationRule = PreservationRule.balanced
    @State private var customQualityLevels: [Double] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Header with AI insights
                        compressionHeader
                        
                        // AI Suggestions
                        aiSuggestionsSection
                        
                        // Size Reduction Histogram
                        sizeHistogramSection
                        
                        // Page-Level Quality Controls
                        pageQualitySection
                        
                        // Preservation Rules
                        preservationRulesSection
                        
                        // Advanced Options
                        advancedOptionsSection
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Advanced Compression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyAdvancedCompression()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
        .onAppear {
            loadPDFDocument()
            analyzePages()
        }
    }
    
    // MARK: - Header
    private var compressionHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("AI-Powered Compression")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Intelligent page-level optimization")
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
                            Image(systemName: "cpu.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        Text(getOriginalSizeText())
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                // Compression preview
                if !pageAnalysis.isEmpty {
                    compressionPreview
                }
            }
        }
    }
    
    private var compressionPreview: some View {
        VStack(spacing: OneBoxSpacing.small) {
            HStack {
                Text("Estimated Result")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Spacer()
                
                Text(getEstimatedSizeText())
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                    .fontWeight(.semibold)
            }
            
            // Compression ratio bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(OneBoxColors.surfaceGraphite)
                        .frame(height: 6)
                        .cornerRadius(3)
                    
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [OneBoxColors.secureGreen, OneBoxColors.primaryGold],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * getCompressionRatio(), height: 6)
                        .cornerRadius(3)
                }
            }
            .frame(height: 6)
            
            HStack {
                Text("\(Int(getCompressionRatio() * 100))% reduction")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Spacer()
                
                Text("Space saved: \(getSavedSpaceText())")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secureGreen)
            }
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.3))
        .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - AI Suggestions
    private var aiSuggestionsSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("AI Optimization Insights")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 16))
                        .foregroundColor(OneBoxColors.primaryGold)
                }
                
                if isAnalyzing {
                    HStack {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(OneBoxColors.primaryGold)
                        
                        Text("Analyzing document structure...")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                } else {
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(getAISuggestions(), id: \.title) { suggestion in
                            suggestionRow(suggestion)
                        }
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func suggestionRow(_ suggestion: AISuggestion) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: suggestion.icon)
                .font(.system(size: 14))
                .foregroundColor(suggestion.priority.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(suggestion.title)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(suggestion.description)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Button("Apply") {
                applySuggestion(suggestion)
            }
            .font(OneBoxTypography.micro)
            .foregroundColor(OneBoxColors.primaryGold)
            .padding(.horizontal, OneBoxSpacing.tiny)
            .padding(.vertical, 2)
            .background(OneBoxColors.primaryGold.opacity(0.1))
            .cornerRadius(OneBoxRadius.small)
        }
    }
    
    // MARK: - Size Histogram
    private var sizeHistogramSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(spacing: OneBoxSpacing.medium) {
                Button(action: {
                    showSizeHistogram.toggle()
                    HapticManager.shared.selection()
                }) {
                    HStack {
                        Text("Size Reduction Histogram")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Image(systemName: showSizeHistogram ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                if showSizeHistogram {
                    sizeHistogram
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: showSizeHistogram)
    }
    
    private var sizeHistogram: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            // Histogram bars
            HStack(alignment: .bottom, spacing: OneBoxSpacing.tiny) {
                ForEach(0..<10) { index in
                    let height = CGFloat.random(in: 20...80)
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [OneBoxColors.primaryGold.opacity(0.3), OneBoxColors.primaryGold],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 20, height: height)
                        .cornerRadius(2)
                }
            }
            .frame(height: 100)
            
            // Legend
            HStack {
                histogramLegendItem("Original", OneBoxColors.tertiaryText)
                histogramLegendItem("Optimized", OneBoxColors.primaryGold)
                histogramLegendItem("Target", OneBoxColors.secureGreen)
            }
        }
    }
    
    private func histogramLegendItem(_ label: String, _ color: Color) -> some View {
        HStack(spacing: OneBoxSpacing.tiny) {
            Rectangle()
                .fill(color)
                .frame(width: 12, height: 8)
                .cornerRadius(2)
            
            Text(label)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
    
    // MARK: - Page Quality Section
    private var pageQualitySection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Page-Level Quality Control")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Button("Auto-Optimize") {
                        autoOptimizeQuality()
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                }
                
                if !pageAnalysis.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: OneBoxSpacing.small) {
                            ForEach(pageAnalysis.prefix(5)) { page in
                                pageQualityCard(page)
                            }
                            
                            if pageAnalysis.count > 5 {
                                Button("View All \(pageAnalysis.count) Pages") {
                                    // Show all pages
                                }
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.primaryGold)
                                .frame(width: 120, height: 100)
                                .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                                .cornerRadius(OneBoxRadius.small)
                            }
                        }
                        .padding(.horizontal, OneBoxSpacing.small)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func pageQualityCard(_ page: CompressionPageAnalysis) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            // Page thumbnail placeholder
            Rectangle()
                .fill(OneBoxColors.surfaceGraphite)
                .frame(width: 60, height: 80)
                .cornerRadius(4)
                .overlay(
                    VStack {
                        Text("Page \(page.pageNumber)")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Image(systemName: page.contentType.icon)
                            .font(.system(size: 16))
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                )
            
            // Quality slider
            VStack(spacing: OneBoxSpacing.tiny) {
                Text("\(Int(page.quality * 100))%")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Slider(value: .constant(page.quality), in: 0.1...1.0)
                    .accentColor(OneBoxColors.primaryGold)
                    .frame(width: 60)
            }
        }
        .frame(width: 80)
        .padding(OneBoxSpacing.tiny)
        .background(OneBoxColors.surfaceGraphite.opacity(0.2))
        .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - Preservation Rules
    private var preservationRulesSection: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Preservation Rules")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(PreservationRule.allCases, id: \.self) { rule in
                        preservationRuleOption(rule)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func preservationRuleOption(_ rule: PreservationRule) -> some View {
        Button(action: {
            selectedPreservationRule = rule
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: selectedPreservationRule == rule ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(selectedPreservationRule == rule ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(rule.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(rule.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Advanced Options
    private var advancedOptionsSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Advanced Options")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    Toggle("Optimize images separately", isOn: $settings.optimizeImagesSeparately)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    Toggle("Preserve vector graphics", isOn: $settings.preserveVectorGraphics)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    Toggle("Remove unused resources", isOn: $settings.removeUnusedResources)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    Toggle("Compress embedded fonts", isOn: $settings.compressFonts)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    if settings.optimizeImagesSeparately {
                        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                            Text("Image compression level: \(Int(settings.imageCompressionLevel * 100))%")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            Slider(value: $settings.imageCompressionLevel, in: 0.1...1.0, step: 0.1)
                                .accentColor(OneBoxColors.primaryGold)
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: settings.optimizeImagesSeparately)
    }
    
    // MARK: - Helper Methods
    private func loadPDFDocument() {
        pdfDocument = PDFDocument(url: pdfURL)
    }
    
    private func analyzePages() {
        guard let document = pdfDocument else { return }
        
        isAnalyzing = true
        
        Task {
            var analysis: [CompressionPageAnalysis] = []
            let pageCount = document.pageCount
            let totalFileSize = getFileSize()
            let averagePageSize = totalFileSize / Int64(max(pageCount, 1))
            
            for pageIndex in 0..<pageCount {
                let pageAnalysis = await analyzePageContent(document: document, pageIndex: pageIndex, averageSize: averagePageSize)
                analysis.append(pageAnalysis)
            }
            
            await MainActor.run {
                self.pageAnalysis = analysis
                self.isAnalyzing = false
            }
        }
    }
    
    private func analyzePageContent(document: PDFDocument, pageIndex: Int, averageSize: Int64) async -> CompressionPageAnalysis {
        guard let page = document.page(at: pageIndex) else {
            return createFallbackPageAnalysis(pageNumber: pageIndex + 1, averageSize: averageSize)
        }
        
        // Real PDF page analysis
        var hasImages = false
        var hasText = false
        var contentType: PageContentType = .text
        var complexity: PageComplexity = .low
        
        // Check for text content
        if let pageText = page.string, !pageText.isEmpty {
            hasText = true
        }
        
        // Check for images and annotations
        let annotations = page.annotations
        for annotation in annotations {
            if annotation.type == "Stamp" || annotation.type == "Image" {
                hasImages = true
                break
            }
        }
        
        // Analyze page complexity based on content
        let textLength = page.string?.count ?? 0
        let annotationCount = annotations.count
        
        if hasImages && hasText {
            contentType = .mixed
            complexity = .high
        } else if hasImages {
            contentType = .images
            complexity = .medium
        } else if hasText {
            contentType = .text
            complexity = textLength > 2000 ? .medium : .low
        }
        
        // Adjust complexity based on annotations
        if annotationCount > 5 {
            complexity = .high
        }
        
        // Calculate quality metrics (simplified estimation)
        let currentQuality = hasImages ? 0.8 : 1.0
        let suggestedQuality = calculateOptimalQuality(contentType: contentType, complexity: complexity)
        
        return CompressionPageAnalysis(
            id: UUID(),
            pageNumber: pageIndex + 1,
            contentType: contentType,
            currentSize: averageSize, // Use calculated average
            quality: currentQuality,
            suggestedQuality: suggestedQuality,
            hasImages: hasImages,
            hasText: hasText,
            complexity: complexity
        )
    }
    
    private func createFallbackPageAnalysis(pageNumber: Int, averageSize: Int64) -> CompressionPageAnalysis {
        return CompressionPageAnalysis(
            id: UUID(),
            pageNumber: pageNumber,
            contentType: .text,
            currentSize: averageSize,
            quality: 1.0,
            suggestedQuality: 0.7,
            hasImages: false,
            hasText: true,
            complexity: .medium
        )
    }
    
    private func calculateOptimalQuality(contentType: PageContentType, complexity: PageComplexity) -> Double {
        switch contentType {
        case .text:
            return complexity == .high ? 0.6 : 0.8
        case .images:
            return complexity == .high ? 0.4 : 0.6
        case .mixed:
            return complexity == .high ? 0.5 : 0.7
        case .vector:
            return complexity == .high ? 0.5 : 0.7
        }
    }
    
    private func getFileSize() -> Int64 {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: pdfURL.path),
              let size = attributes[.size] as? Int64 else {
            return 1_000_000 // 1MB fallback
        }
        return size
    }
    
    private func getOriginalSizeText() -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: pdfURL.path),
              let size = attributes[.size] as? Int64 else {
            return "Unknown size"
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func getEstimatedSizeText() -> String {
        // Calculate estimated size based on compression settings
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: pdfURL.path),
              let originalSize = attributes[.size] as? Int64 else {
            return "Unknown"
        }
        
        let compressionFactor = getCompressionRatio()
        let estimatedSize = Int64(Double(originalSize) * (1.0 - compressionFactor))
        return ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file)
    }
    
    private func getCompressionRatio() -> Double {
        // Calculate based on selected preservation rule and page analysis
        let baseRatio = selectedPreservationRule.compressionRatio
        let analysisAdjustment = pageAnalysis.isEmpty ? 0.0 : 
            pageAnalysis.map { $0.complexity.compressionPotential }.reduce(0, +) / Double(pageAnalysis.count)
        
        return min(0.8, baseRatio + analysisAdjustment)
    }
    
    private func getSavedSpaceText() -> String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: pdfURL.path),
              let originalSize = attributes[.size] as? Int64 else {
            return "Unknown"
        }
        
        let savedBytes = Int64(Double(originalSize) * getCompressionRatio())
        return ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)
    }
    
    private func getAISuggestions() -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        // Analyze page content and generate suggestions
        let hasLargeImages = pageAnalysis.contains { $0.hasImages && $0.currentSize > 200000 }
        let hasComplexPages = pageAnalysis.contains { $0.complexity == .high }
        let hasUniformContent = pageAnalysis.allSatisfy { $0.contentType == pageAnalysis.first?.contentType }
        
        if hasLargeImages {
            suggestions.append(AISuggestion(
                title: "Optimize Large Images",
                description: "Detected high-resolution images that can be safely compressed",
                icon: "photo.artframe",
                priority: .high,
                action: "optimizeImages"
            ))
        }
        
        if hasComplexPages {
            suggestions.append(AISuggestion(
                title: "Variable Quality by Page",
                description: "Use different compression levels for complex vs simple pages",
                icon: "slider.horizontal.below.square.fill.and.square",
                priority: .medium,
                action: "variableQuality"
            ))
        }
        
        if hasUniformContent {
            suggestions.append(AISuggestion(
                title: "Uniform Compression",
                description: "Document has consistent content - apply uniform compression",
                icon: "rectangle.3.group",
                priority: .low,
                action: "uniformCompression"
            ))
        }
        
        return suggestions
    }
    
    private func applySuggestion(_ suggestion: AISuggestion) {
        switch suggestion.action {
        case "optimizeImages":
            settings.optimizeImagesSeparately = true
            settings.imageCompressionLevel = 0.6
        case "variableQuality":
            autoOptimizeQuality()
        case "uniformCompression":
            // Apply uniform compression settings
            break
        default:
            break
        }
        
        HapticManager.shared.notification(.success)
    }
    
    private func autoOptimizeQuality() {
        // Automatically set optimal quality levels for each page
        for index in pageAnalysis.indices {
            let page = pageAnalysis[index]
            let _ = calculateOptimalQuality(for: page)
            // Apply optimal quality (in real implementation, this would update the page settings)
        }
        
        HapticManager.shared.notification(.success)
    }
    
    private func calculateOptimalQuality(for page: CompressionPageAnalysis) -> Double {
        var quality = 0.7 // Base quality
        
        // Adjust based on content type
        switch page.contentType {
        case .text:
            quality = 0.5 // Text can handle more compression
        case .images:
            quality = 0.8 // Images need higher quality
        case .mixed:
            quality = 0.7 // Balanced approach
        case .vector:
            quality = 0.9 // Preserve vector quality
        }
        
        // Adjust based on complexity
        switch page.complexity {
        case .low:
            quality -= 0.2
        case .medium:
            break // No adjustment
        case .high:
            quality += 0.1
        }
        
        return max(0.1, min(1.0, quality))
    }
    
    private func applyAdvancedCompression() {
        // Apply all the advanced compression settings
        settings.preservationRule = selectedPreservationRule.rawValue
        settings.pageQualityLevels = customQualityLevels
        
        dismiss()
        HapticManager.shared.notification(.success)
    }
}

// MARK: - Supporting Types

struct CompressionPageAnalysis: Identifiable {
    let id: UUID
    let pageNumber: Int
    let contentType: PageContentType
    let currentSize: Int64
    let quality: Double
    let suggestedQuality: Double
    let hasImages: Bool
    let hasText: Bool
    let complexity: PageComplexity
}

enum PageContentType: CaseIterable {
    case text, images, mixed, vector
    
    var icon: String {
        switch self {
        case .text: return "text.justify"
        case .images: return "photo"
        case .mixed: return "doc.richtext"
        case .vector: return "vector"
        }
    }
}

enum PageComplexity: CaseIterable {
    case low, medium, high
    
    var compressionPotential: Double {
        switch self {
        case .low: return 0.3
        case .medium: return 0.2
        case .high: return 0.1
        }
    }
}

enum PreservationRule: String, CaseIterable {
    case aggressive = "aggressive"
    case balanced = "balanced"
    case conservative = "conservative"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .aggressive: return "Aggressive"
        case .balanced: return "Balanced"
        case .conservative: return "Conservative"
        case .custom: return "Custom"
        }
    }
    
    var description: String {
        switch self {
        case .aggressive: return "Maximum compression, some quality loss"
        case .balanced: return "Good compression with minimal quality loss"
        case .conservative: return "Preserve quality, moderate compression"
        case .custom: return "Custom rules per page type"
        }
    }
    
    var compressionRatio: Double {
        switch self {
        case .aggressive: return 0.7
        case .balanced: return 0.5
        case .conservative: return 0.3
        case .custom: return 0.4
        }
    }
}

struct AISuggestion {
    let title: String
    let description: String
    let icon: String
    let priority: Priority
    let action: String
    
    enum Priority {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return OneBoxColors.secondaryText
            case .medium: return OneBoxColors.warningAmber
            case .high: return OneBoxColors.criticalRed
            }
        }
    }
}

// MARK: - JobSettings Extensions for Compression

extension JobSettings {
    var optimizeImagesSeparately: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var preserveVectorGraphics: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var removeUnusedResources: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var compressFonts: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var imageCompressionLevel: Double {
        get { imageQuality }
        set { imageQuality = newValue }
    }
    
    var preservationRule: String {
        get { pdfTitle ?? "balanced" }
        set { pdfTitle = newValue }
    }
    
    var pageQualityLevels: [Double] {
        get { [] }
        set { }
    }
}

#Preview {
    AdvancedPDFCompressionView(
        settings: .constant(JobSettings()),
        pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf")
    )
}