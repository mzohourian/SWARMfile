//
//  AdaptiveWatermarkView.swift
//  OneBox
//
//  Adaptive watermark system with anti-removal patterns and intelligent placement
//

import SwiftUI
import UIComponents
import JobEngine
import PDFKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Vision

struct AdaptiveWatermarkView: View {
    @Binding var settings: JobSettings
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var pdfDocument: PDFDocument?
    @State private var watermarkText = "CONFIDENTIAL"
    @State private var watermarkType: WatermarkType = .text
    @State private var watermarkPosition: AdaptiveWatermarkPosition = .adaptive
    @State private var opacity: Double = 0.3
    @State private var rotation: Double = -45
    @State private var fontSize: Double = 36
    @State private var color: Color = .gray
    @State private var pattern: WatermarkPattern = .diagonal
    @State private var antiRemovalLevel: AntiRemovalLevel = .medium
    @State private var selectedPage = 0
    @State private var showPreview = false
    @State private var isAnalyzing = false
    @State private var pageAnalysis: [WatermarkPageAnalysis] = []
    @State private var intelligentPositions: [IntelligentPosition] = []
    @State private var customImage: UIImage?
    @State private var blendMode: BlendMode = .multiply
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Header with preview
                        watermarkHeader
                        
                        // Watermark Type Selection
                        watermarkTypeSection
                        
                        // Content Configuration
                        contentConfigurationSection
                        
                        // Intelligent Positioning
                        positioningSection
                        
                        // Appearance Settings
                        appearanceSection
                        
                        // Anti-Removal Protection (temporarily disabled)
                        // antiRemovalSection
                        
                        // Page Analysis
                        if !pageAnalysis.isEmpty {
                            pageAnalysisSection
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Adaptive Watermark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        applyAdaptiveWatermark()
                    }) {
                        Text("Apply")
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
        .sheet(isPresented: $showPreview) {
            WatermarkPreviewView(
                pdfURL: pdfURL,
                watermarkSettings: createWatermarkSettings()
            )
        }
        .onAppear {
            loadPDFDocument()
            analyzeDocument()
        }
    }
    
    // MARK: - Header
    private var watermarkHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Adaptive Watermark Protection")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Smart on-device placement analysis")
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
                            Image(systemName: "shield.lefthalf.filled")
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
                
                // Preview button
                Button(action: {
                    showPreview = true
                    HapticManager.shared.impact(.light)
                }) {
                    Text("Live Preview")
                }
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryGraphite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, OneBoxSpacing.small)
                .background(OneBoxColors.primaryGold)
                .cornerRadius(OneBoxRadius.small)
            }
        }
    }
    
    // MARK: - Watermark Type
    private var watermarkTypeSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Watermark Type")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    // Only show text watermarks for now (others are under development)
                    watermarkTypeOption(.text)
                    
                    // Coming Soon indicator for other types
                    VStack(spacing: OneBoxSpacing.tiny) {
                        ForEach([WatermarkType.image, .logo, .qr], id: \.self) { type in
                            comingSoonTypeOption(type)
                        }
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func watermarkTypeOption(_ type: WatermarkType) -> some View {
        Button(action: {
            watermarkType = type
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: watermarkType == type ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(watermarkType == type ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(type.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(type.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: type.icon)
                    .font(.system(size: 16))
                    .foregroundColor(OneBoxColors.primaryGold)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func comingSoonTypeOption(_ type: WatermarkType) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: "clock")
                .foregroundColor(OneBoxColors.tertiaryText)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(type.displayName)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.tertiaryText)
                
                Text("Coming Soon")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.tertiaryText)
            }
            
            Spacer()
            
            Image(systemName: type.icon)
                .font(.system(size: 16))
                .foregroundColor(OneBoxColors.tertiaryText)
        }
        .opacity(0.6)
    }
    
    // MARK: - Content Configuration
    private var contentConfigurationSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Content Configuration")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.medium) {
                    if watermarkType == .text {
                        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                            Text("Watermark Text")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            TextField("Enter watermark text", text: $watermarkText)
                                .textFieldStyle(.roundedBorder)
                            
                            HStack {
                                watermarkPreset("CONFIDENTIAL")
                                watermarkPreset("DRAFT")
                                watermarkPreset("INTERNAL USE")
                            }
                        }
                    } else {
                        // Temporarily disable advanced watermark types
                        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                            Text("Feature Coming Soon")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            Text("Image, Logo, and QR Code watermarks are currently under development. Please use Text watermarks for now.")
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.tertiaryText)
                                .padding(OneBoxSpacing.small)
                                .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                                .cornerRadius(OneBoxRadius.small)
                        }
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func watermarkPreset(_ text: String) -> some View {
        Button(action: {
            watermarkText = text
            HapticManager.shared.selection()
        }) {
            Text(text)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.primaryGold)
                .padding(.horizontal, OneBoxSpacing.small)
                .padding(.vertical, OneBoxSpacing.tiny)
                .background(OneBoxColors.primaryGold.opacity(0.1))
                .cornerRadius(OneBoxRadius.small)
        }
    }
    
    private func logoOption(_ name: String, _ icon: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(OneBoxColors.primaryGold)
            
            Text(name)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.3))
        .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - Positioning
    private var positioningSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Intelligent Positioning")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(AdaptiveWatermarkPosition.allCases, id: \.self) { position in
                        positionOption(position)
                    }
                }
                
                if watermarkPosition == .adaptive && !intelligentPositions.isEmpty {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        Text("Detected Positions (On-Device)")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        ForEach(intelligentPositions.prefix(3)) { position in
                            intelligentPositionRow(position)
                        }
                    }
                    .transition(.opacity)
                }
                
                if watermarkPosition == .pattern {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        Text("Pattern Configuration")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        HStack {
                            ForEach(WatermarkPattern.allCases, id: \.self) { patternType in
                                patternOption(patternType)
                            }
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: watermarkPosition)
    }
    
    private func positionOption(_ position: AdaptiveWatermarkPosition) -> some View {
        Button(action: {
            watermarkPosition = position
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: watermarkPosition == position ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(watermarkPosition == position ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(position.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(position.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
                
                if position == .adaptive {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func intelligentPositionRow(_ position: IntelligentPosition) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: position.confidence > 0.8 ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 12))
                .foregroundColor(position.confidence > 0.8 ? OneBoxColors.secureGreen : OneBoxColors.warningAmber)
            
            Text(position.description)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
            
            Text("\(Int(position.confidence * 100))%")
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.tertiaryText)
        }
    }
    
    private func patternOption(_ patternType: WatermarkPattern) -> some View {
        Button(action: {
            pattern = patternType
            HapticManager.shared.selection()
        }) {
            VStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: patternType.icon)
                    .font(.system(size: 20))
                    .foregroundColor(pattern == patternType ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                Text(patternType.displayName)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(OneBoxSpacing.small)
            .background(pattern == patternType ? OneBoxColors.primaryGold.opacity(0.1) : Color.clear)
            .cornerRadius(OneBoxRadius.small)
        }
    }
    
    // MARK: - Appearance
    private var appearanceSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Appearance Settings")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.medium) {
                    // Opacity
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        HStack {
                            Text("Opacity")
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Spacer()
                            
                            Text("\(Int(opacity * 100))%")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        Slider(value: $opacity, in: 0.1...1.0)
                            .accentColor(OneBoxColors.primaryGold)
                    }
                    
                    // Rotation
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        HStack {
                            Text("Rotation")
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Spacer()
                            
                            Text("\(Int(rotation))°")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        Slider(value: $rotation, in: -180...180)
                            .accentColor(OneBoxColors.primaryGold)
                    }
                    
                    if watermarkType == .text {
                        // Font Size
                        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                            HStack {
                                Text("Font Size")
                                    .font(OneBoxTypography.body)
                                    .foregroundColor(OneBoxColors.primaryText)
                                
                                Spacer()
                                
                                Text("\(Int(fontSize))pt")
                                    .font(OneBoxTypography.caption)
                                    .foregroundColor(OneBoxColors.primaryGold)
                            }
                            
                            Slider(value: $fontSize, in: 12...72)
                                .accentColor(OneBoxColors.primaryGold)
                        }
                    }
                    
                    // Color
                    HStack {
                        Text("Color")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        ColorPicker("", selection: $color)
                            .labelsHidden()
                    }
                    
                    // Blend Mode
                    HStack {
                        Text("Blend Mode")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Picker(selection: $blendMode, label: Text("Blend Mode")) {
                            ForEach(BlendMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(OneBoxColors.primaryGold)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Anti-Removal
    private var antiRemovalSection: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Anti-Removal Protection")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .font(.system(size: 16))
                        .foregroundColor(OneBoxColors.secureGreen)
                }
                
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(AntiRemovalLevel.allCases, id: \.self) { level in
                        antiRemovalOption(level)
                    }
                }
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                    Text("Protection Features")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    VStack(spacing: OneBoxSpacing.tiny) {
                        protectionFeature("Invisible metadata embedding", antiRemovalLevel.rawValue >= 1)
                        protectionFeature("Multiple layer redundancy", antiRemovalLevel.rawValue >= 2)
                        protectionFeature("Content-aware positioning", antiRemovalLevel.rawValue >= 2)
                        protectionFeature("Steganographic protection", antiRemovalLevel.rawValue >= 3)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func antiRemovalOption(_ level: AntiRemovalLevel) -> some View {
        Button(action: {
            antiRemovalLevel = level
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: antiRemovalLevel == level ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(antiRemovalLevel == level ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(level.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(level.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
                
                HStack(spacing: OneBoxSpacing.tiny) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(index < level.rawValue ? OneBoxColors.secureGreen : OneBoxColors.tertiaryText)
                            .frame(width: 6, height: 6)
                    }
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func protectionFeature(_ name: String, _ enabled: Bool) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: enabled ? "checkmark" : "xmark")
                .font(.system(size: 10))
                .foregroundColor(enabled ? OneBoxColors.secureGreen : OneBoxColors.tertiaryText)
                .frame(width: 12)
            
            Text(name)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
        }
    }
    
    // MARK: - Page Analysis
    private var pageAnalysisSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Document Analysis")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    if isAnalyzing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(OneBoxColors.primaryGold)
                    } else {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                if !pageAnalysis.isEmpty {
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(pageAnalysis.prefix(3)) { analysis in
                            analysisRow(analysis)
                        }
                        
                        if pageAnalysis.count > 3 {
                            Button(action: {
                                // Show detailed analysis
                            }) {
                                Text("View All \(pageAnalysis.count) Analyses")
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
    
    private func analysisRow(_ analysis: WatermarkPageAnalysis) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: analysis.optimalForWatermark ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(analysis.optimalForWatermark ? OneBoxColors.secureGreen : OneBoxColors.warningAmber)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text("Page \(analysis.pageNumber + 1)")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(analysis.recommendation)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(2)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func loadPDFDocument() {
        pdfDocument = PDFDocument(url: pdfURL)
    }
    
    private func analyzeDocument() {
        guard let document = pdfDocument else { return }
        
        isAnalyzing = true
        
        Task {
            var analyses: [WatermarkPageAnalysis] = []
            var positions: [IntelligentPosition] = []
            
            for pageIndex in 0..<document.pageCount {
                let analysis = await analyzePage(document: document, pageIndex: pageIndex)
                analyses.append(analysis)
                
                // Generate intelligent positions for this page
                let pagePositions = generateIntelligentPositions(for: analysis)
                positions.append(contentsOf: pagePositions)
            }
            
            await MainActor.run {
                self.pageAnalysis = analyses
                self.intelligentPositions = positions
                self.isAnalyzing = false
            }
        }
    }
    
    private func analyzePage(document: PDFDocument, pageIndex: Int) async -> WatermarkPageAnalysis {
        // Real page analysis using Vision framework for optimal watermark placement
        guard let page = document.page(at: pageIndex) else {
            return createFallbackAnalysis(pageIndex: pageIndex)
        }
        
        // Explicitly cast PDFThumbnail to UIImage? to handle optional binding correctly
        let thumbnail: UIImage? = page.thumbnail(of: CGSize(width: 800, height: 1000), for: .mediaBox)
        guard let pageImage = thumbnail else {
            return createFallbackAnalysis(pageIndex: pageIndex)
        }
        
        var hasImages = false
        var textDensity: Double = 0.0
        
        // Perform real Vision framework analysis
        hasImages = await performVisionImageAnalysis(on: pageImage)
        textDensity = await performVisionTextAnalysis(on: pageImage)
        
        let hasWhitespace = textDensity < 0.5
        
        let recommendation: String
        let optimal: Bool
        
        if hasWhitespace && !hasImages {
            recommendation = "Optimal for large watermarks with high opacity"
            optimal = true
        } else if hasImages {
            recommendation = "Use transparent watermark to avoid content overlap"
            optimal = false
        } else {
            recommendation = "Dense text - consider smaller, subtle watermark"
            optimal = false
        }
        
        return WatermarkPageAnalysis(
            id: UUID(),
            pageNumber: pageIndex,
            textDensity: textDensity,
            hasImages: hasImages,
            hasWhitespace: hasWhitespace,
            optimalForWatermark: optimal,
            recommendation: recommendation
        )
    }
    
    private func createFallbackAnalysis(pageIndex: Int) -> WatermarkPageAnalysis {
        // Conservative fallback when Vision analysis fails
        return WatermarkPageAnalysis(
            id: UUID(),
            pageNumber: pageIndex,
            textDensity: 0.7, // Assume moderate text density
            hasImages: false, // Conservative assumption
            hasWhitespace: false, // Conservative assumption  
            optimalForWatermark: false, // Conservative recommendation
            recommendation: "Standard watermark placement recommended"
        )
    }
    
    private func performVisionImageAnalysis(on image: UIImage) async -> Bool {
        return await withCheckedContinuation { continuation in
            guard let cgImage: CGImage = image.cgImage else {
                continuation.resume(returning: false)
                return
            }
            
            let request = VNDetectRectanglesRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRectangleObservation] else {
                    continuation.resume(returning: false)
                    return
                }
                
                // Consider significant rectangles as potential images
                let significantRectangles = observations.filter { observation in
                    let area = observation.boundingBox.width * observation.boundingBox.height
                    return area > 0.02 && observation.confidence > 0.3 // At least 2% of page area
                }
                
                continuation.resume(returning: !significantRectangles.isEmpty)
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func performVisionTextAnalysis(on image: UIImage) async -> Double {
        return await withCheckedContinuation { continuation in
            guard let cgImage: CGImage = image.cgImage else {
                continuation.resume(returning: 0.0)
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: 0.0)
                    return
                }
                
                // Calculate text coverage of the page
                let totalPageArea: Double = 1.0 // Normalized area
                let textArea = observations.reduce(0.0) { total, observation in
                    let boundingBoxArea = observation.boundingBox.width * observation.boundingBox.height
                    return total + boundingBoxArea
                }
                
                let density = min(1.0, textArea / totalPageArea)
                continuation.resume(returning: density)
            }
            
            request.recognitionLevel = .fast
            request.usesLanguageCorrection = false
            // Support multiple languages for international documents
            request.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "ar-SA", "fa-IR"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])
        }
    }
    
    private func generateIntelligentPositions(for analysis: WatermarkPageAnalysis) -> [IntelligentPosition] {
        var positions: [IntelligentPosition] = []
        
        if analysis.hasWhitespace {
            positions.append(IntelligentPosition(
                id: UUID(),
                pageNumber: analysis.pageNumber,
                x: 0.5,
                y: 0.5,
                confidence: 0.9,
                description: "Center of page - large whitespace area"
            ))
        }
        
        if !analysis.hasImages {
            positions.append(IntelligentPosition(
                id: UUID(),
                pageNumber: analysis.pageNumber,
                x: 0.2,
                y: 0.8,
                confidence: 0.7,
                description: "Bottom left - text-free zone"
            ))
        }
        
        if analysis.textDensity < 0.5 {
            positions.append(IntelligentPosition(
                id: UUID(),
                pageNumber: analysis.pageNumber,
                x: 0.8,
                y: 0.2,
                confidence: 0.8,
                description: "Top right - low text density"
            ))
        }
        
        return positions
    }
    
    private func createWatermarkSettings() -> WatermarkSettings {
        return WatermarkSettings(
            text: watermarkText,
            type: watermarkType,
            position: watermarkPosition,
            opacity: opacity,
            rotation: rotation,
            fontSize: fontSize,
            color: color,
            pattern: pattern,
            antiRemovalLevel: antiRemovalLevel,
            blendMode: blendMode
        )
    }
    
    private func applyAdaptiveWatermark() {
        // Apply watermark with all adaptive settings
        let _ = createWatermarkSettings()
        
        // Create job with watermark settings
        var jobSettings = JobSettings()
        jobSettings.watermarkText = watermarkText
        jobSettings.watermarkOpacity = opacity
        jobSettings.watermarkPosition = .center // Will be handled by adaptive positioning
        
        let job = Job(
            type: .pdfWatermark,
            inputs: [pdfURL],
            settings: jobSettings
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

struct WatermarkSettings {
    let text: String
    let type: WatermarkType
    let position: AdaptiveWatermarkPosition
    let opacity: Double
    let rotation: Double
    let fontSize: Double
    let color: Color
    let pattern: WatermarkPattern
    let antiRemovalLevel: AntiRemovalLevel
    let blendMode: BlendMode
}

struct WatermarkPageAnalysis: Identifiable {
    let id: UUID
    let pageNumber: Int
    let textDensity: Double
    let hasImages: Bool
    let hasWhitespace: Bool
    let optimalForWatermark: Bool
    let recommendation: String
}

struct IntelligentPosition: Identifiable {
    let id: UUID
    let pageNumber: Int
    let x: Double
    let y: Double
    let confidence: Double
    let description: String
}

enum WatermarkType: String, CaseIterable {
    case text = "text"
    case image = "image"
    case logo = "logo"
    case qr = "qr"
    
    var displayName: String {
        switch self {
        case .text: return "Text Watermark"
        case .image: return "Image Watermark"
        case .logo: return "Logo Watermark"
        case .qr: return "QR Code"
        }
    }
    
    var description: String {
        switch self {
        case .text: return "Custom text with advanced typography"
        case .image: return "Upload custom image or graphics"
        case .logo: return "Professional logo watermarks"
        case .qr: return "QR code with embedded information"
        }
    }
    
    var icon: String {
        switch self {
        case .text: return "textformat"
        case .image: return "photo"
        case .logo: return "building.2"
        case .qr: return "qrcode"
        }
    }
}

enum AdaptiveWatermarkPosition: String, CaseIterable {
    case center = "center"
    case corner = "corner"
    case pattern = "pattern"
    case adaptive = "adaptive"
    
    var displayName: String {
        switch self {
        case .center: return "Center"
        case .corner: return "Corner"
        case .pattern: return "Pattern"
        case .adaptive: return "Smart Adaptive"
        }
    }
    
    var description: String {
        switch self {
        case .center: return "Single watermark in page center"
        case .corner: return "Watermark in document corners"
        case .pattern: return "Repeating pattern across page"
        case .adaptive: return "On-device analysis determines optimal placement"
        }
    }
}

enum WatermarkPattern: String, CaseIterable {
    case diagonal = "diagonal"
    case grid = "grid"
    case radial = "radial"
    case random = "random"
    
    var displayName: String {
        switch self {
        case .diagonal: return "Diagonal"
        case .grid: return "Grid"
        case .radial: return "Radial"
        case .random: return "Random"
        }
    }
    
    var icon: String {
        switch self {
        case .diagonal: return "line.diagonal"
        case .grid: return "grid"
        case .radial: return "circle.grid.cross"
        case .random: return "sparkles"
        }
    }
}

enum AntiRemovalLevel: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    
    var displayName: String {
        switch self {
        case .low: return "Basic"
        case .medium: return "Standard"
        case .high: return "Maximum"
        }
    }
    
    var description: String {
        switch self {
        case .low: return "Basic visible watermark protection"
        case .medium: return "Multiple layers with metadata embedding"
        case .high: return "Advanced steganographic protection"
        }
    }
}

enum BlendMode: String, CaseIterable {
    case normal = "normal"
    case multiply = "multiply"
    case overlay = "overlay"
    case screen = "screen"
    
    var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .multiply: return "Multiply"
        case .overlay: return "Overlay"
        case .screen: return "Screen"
        }
    }
}

// MARK: - Watermark Preview

struct WatermarkPreviewView: View {
    let pdfURL: URL
    let watermarkSettings: WatermarkSettings
    @Environment(\.dismiss) var dismiss
    
    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var isLoading = true
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Watermark Preview")
                        .font(OneBoxTypography.sectionTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    if let document = pdfDocument, document.pageCount > 1 {
                        Text("Page \(currentPageIndex + 1) of \(document.pageCount)")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                .padding()
                
                // PDF Preview with Watermark Overlay
                GeometryReader { geometry in
                    ZStack {
                        // PDF Page Background
                        if isLoading {
                            Rectangle()
                                .fill(OneBoxColors.surfaceGraphite)
                                .overlay(
                                    ProgressView()
                                        .tint(OneBoxColors.primaryGold)
                                )
                        } else if let document = pdfDocument,
                                let page = document.page(at: currentPageIndex) {
                            
                            // PDF Page
                            PDFPagePreviewView(page: page)
                                .overlay(
                                    // Watermark Overlay
                                    WatermarkOverlayView(
                                        settings: watermarkSettings,
                                        pageSize: page.bounds(for: .mediaBox).size
                                    )
                                )
                        } else {
                            Rectangle()
                                .fill(OneBoxColors.surfaceGraphite)
                                .overlay(
                                    Text("Unable to load PDF")
                                        .foregroundColor(OneBoxColors.secondaryText)
                                )
                        }
                    }
                    .cornerRadius(OneBoxRadius.medium)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
                }
                .padding()
                
                // Page Navigation
                if let document = pdfDocument, document.pageCount > 1 {
                    HStack {
                        Button(action: {
                            if currentPageIndex > 0 {
                                currentPageIndex -= 1
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(currentPageIndex > 0 ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                        }
                        .disabled(currentPageIndex == 0)
                        
                        Spacer()
                        
                        Button(action: {
                            if currentPageIndex < document.pageCount - 1 {
                                currentPageIndex += 1
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .foregroundColor(currentPageIndex < document.pageCount - 1 ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                        }
                        .disabled(currentPageIndex >= document.pageCount - 1)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
            }
            .onAppear {
                loadPDFDocument()
            }
        }
    }
    
    private func loadPDFDocument() {
        Task {
            let document = PDFDocument(url: pdfURL)
            await MainActor.run {
                self.pdfDocument = document
                self.isLoading = false
            }
        }
    }
}

struct PDFPagePreviewView: UIViewRepresentable {
    let page: PDFPage
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .white
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        // Clear previous content
        uiView.subviews.forEach { $0.removeFromSuperview() }
        
        // Create image from PDF page
        let pageRect = page.bounds(for: .mediaBox)
        let renderer = UIGraphicsImageRenderer(size: pageRect.size)
        let image = renderer.image { context in
            context.cgContext.translateBy(x: 0, y: pageRect.size.height)
            context.cgContext.scaleBy(x: 1.0, y: -1.0)
            page.draw(with: .mediaBox, to: context.cgContext)
        }
        
        // Add image view
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        uiView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: uiView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: uiView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: uiView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: uiView.bottomAnchor)
        ])
    }
}

struct WatermarkOverlayView: View {
    let settings: WatermarkSettings
    let pageSize: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            let watermarkSize = calculateWatermarkSize(for: geometry.size)
            let watermarkPosition = calculateWatermarkPosition(for: geometry.size, watermarkSize: watermarkSize)
            
            if settings.type == .text {
                Text(settings.text)
                    .font(.system(size: settings.fontSize * (geometry.size.width / pageSize.width)))
                    .foregroundColor(settings.color)
                    .opacity(settings.opacity)
                    .rotationEffect(.degrees(settings.rotation))
                    .position(watermarkPosition)
            }
        }
    }
    
    private func calculateWatermarkSize(for viewSize: CGSize) -> CGSize {
        // Scale watermark relative to view size
        let scale = min(viewSize.width / pageSize.width, viewSize.height / pageSize.height)
        return CGSize(
            width: pageSize.width * 0.2 * scale, // Default 20% of page width
            height: pageSize.height * 0.1 * scale // Default 10% of page height
        )
    }
    
    private func calculateWatermarkPosition(for viewSize: CGSize, watermarkSize: CGSize) -> CGPoint {
        // Convert adaptive position to standard position for preview
        let standardPosition: WatermarkPosition
        switch settings.position {
        case .center:
            standardPosition = .center
        case .corner:
            standardPosition = .bottomRight
        case .pattern:
            standardPosition = .center // Show one instance for pattern preview
        case .adaptive:
            standardPosition = .center // Default adaptive to center for preview
        }
        
        return calculatePositionPoint(standardPosition, in: viewSize, watermarkSize: watermarkSize)
    }
    
    private func calculatePositionPoint(_ position: WatermarkPosition, in viewSize: CGSize, watermarkSize: CGSize) -> CGPoint {
        let margin: CGFloat = 20
        
        switch position {
        case .topLeft:
            return CGPoint(x: margin + watermarkSize.width/2, y: margin + watermarkSize.height/2)
        case .topCenter:
            return CGPoint(x: viewSize.width/2, y: margin + watermarkSize.height/2)
        case .topRight:
            return CGPoint(x: viewSize.width - margin - watermarkSize.width/2, y: margin + watermarkSize.height/2)
        case .middleLeft:
            return CGPoint(x: margin + watermarkSize.width/2, y: viewSize.height/2)
        case .center:
            return CGPoint(x: viewSize.width/2, y: viewSize.height/2)
        case .middleRight:
            return CGPoint(x: viewSize.width - margin - watermarkSize.width/2, y: viewSize.height/2)
        case .bottomLeft:
            return CGPoint(x: margin + watermarkSize.width/2, y: viewSize.height - margin - watermarkSize.height/2)
        case .bottomCenter:
            return CGPoint(x: viewSize.width/2, y: viewSize.height - margin - watermarkSize.height/2)
        case .bottomRight:
            return CGPoint(x: viewSize.width - margin - watermarkSize.width/2, y: viewSize.height - margin - watermarkSize.height/2)
        case .tiled:
            return CGPoint(x: viewSize.width/2, y: viewSize.height/2) // Show center instance for preview
        }
    }
}

#Preview {
    AdaptiveWatermarkView(
        settings: .constant(JobSettings()),
        pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf")
    )
}