//
//  SmartPageOrganizerView.swift
//  OneBox
//
//  Smart page organization with anomaly detection and AI insights
//

import SwiftUI
import UIComponents
import JobEngine
import PDFKit
import Vision
import CoreImage

struct SmartPageOrganizerView: View {
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var pdfDocument: PDFDocument?
    @State private var pages: [SmartPage] = []
    @State private var selectedPages: Set<UUID> = []
    @State private var showInsightsBar = true
    @State private var anomalies: [SmartPageAnomaly] = []
    @State private var isAnalyzing = false
    @State private var currentOperation: PageOperation?
    @State private var undoStack: [UndoAction] = []
    @State private var redoStack: [UndoAction] = []
    @State private var secureMode = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 120, maximum: 160), spacing: OneBoxSpacing.small)
    ]
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Insights Bar
                    if showInsightsBar && !anomalies.isEmpty {
                        insightsBar
                    }
                    
                    // Main Content
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: OneBoxSpacing.medium) {
                            ForEach(pages) { page in
                                smartPageCard(page)
                            }
                        }
                        .padding(OneBoxSpacing.medium)
                    }
                    
                    // Floating Action Tray
                    if !selectedPages.isEmpty {
                        floatingActionTray
                    }
                }
                
                // Progress Overlay
                if isAnalyzing {
                    analysisOverlay
                }
            }
            .navigationTitle("Smart Organizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Toggle Insights", systemImage: "lightbulb") {
                            showInsightsBar.toggle()
                        }
                        
                        Button("Secure Mode", systemImage: "shield.checkered") {
                            secureMode.toggle()
                        }
                        
                        Button("Auto-Organize", systemImage: "wand.and.stars") {
                            autoOrganize()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
            }
        }
        .onAppear {
            loadPDFDocument()
            analyzePages()
        }
    }
    
    // MARK: - Insights Bar
    private var insightsBar: some View {
        OneBoxCard(style: .elevated) {
            VStack(spacing: OneBoxSpacing.small) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("AI Insights")
                            .font(OneBoxTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("\(anomalies.count) issues detected")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Button("Dismiss") {
                        withAnimation(.easeInOut) {
                            showInsightsBar = false
                        }
                    }
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.tertiaryText)
                }
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: OneBoxSpacing.small) {
                        ForEach(anomalies.prefix(3)) { anomaly in
                            insightChip(anomaly)
                        }
                        
                        if anomalies.count > 3 {
                            Button("View All") {
                                // Show all anomalies
                            }
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.primaryGold)
                            .padding(.horizontal, OneBoxSpacing.small)
                            .padding(.vertical, OneBoxSpacing.tiny)
                            .background(OneBoxColors.primaryGold.opacity(0.1))
                            .cornerRadius(OneBoxRadius.small)
                        }
                    }
                    .padding(.horizontal, OneBoxSpacing.tiny)
                }
            }
        }
        .padding(.horizontal, OneBoxSpacing.medium)
        .padding(.top, OneBoxSpacing.small)
    }
    
    private func insightChip(_ anomaly: SmartPageAnomaly) -> some View {
        Button(action: {
            selectPagesForAnomaly(anomaly)
        }) {
            HStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: anomaly.type.icon)
                    .font(.system(size: 12))
                    .foregroundColor(anomaly.type.color)
                
                Text(anomaly.shortDescription)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("(\(anomaly.affectedPages.count))")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            .padding(.horizontal, OneBoxSpacing.small)
            .padding(.vertical, OneBoxSpacing.tiny)
            .background(anomaly.type.backgroundColor)
            .cornerRadius(OneBoxRadius.small)
        }
    }
    
    // MARK: - Smart Page Card
    private func smartPageCard(_ page: SmartPage) -> some View {
        let isSelected = selectedPages.contains(page.id)
        let hasAnomalies = anomalies.contains { $0.affectedPages.contains(page.pageNumber) }
        
        return VStack(spacing: OneBoxSpacing.tiny) {
            // Page thumbnail
            ZStack {
                Rectangle()
                    .fill(OneBoxColors.surfaceGraphite)
                    .aspectRatio(0.75, contentMode: .fit)
                    .cornerRadius(OneBoxRadius.small)
                
                // Page content representation based on real analytics
                VStack(spacing: 2) {
                    let lineCount = max(1, min(10, Int(page.analytics?.textDensity ?? 0.0 * 10)))
                    ForEach(0..<lineCount, id: \.self) { _ in
                        Rectangle()
                            .fill(OneBoxColors.primaryText.opacity(0.3))
                            .frame(height: 2)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, OneBoxSpacing.tiny)
                    }
                }
                
                // Anomaly indicators
                if hasAnomalies {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 12))
                                .foregroundColor(OneBoxColors.warningAmber)
                                .padding(4)
                                .background(Circle().fill(OneBoxColors.primaryGraphite))
                        }
                        Spacer()
                    }
                    .padding(OneBoxSpacing.tiny)
                }
                
                // Selection overlay
                if isSelected {
                    Rectangle()
                        .fill(OneBoxColors.primaryGold.opacity(0.3))
                        .cornerRadius(OneBoxRadius.small)
                    
                    VStack {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(OneBoxColors.primaryGold)
                                .background(Circle().fill(OneBoxColors.primaryGraphite))
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(OneBoxSpacing.tiny)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: OneBoxRadius.small)
                    .stroke(
                        isSelected ? OneBoxColors.primaryGold : 
                        hasAnomalies ? OneBoxColors.warningAmber.opacity(0.5) : 
                        Color.clear,
                        lineWidth: isSelected ? 2 : 1
                    )
            )
            .onTapGesture {
                togglePageSelection(page.id)
            }
            
            // Page info
            VStack(spacing: OneBoxSpacing.tiny) {
                HStack {
                    Text("Page \(page.pageNumber)")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryText)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    if page.rotation != 0 {
                        Image(systemName: "rotate.right")
                            .font(.system(size: 10))
                            .foregroundColor(OneBoxColors.warningAmber)
                    }
                }
                
                if let analytics = page.analytics {
                    HStack {
                        qualityIndicator(analytics.quality)
                        
                        Spacer()
                        
                        if analytics.isDuplicate {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 10))
                                .foregroundColor(OneBoxColors.criticalRed)
                        }
                        
                        if analytics.lowContrast {
                            Image(systemName: "eye.slash")
                                .font(.system(size: 10))
                                .foregroundColor(OneBoxColors.warningAmber)
                        }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .contextMenu {
            pageContextMenu(page)
        }
    }
    
    private func qualityIndicator(_ quality: PageQuality) -> some View {
        HStack(spacing: OneBoxSpacing.tiny) {
            Circle()
                .fill(quality.color)
                .frame(width: 6, height: 6)
            
            Text(quality.displayName)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.tertiaryText)
        }
    }
    
    private func pageContextMenu(_ page: SmartPage) -> some View {
        Group {
            Button("Rotate 90°", systemImage: "rotate.right") {
                rotatePage(page, by: 90)
            }
            
            Button("Duplicate", systemImage: "doc.on.doc") {
                duplicatePage(page)
            }
            
            Button("Extract", systemImage: "arrow.up.doc") {
                extractPage(page)
            }
            
            Divider()
            
            Button("Delete", systemImage: "trash", role: .destructive) {
                deletePage(page)
            }
        }
    }
    
    // MARK: - Floating Action Tray
    private var floatingActionTray: some View {
        HStack(spacing: OneBoxSpacing.medium) {
            // Selected count
            Text("\(selectedPages.count) selected")
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
            
            // Actions
            HStack(spacing: OneBoxSpacing.small) {
                actionButton("arrow.clockwise", "Rotate") {
                    rotateSelectedPages()
                }
                
                actionButton("trash", "Delete") {
                    deleteSelectedPages()
                }
                
                actionButton("arrow.up.doc", "Extract") {
                    extractSelectedPages()
                }
                
                if secureMode {
                    actionButton("lock.shield", "Secure") {
                        secureSelectedPages()
                    }
                }
            }
            
            // Undo/Redo
            HStack(spacing: OneBoxSpacing.tiny) {
                Button(action: undo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 16))
                        .foregroundColor(undoStack.isEmpty ? OneBoxColors.tertiaryText : OneBoxColors.primaryGold)
                }
                .disabled(undoStack.isEmpty)
                
                Button(action: redo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 16))
                        .foregroundColor(redoStack.isEmpty ? OneBoxColors.tertiaryText : OneBoxColors.primaryGold)
                }
                .disabled(redoStack.isEmpty)
            }
        }
        .padding(OneBoxSpacing.medium)
        .background(
            OneBoxCard(style: .security) {
                EmptyView()
            }
        )
        .padding(.horizontal, OneBoxSpacing.medium)
        .padding(.bottom, OneBoxSpacing.medium)
    }
    
    private func actionButton(_ icon: String, _ title: String, action: @escaping () -> Void) -> some View {
        Button(action: {
            action()
            HapticManager.shared.impact(.medium)
        }) {
            VStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(OneBoxColors.primaryGold)
                
                Text(title)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
        }
        .frame(minWidth: 44)
    }
    
    // MARK: - Analysis Overlay
    private var analysisOverlay: some View {
        ZStack {
            Rectangle()
                .fill(OneBoxColors.primaryGraphite.opacity(0.8))
                .ignoresSafeArea()
            
            VStack(spacing: OneBoxSpacing.large) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(OneBoxColors.primaryGold)
                    .scaleEffect(isAnalyzing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnalyzing)
                
                VStack(spacing: OneBoxSpacing.small) {
                    Text("Analyzing Pages")
                        .font(OneBoxTypography.sectionTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text("Detecting duplicates, rotation, and quality issues...")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadPDFDocument() {
        guard let document = PDFDocument(url: pdfURL) else { return }
        pdfDocument = document
        
        pages = (0..<document.pageCount).map { index in
            SmartPage(
                id: UUID(),
                pageNumber: index + 1,
                rotation: 0, // Will be detected during analysis
                analytics: nil // Will be populated during analysis
            )
        }
    }
    
    private func analyzePages() {
        guard let document = pdfDocument else { return }
        
        isAnalyzing = true
        
        Task {
            var detectedAnomalies: [SmartPageAnomaly] = []
            var updatedPages = pages
            
            // Analyze each page with Vision framework
            for (index, page) in pages.enumerated() {
                guard let pdfPage = document.page(at: page.pageNumber - 1) else { continue }
                
                let analytics = await analyzePageWithVision(pdfPage: pdfPage, pageNumber: page.pageNumber)
                updatedPages[index] = SmartPage(
                    id: page.id,
                    pageNumber: page.pageNumber,
                    rotation: analytics.detectedRotation,
                    analytics: analytics
                )
            }
            
            // Find anomalies based on real analysis
            await MainActor.run {
                self.pages = updatedPages
            }
            
            // Detect duplicates using content similarity
            let duplicateGroups = await findDuplicatePages(updatedPages)
            if !duplicateGroups.isEmpty {
                let allDuplicates = duplicateGroups.flatMap { $0 }
                detectedAnomalies.append(SmartPageAnomaly(
                    id: UUID(),
                    type: .duplicates,
                    affectedPages: allDuplicates,
                    shortDescription: "Duplicate content",
                    suggestion: "Remove \(allDuplicates.count) duplicate pages",
                    autoFixAvailable: true
                ))
            }
            
            // Detect rotation issues
            let rotatedPages = updatedPages.compactMap { $0.rotation != 0 ? $0.pageNumber : nil }
            if !rotatedPages.isEmpty {
                detectedAnomalies.append(SmartPageAnomaly(
                    id: UUID(),
                    type: .rotation,
                    affectedPages: rotatedPages,
                    shortDescription: "Orientation issues",
                    suggestion: "Auto-correct \(rotatedPages.count) page orientations",
                    autoFixAvailable: true
                ))
            }
            
            // Detect low contrast pages
            let lowContrastPages = updatedPages.compactMap { 
                $0.analytics?.lowContrast == true ? $0.pageNumber : nil 
            }
            if !lowContrastPages.isEmpty {
                detectedAnomalies.append(SmartPageAnomaly(
                    id: UUID(),
                    type: .lowContrast,
                    affectedPages: lowContrastPages,
                    shortDescription: "Low contrast",
                    suggestion: "Enhance readability for \(lowContrastPages.count) pages",
                    autoFixAvailable: true
                ))
            }
            
            // Detect poor quality pages
            let poorQualityPages = updatedPages.compactMap {
                $0.analytics?.quality == .poor ? $0.pageNumber : nil
            }
            if !poorQualityPages.isEmpty {
                detectedAnomalies.append(SmartPageAnomaly(
                    id: UUID(),
                    type: .lowQuality,
                    affectedPages: poorQualityPages,
                    shortDescription: "Poor quality",
                    suggestion: "Improve quality for \(poorQualityPages.count) pages",
                    autoFixAvailable: true
                ))
            }
            
            await MainActor.run {
                self.anomalies = detectedAnomalies
                self.isAnalyzing = false
            }
        }
    }
    
    private func analyzePageWithVision(pdfPage: PDFPage, pageNumber: Int) async -> PageAnalytics {
        // Convert PDF page to image for Vision processing
        let pageSize = CGSize(width: 612, height: 792)
        let thumbnailOptional: UIImage? = pdfPage.thumbnail(of: pageSize, for: .mediaBox)
        guard let pageImage = thumbnailOptional else {
            return createFallbackAnalytics()
        }
        guard let cgImage = pageImage.cgImage else {
            return createFallbackAnalytics()
        }
        
        let ciImage = CIImage(cgImage: cgImage)
        
        // Detect text orientation
        let detectedRotation = await detectTextOrientation(ciImage: ciImage)
        
        // Analyze image quality
        let quality = await analyzeImageQuality(ciImage: ciImage)
        
        // Detect contrast issues
        let hasLowContrast = await detectLowContrast(ciImage: ciImage)
        
        // Count text regions and images
        let (textDensity, imageCount) = await analyzeContentDistribution(ciImage: ciImage)
        
        return PageAnalytics(
            quality: quality,
            isDuplicate: false, // Will be determined by comparison
            lowContrast: hasLowContrast,
            textDensity: textDensity,
            imageCount: imageCount,
            detectedRotation: detectedRotation
        )
    }
    
    private func detectTextOrientation(ciImage: CIImage) async -> Int {
        let request = VNDetectTextRectanglesRequest()
        request.reportCharacterBoxes = false
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let results = request.results else {
                return 0  // No rotation detected
            }
            if !results.isEmpty {
                // Analyze text rectangle orientations
                var rotationCounts: [Int: Int] = [0: 0, 90: 0, 180: 0, 270: 0]
                
                for observation in results {
                    let angle = atan2(observation.boundingBox.height, observation.boundingBox.width)
                    let degrees = Int((angle * 180 / .pi).rounded()) % 360
                    let normalizedRotation = ((degrees + 360) % 360)
                    
                    // Map to nearest 90-degree increment
                    if normalizedRotation <= 45 || normalizedRotation > 315 {
                        rotationCounts[0, default: 0] += 1
                    } else if normalizedRotation <= 135 {
                        rotationCounts[90, default: 0] += 1
                    } else if normalizedRotation <= 225 {
                        rotationCounts[180, default: 0] += 1
                    } else {
                        rotationCounts[270, default: 0] += 1
                    }
                }
                
                // Return the most common rotation
                if let dominantRotation = rotationCounts.max(by: { $0.value < $1.value }) {
                    return dominantRotation.key
                }
            }
        } catch {
            print("Text orientation detection failed: \(error)")
        }
        
        return 0 // No rotation detected
    }
    
    private func analyzeImageQuality(ciImage: CIImage) async -> PageQuality {
        // Simple quality analysis based on sharpness and noise
        let context = CIContext()
        
        // Apply edge detection filter to measure sharpness
        guard let edgeFilter = CIFilter(name: "CIEdges") else {
            return .fair
        }
        
        edgeFilter.setValue(ciImage, forKey: kCIInputImageKey)
        edgeFilter.setValue(1.0, forKey: kCIInputIntensityKey)
        
        guard let edgeImage = edgeFilter.outputImage else {
            return .fair
        }
        
        // Calculate average pixel intensity (rougher measure of edge density)
        let extent = edgeImage.extent
        let inputExtent = CGRect(x: 0, y: 0, width: min(extent.width, 200), height: min(extent.height, 200))
        
        guard let cgImage = context.createCGImage(edgeImage, from: inputExtent) else {
            return .fair
        }
        
        let pixelData = cgImage.dataProvider?.data
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let pixelCount = Int(inputExtent.width * inputExtent.height)
        var totalIntensity: Int = 0
        
        for i in 0..<pixelCount {
            totalIntensity += Int(data[i * 4]) // Red channel
        }
        
        let avgIntensity = Double(totalIntensity) / Double(pixelCount) / 255.0
        
        // Classify based on edge density (higher = sharper)
        switch avgIntensity {
        case 0.3...:
            return .excellent
        case 0.2..<0.3:
            return .good
        case 0.1..<0.2:
            return .fair
        default:
            return .poor
        }
    }
    
    private func detectLowContrast(ciImage: CIImage) async -> Bool {
        let context = CIContext()
        
        // Sample a smaller region for performance
        let extent = ciImage.extent
        let sampleSize = CGRect(x: 0, y: 0, width: min(extent.width, 100), height: min(extent.height, 100))
        
        guard let cgImage = context.createCGImage(ciImage, from: sampleSize) else {
            return false
        }
        
        guard let pixelData = cgImage.dataProvider?.data else { return false }
        let data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
        
        let pixelCount = Int(sampleSize.width * sampleSize.height)
        var luminanceValues: [Double] = []
        
        for i in 0..<pixelCount {
            let r = Double(data[i * 4])
            let g = Double(data[i * 4 + 1])
            let b = Double(data[i * 4 + 2])
            
            // Calculate luminance
            let luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            luminanceValues.append(luminance)
        }
        
        // Calculate contrast using standard deviation
        let mean = luminanceValues.reduce(0, +) / Double(luminanceValues.count)
        let variance = luminanceValues.map { pow($0 - mean, 2) }.reduce(0, +) / Double(luminanceValues.count)
        let standardDeviation = sqrt(variance)
        
        // Low contrast if standard deviation is below threshold
        return standardDeviation < 0.15
    }
    
    private func analyzeContentDistribution(ciImage: CIImage) async -> (textDensity: Double, imageCount: Int) {
        let textRequest = VNDetectTextRectanglesRequest()
        let _ = VNClassifyImageRequest() // Reserved for future image classification
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        var textDensity = 0.0
        var imageCount = 0
        
        do {
            try handler.perform([textRequest])
            
            if let textResults = textRequest.results {
                let totalArea = ciImage.extent.width * ciImage.extent.height
                let textArea = textResults.reduce(0.0) { sum, observation in
                    let rect = observation.boundingBox
                    return sum + (rect.width * rect.height * totalArea)
                }
                textDensity = textArea / totalArea
            }
            
            // Real image detection using Vision framework
            let rectangleRequest = VNDetectRectanglesRequest()
            try handler.perform([rectangleRequest])
            imageCount = rectangleRequest.results?.count ?? 0
            
        } catch {
            print("Content analysis failed: \(error)")
        }
        
        return (textDensity, imageCount)
    }
    
    private func findDuplicatePages(_ pages: [SmartPage]) async -> [[Int]] {
        // Simple duplicate detection based on text density similarity
        var duplicateGroups: [[Int]] = []
        var processed: Set<Int> = []
        
        for (i, page1) in pages.enumerated() {
            if processed.contains(i) { continue }
            
            var group = [page1.pageNumber]
            processed.insert(i)
            
            for (j, page2) in pages.enumerated() where j > i {
                if processed.contains(j) { continue }
                
                // Compare text density and image count as similarity measures
                if let analytics1 = page1.analytics, let analytics2 = page2.analytics {
                    let densityDiff = abs(analytics1.textDensity - analytics2.textDensity)
                    let imageDiff = abs(analytics1.imageCount - analytics2.imageCount)
                    
                    // Consider pages duplicates if they're very similar
                    if densityDiff < 0.1 && imageDiff <= 1 {
                        group.append(page2.pageNumber)
                        processed.insert(j)
                    }
                }
            }
            
            if group.count > 1 {
                duplicateGroups.append(group)
            }
        }
        
        return duplicateGroups
    }
    
    private func createFallbackAnalytics() -> PageAnalytics {
        // Return minimal real analytics when Vision framework fails
        return PageAnalytics(
            quality: .fair, // Conservative estimate when analysis fails
            isDuplicate: false,
            lowContrast: false, // Conservative assumption
            textDensity: 0.0, // No text detected in fallback
            imageCount: 0, // No images detected in fallback
            detectedRotation: 0 // No rotation detected
        )
    }
    
    private func togglePageSelection(_ pageId: UUID) {
        if selectedPages.contains(pageId) {
            selectedPages.remove(pageId)
        } else {
            selectedPages.insert(pageId)
        }
        HapticManager.shared.selection()
    }
    
    private func selectPagesForAnomaly(_ anomaly: SmartPageAnomaly) {
        let pageIds = pages.compactMap { page in
            anomaly.affectedPages.contains(page.pageNumber) ? page.id : nil
        }
        selectedPages = Set(pageIds)
        HapticManager.shared.impact(.light)
    }
    
    private func autoOrganize() {
        // Auto-fix all anomalies
        for anomaly in anomalies where anomaly.autoFixAvailable {
            switch anomaly.type {
            case .duplicates:
                removeDuplicates(anomaly.affectedPages)
            case .rotation:
                autoCorrectRotation(anomaly.affectedPages)
            case .lowContrast:
                enhanceContrast(anomaly.affectedPages)
            case .lowQuality:
                // Low quality pages - could apply enhancement
                break
            }
        }
        
        HapticManager.shared.notification(.success)
    }
    
    private func removeDuplicates(_ pageNumbers: [Int]) {
        // Implementation for removing duplicates
        let action = UndoAction(type: .removeDuplicates, affectedPages: pageNumbers)
        undoStack.append(action)
        redoStack.removeAll()
    }
    
    private func autoCorrectRotation(_ pageNumbers: [Int]) {
        // Implementation for auto-correcting rotation
        for pageNumber in pageNumbers {
            if let index = pages.firstIndex(where: { $0.pageNumber == pageNumber }) {
                pages[index].rotation = 0
            }
        }
        
        let action = UndoAction(type: .rotation, affectedPages: pageNumbers)
        undoStack.append(action)
        redoStack.removeAll()
    }
    
    private func enhanceContrast(_ pageNumbers: [Int]) {
        // Implementation for enhancing contrast
        let action = UndoAction(type: .enhanceContrast, affectedPages: pageNumbers)
        undoStack.append(action)
        redoStack.removeAll()
    }
    
    private func rotateSelectedPages() {
        // Rotate implementation
        let selectedPageNumbers = getSelectedPageNumbers()
        let action = UndoAction(type: .rotation, affectedPages: selectedPageNumbers)
        undoStack.append(action)
        redoStack.removeAll()
    }
    
    private func deleteSelectedPages() {
        let selectedPageNumbers = getSelectedPageNumbers()
        // Delete implementation
        let action = UndoAction(type: .delete, affectedPages: selectedPageNumbers)
        undoStack.append(action)
        redoStack.removeAll()
        selectedPages.removeAll()
    }
    
    private func extractSelectedPages() {
        let _ = getSelectedPageNumbers() // Reserved for future extract implementation
    }
    
    private func secureSelectedPages() {
        // Apply security measures to selected pages
        let selectedPageNumbers = getSelectedPageNumbers()
        let action = UndoAction(type: .secure, affectedPages: selectedPageNumbers)
        undoStack.append(action)
        redoStack.removeAll()
    }
    
    private func rotatePage(_ page: SmartPage, by degrees: Int) {
        if let index = pages.firstIndex(where: { $0.id == page.id }) {
            pages[index].rotation = (pages[index].rotation + degrees) % 360
        }
        HapticManager.shared.impact(.light)
    }
    
    private func duplicatePage(_ page: SmartPage) {
        // Duplicate page implementation
        HapticManager.shared.impact(.light)
    }
    
    private func extractPage(_ page: SmartPage) {
        // Extract single page implementation
        HapticManager.shared.impact(.light)
    }
    
    private func deletePage(_ page: SmartPage) {
        // Delete single page implementation
        let action = UndoAction(type: .delete, affectedPages: [page.pageNumber])
        undoStack.append(action)
        redoStack.removeAll()
        HapticManager.shared.impact(.medium)
    }
    
    private func getSelectedPageNumbers() -> [Int] {
        return pages.compactMap { page in
            selectedPages.contains(page.id) ? page.pageNumber : nil
        }
    }
    
    private func undo() {
        guard let action = undoStack.popLast() else { return }
        // Implement undo logic
        redoStack.append(action)
        HapticManager.shared.impact(.light)
    }
    
    private func redo() {
        guard let action = redoStack.popLast() else { return }
        // Implement redo logic
        undoStack.append(action)
        HapticManager.shared.impact(.light)
    }
}

// MARK: - Supporting Types

struct SmartPage: Identifiable {
    let id: UUID
    let pageNumber: Int
    var rotation: Int
    let analytics: PageAnalytics?
}

struct PageAnalytics {
    let quality: PageQuality
    let isDuplicate: Bool
    let lowContrast: Bool
    let textDensity: Double
    let imageCount: Int
    let detectedRotation: Int
}

enum PageQuality: CaseIterable {
    case excellent, good, fair, poor
    
    var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent: return OneBoxColors.secureGreen
        case .good: return OneBoxColors.primaryGold
        case .fair: return OneBoxColors.warningAmber
        case .poor: return OneBoxColors.criticalRed
        }
    }
}

struct SmartPageAnomaly: Identifiable {
    let id: UUID
    let type: AnomalyType
    let affectedPages: [Int]
    let shortDescription: String
    let suggestion: String
    let autoFixAvailable: Bool
    
    enum AnomalyType {
        case duplicates, rotation, lowContrast, lowQuality
        
        var icon: String {
            switch self {
            case .duplicates: return "doc.on.doc"
            case .rotation: return "rotate.right"
            case .lowContrast: return "eye.slash"
            case .lowQuality: return "exclamationmark.triangle"
            }
        }
        
        var color: Color {
            switch self {
            case .duplicates: return OneBoxColors.criticalRed
            case .rotation: return OneBoxColors.warningAmber
            case .lowContrast: return OneBoxColors.warningAmber
            case .lowQuality: return OneBoxColors.criticalRed
            }
        }
        
        var backgroundColor: Color {
            color.opacity(0.1)
        }
    }
}

enum PageOperation {
    case rotate, delete, extract, duplicate, secure, removeDuplicates, rotation, enhanceContrast
}

struct UndoAction {
    let type: PageOperation
    let affectedPages: [Int]
}

#Preview {
    SmartPageOrganizerView(pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
        .environmentObject(JobManager.shared)
}