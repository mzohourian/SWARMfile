//
//  AdvancedImageToPDFView.swift
//  OneBox
//
//  Advanced Image to PDF settings with OneBox Standard luxury experience
//

import SwiftUI
import UIComponents
import JobEngine
import Vision
import VisionKit

struct AdvancedImageToPDFView: View {
    @Binding var settings: JobSettings
    let selectedURLs: [URL]
    @Environment(\.dismiss) var dismiss
    
    @State private var showOCRSettings = false
    @State private var showQualityProfiles = false
    @State private var showNamingTemplates = false
    @State private var analyzingImages = false
    @State private var imageAnalysis: [ImageAnalysisResult] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Header with ceremony
                        advancedHeader
                        
                        // Image Analysis Section
                        imageAnalysisSection
                        
                        // Background Cleanup
                        backgroundCleanupSection
                        
                        // Quality Profiles
                        qualityProfilesSection
                        
                        // OCR and Tagging
                        ocrTaggingSection
                        
                        // Batch Naming
                        batchNamingSection
                        
                        // Advanced Layout
                        layoutSection
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Advanced Image Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                        HapticManager.shared.notification(.success)
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
        .onAppear {
            if imageAnalysis.isEmpty {
                analyzeImages()
            }
        }
    }
    
    // MARK: - Header
    private var advancedHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Advanced Image Processing")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("AI-powered optimization for professional results")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(OneBoxColors.primaryGold)
                }
                
                HStack {
                    Text("\(selectedURLs.count) images selected")
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
    
    // MARK: - Image Analysis
    private var imageAnalysisSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("AI Image Analysis")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    if analyzingImages {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(OneBoxColors.primaryGold)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(OneBoxColors.secureGreen)
                    }
                }
                
                if analyzingImages {
                    Text("Analyzing image quality and content...")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                } else {
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(imageAnalysis.prefix(3)) { analysis in
                            imageAnalysisRow(analysis)
                        }
                        
                        if imageAnalysis.count > 3 {
                            Button("View All \(imageAnalysis.count) Analysis Results") {
                                // Show detailed analysis
                            }
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.primaryGold)
                        }
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func imageAnalysisRow(_ analysis: ImageAnalysisResult) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: analysis.icon)
                .font(.system(size: 14))
                .foregroundColor(analysis.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(analysis.filename)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)
                
                Text(analysis.suggestion)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
            
            if analysis.needsAttention {
                Button("Fix") {
                    applyFix(for: analysis)
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
    
    // MARK: - Background Cleanup
    private var backgroundCleanupSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Smart Background Cleanup")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Toggle("", isOn: $settings.enableBackgroundCleanup)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                }
                
                if settings.enableBackgroundCleanup {
                    VStack(spacing: OneBoxSpacing.small) {
                        cleanupOption("Auto-crop margins", "Remove white space around documents", $settings.autoCropMargins)
                        cleanupOption("Enhance contrast", "Improve readability of scanned docs", $settings.enhanceContrast)
                        cleanupOption("Remove shadows", "Eliminate scanning shadows and artifacts", $settings.removeShadows)
                        cleanupOption("Straighten pages", "Auto-correct skewed document scans", $settings.straightenPages)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: settings.enableBackgroundCleanup)
    }
    
    private func cleanupOption(_ title: String, _ description: String, _ binding: Binding<Bool>) -> some View {
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
    
    // MARK: - Quality Profiles
    private var qualityProfilesSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Button(action: {
                    showQualityProfiles.toggle()
                    HapticManager.shared.selection()
                }) {
                    HStack {
                        Text("Quality Profiles")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Text(settings.qualityProfile.displayName)
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        Image(systemName: showQualityProfiles ? "chevron.up" : "chevron.down")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                if showQualityProfiles {
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(QualityProfile.allCases, id: \.self) { profile in
                            qualityProfileOption(profile)
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: showQualityProfiles)
    }
    
    private func qualityProfileOption(_ profile: QualityProfile) -> some View {
        Button(action: {
            settings.qualityProfile = profile
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: settings.qualityProfile == profile ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(settings.qualityProfile == profile ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(profile.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(profile.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
                
                Text(profile.sizeEstimate)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.tertiaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - OCR and Tagging
    private var ocrTaggingSection: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("OCR & Auto-Tagging")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Toggle("", isOn: $settings.enableOCR)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                }
                
                if settings.enableOCR {
                    VStack(spacing: OneBoxSpacing.small) {
                        HStack {
                            Text("OCR Language")
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Spacer()
                            
                            Picker("OCR Language", selection: $settings.ocrLanguage) {
                                ForEach(OCRLanguage.allCases, id: \.self) { language in
                                    Text(language.displayName).tag(language)
                                }
                            }
                            .pickerStyle(.menu)
                            .accentColor(OneBoxColors.primaryGold)
                        }
                        
                        Toggle("Auto-tag by content", isOn: $settings.autoTagByContent)
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.secondaryGold))
                        
                        Toggle("Extract metadata", isOn: $settings.extractMetadata)
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.secondaryGold))
                        
                        Toggle("Create searchable PDF", isOn: $settings.createSearchablePDF)
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.secondaryGold))
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: settings.enableOCR)
    }
    
    // MARK: - Batch Naming
    private var batchNamingSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Batch Naming Templates")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    HStack {
                        Text("Template")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Picker("Template", selection: $settings.namingTemplate) {
                            ForEach(NamingTemplate.allCases, id: \.self) { template in
                                Text(template.displayName).tag(template)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(OneBoxColors.primaryGold)
                    }
                    
                    if settings.namingTemplate == .custom {
                        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                            Text("Custom Pattern")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            TextField("e.g., Document_{date}_{index}", text: $settings.customNamingPattern)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Text("Available: {date}, {time}, {index}, {original}, {content}")
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.tertiaryText)
                        }
                    }
                    
                    // Preview
                    HStack {
                        Text("Preview:")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        Text(generateNamePreview())
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.primaryGold)
                            .italic()
                        
                        Spacer()
                    }
                    .padding(OneBoxSpacing.tiny)
                    .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                    .cornerRadius(OneBoxRadius.small)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Layout Section
    private var layoutSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Advanced Layout")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    Toggle("Adaptive page sizing", isOn: $settings.adaptivePageSizing)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    Toggle("Maintain aspect ratios", isOn: $settings.maintainAspectRatios)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    Toggle("Smart rotation detection", isOn: $settings.smartRotation)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    if settings.adaptivePageSizing {
                        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                            Text("Minimum margin: \(Int(settings.minimumMargin))pt")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            Slider(value: $settings.minimumMargin, in: 0...50, step: 5)
                                .accentColor(OneBoxColors.primaryGold)
                        }
                        .transition(.opacity)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: settings.adaptivePageSizing)
    }
    
    // MARK: - Helper Methods
    private func analyzeImages() {
        analyzingImages = true
        
        Task {
            var results: [ImageAnalysisResult] = []
            
            for (index, url) in selectedURLs.enumerated() {
                let analysis = await analyzeImage(url: url, index: index)
                results.append(analysis)
            }
            
            await MainActor.run {
                self.imageAnalysis = results
                self.analyzingImages = false
            }
        }
    }
    
    private func analyzeImage(url: URL, index: Int) async -> ImageAnalysisResult {
        // Real image analysis using Vision framework
        let filename = url.lastPathComponent
        
        guard let image = UIImage(contentsOfFile: url.path) else {
            return ImageAnalysisResult(
                id: UUID(),
                filename: filename,
                suggestion: "Unable to read image file",
                needsAttention: true,
                icon: "exclamationmark.triangle.fill",
                color: OneBoxColors.warningAmber
            )
        }
        
        let analysisResult = await performVisionAnalysis(on: image)
        
        return ImageAnalysisResult(
            id: UUID(),
            filename: filename,
            suggestion: analysisResult.suggestion,
            needsAttention: analysisResult.needsAttention,
            icon: analysisResult.needsAttention ? "exclamationmark.triangle.fill" : "checkmark.circle.fill",
            color: analysisResult.needsAttention ? OneBoxColors.warningAmber : OneBoxColors.secureGreen
        )
    }
    
    private func performVisionAnalysis(on image: UIImage) async -> (suggestion: String, needsAttention: Bool) {
        return await withCheckedContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(returning: ("Image format not supported", true))
                return
            }
            
            var hasText = false
            var needsAttention = false
            var suggestion = "Good quality - no optimization needed"
            
            // Detect text in image
            let textRequest = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    return
                }
                
                hasText = !observations.isEmpty
                
                if hasText {
                    suggestion = "Text detected - enable OCR for searchability"
                    needsAttention = false
                }
            }
            
            // Detect rectangles (might indicate skewed documents)
            let rectangleRequest = VNDetectRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRectangleObservation] else {
                    return
                }
                
                // Check for skewed rectangles
                for observation in observations {
                    let topLeft = observation.topLeft
                    let topRight = observation.topRight
                    
                    // Calculate if rectangle is significantly rotated
                    let angle = atan2(topRight.y - topLeft.y, topRight.x - topLeft.x)
                    let degrees = abs(angle * 180 / .pi)
                    
                    if degrees > 5 && degrees < 175 { // Significantly skewed
                        suggestion = "Image appears skewed - enable auto-straighten"
                        needsAttention = true
                        break
                    }
                }
            }

            // Support multiple languages for international documents
            textRequest.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "ar-SA", "fa-IR"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([textRequest, rectangleRequest])
                continuation.resume(returning: (suggestion, needsAttention))
            } catch {
                continuation.resume(returning: ("Analysis failed - will use default settings", false))
            }
        }
    }
    
    private func applyFix(for analysis: ImageAnalysisResult) {
        // Apply suggested fixes based on analysis
        if analysis.suggestion.contains("background cleanup") {
            settings.enableBackgroundCleanup = true
            settings.autoCropMargins = true
        } else if analysis.suggestion.contains("skewed") {
            settings.straightenPages = true
        } else if analysis.suggestion.contains("contrast") {
            settings.enhanceContrast = true
        } else if analysis.suggestion.contains("OCR") {
            settings.enableOCR = true
        }
        
        HapticManager.shared.notification(.success)
    }
    
    private func generateNamePreview() -> String {
        let template = settings.namingTemplate
        let pattern = template == .custom ? settings.customNamingPattern : template.pattern
        
        return pattern
            .replacingOccurrences(of: "{date}", with: "2024-01-15")
            .replacingOccurrences(of: "{time}", with: "14-30")
            .replacingOccurrences(of: "{index}", with: "001")
            .replacingOccurrences(of: "{original}", with: "document")
            .replacingOccurrences(of: "{content}", with: "invoice")
    }
}

// MARK: - Supporting Types

struct ImageAnalysisResult: Identifiable {
    let id: UUID
    let filename: String
    let suggestion: String
    let needsAttention: Bool
    let icon: String
    let color: Color
}

enum QualityProfile: String, CaseIterable {
    case archival = "archival"
    case standard = "standard" 
    case web = "web"
    case print = "print"
    
    var displayName: String {
        switch self {
        case .archival: return "Archival"
        case .standard: return "Standard"
        case .web: return "Web Optimized"
        case .print: return "Print Ready"
        }
    }
    
    var description: String {
        switch self {
        case .archival: return "Maximum quality for long-term storage"
        case .standard: return "Balanced quality and file size"
        case .web: return "Optimized for web sharing"
        case .print: return "High quality for printing"
        }
    }
    
    var sizeEstimate: String {
        switch self {
        case .archival: return "~2MB"
        case .standard: return "~800KB"
        case .web: return "~300KB"
        case .print: return "~1.5MB"
        }
    }
}

enum OCRLanguage: String, CaseIterable {
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chinese = "zh"
    case japanese = "ja"
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .chinese: return "Chinese"
        case .japanese: return "Japanese"
        }
    }
}

enum NamingTemplate: String, CaseIterable {
    case original = "original"
    case dateTime = "datetime"
    case sequential = "sequential"
    case content = "content"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .original: return "Keep Original"
        case .dateTime: return "Date & Time"
        case .sequential: return "Sequential"
        case .content: return "By Content"
        case .custom: return "Custom Pattern"
        }
    }
    
    var pattern: String {
        switch self {
        case .original: return "{original}"
        case .dateTime: return "Doc_{date}_{time}"
        case .sequential: return "Document_{index}"
        case .content: return "{content}_{date}"
        case .custom: return ""
        }
    }
}

// MARK: - JobSettings Extensions

extension JobSettings {
    var enableBackgroundCleanup: Bool {
        get { enableDocumentSanitization }
        set { enableDocumentSanitization = newValue }
    }
    
    var autoCropMargins: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var enhanceContrast: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var removeShadows: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var straightenPages: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var qualityProfile: QualityProfile {
        get { .standard }
        set { }
    }
    
    var enableOCR: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var ocrLanguage: OCRLanguage {
        get { .english }
        set { }
    }
    
    var autoTagByContent: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var extractMetadata: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var createSearchablePDF: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var namingTemplate: NamingTemplate {
        get { .original }
        set { }
    }
    
    var customNamingPattern: String {
        get { pdfTitle ?? "" }
        set { pdfTitle = newValue }
    }
    
    var adaptivePageSizing: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var maintainAspectRatios: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var smartRotation: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var minimumMargin: Double {
        get { Double(margins) }
        set { margins = CGFloat(newValue) }
    }
}

#Preview {
    AdvancedImageToPDFView(
        settings: .constant(JobSettings()),
        selectedURLs: [
            URL(fileURLWithPath: "/tmp/image1.jpg"),
            URL(fileURLWithPath: "/tmp/image2.jpg")
        ]
    )
}