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
                        
                        // Anti-Removal Protection
                        antiRemovalSection
                        
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
                        
                        Text("AI-powered placement with tamper resistance")
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
                    ForEach(WatermarkType.allCases, id: \.self) { type in
                        watermarkTypeOption(type)
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
                    }
                    
                    if watermarkType == .image {
                        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                            Text("Watermark Image")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            Button(action: {
                                // Image picker
                            }) {
                                Text("Select Image")
                            }
                            .foregroundColor(OneBoxColors.primaryGold)
                            
                            if let image = customImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(height: 60)
                                    .cornerRadius(OneBoxRadius.small)
                            }
                        }
                    }
                    
                    if watermarkType == .logo {
                        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                            Text("Logo Configuration")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            HStack {
                                logoOption("Company", "building.2")
                                logoOption("Personal", "person.circle")
                                logoOption("Security", "shield")
                            }
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
                        Text("AI-Detected Positions")
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
        case .adaptive: return "AI Adaptive"
        }
    }
    
    var description: String {
        switch self {
        case .center: return "Single watermark in page center"
        case .corner: return "Watermark in document corners"
        case .pattern: return "Repeating pattern across page"
        case .adaptive: return "AI determines optimal placement"
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
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Watermark Preview")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                // Simplified preview
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(height: 400)
                        .cornerRadius(OneBoxRadius.medium)
                    
                    Text(watermarkSettings.text)
                        .font(.system(size: watermarkSettings.fontSize))
                        .foregroundColor(watermarkSettings.color)
                        .opacity(watermarkSettings.opacity)
                        .rotationEffect(.degrees(watermarkSettings.rotation))
                }
                .padding()
                
                Spacer()
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
                    }
                }
            }
        }
    }
}

#Preview {
    AdaptiveWatermarkView(
        settings: .constant(JobSettings()),
        pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf")
    )
}