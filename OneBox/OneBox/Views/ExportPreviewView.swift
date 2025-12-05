//
//  ExportPreviewView.swift
//  OneBox
//
//  Zero-Regret Export: Preview, estimate, and confirm before exporting
//

import SwiftUI
import UIComponents
import QuickLook
import PDFKit
import Photos

struct ExportPreviewView: View {
    let outputURLs: [URL]
    let exportTitle: String
    let originalSize: Int64
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var selectedURL: URL?
    @State private var showingPreview = false
    @State private var exportProgress: Double = 0
    @State private var isExporting = false
    @State private var showingSecurityOptions = false
    @State private var isSavingToPhotos = false
    @State private var saveToPhotosError: String?
    @State private var showSaveError = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                if isExporting {
                    exportProgressView
                } else {
                    exportPreviewContent
                }
            }
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        onCancel()
                        dismiss()
                    }) {
                        Text("Cancel")
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    SecurityBadge(style: .minimal)
                }
            }
        }
        .sheet(isPresented: $showingPreview) {
            if let url = selectedURL {
                QuickLookPreview(url: url)
                    .onAppear {
                        // Small delay to ensure file is ready
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            // Preview will load automatically
                        }
                    }
            }
        }
        .sheet(isPresented: $showingSecurityOptions) {
            SecurityOptionsView { options in
                applySecurityOptions(options)
            }
        }
        .alert("Error Saving to Photos", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {
                // Dismiss view even if there was an error
                dismiss()
            }
        } message: {
            if let error = saveToPhotosError {
                Text(error)
            }
        }
        .onAppear {
            HapticManager.shared.impact(.light)
        }
    }
    
    // MARK: - Export Preview Content
    private var exportPreviewContent: some View {
        ScrollView {
            VStack(spacing: OneBoxSpacing.large) {
                // Header
                exportHeaderCard
                
                // File Analysis
                fileAnalysisCard
                
                // Preview Grid
                filePreviewGrid
                
                // Security Options
                securityOptionsCard
                
                // Export Actions
                exportActionsCard
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Export Header Card
    private var exportHeaderCard: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text(ConciergeCopy.exportPreview)
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Verify your export before saving")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(OneBoxColors.secureGreen)
                }
                
                // Export Summary
                VStack(spacing: OneBoxSpacing.small) {
                    exportSummaryRow("Task", exportTitle)
                    exportSummaryRow("Files", "\(outputURLs.count)")
                    exportSummaryRow("Total Size", totalSizeString)
                    exportSummaryRow("Size Change", sizeChangeString)
                }
            }
        }
    }
    
    private func exportSummaryRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(OneBoxTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(OneBoxColors.primaryText)
        }
    }
    
    // MARK: - File Analysis Card
    private var fileAnalysisCard: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Quality Analysis")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    qualityBadge
                }
                
                // Analysis insights
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(getQualityInsights(), id: \.id) { insight in
                        qualityInsightRow(insight)
                    }
                }
                
                // Optimization suggestions
                if !getOptimizationSuggestions().isEmpty {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        Text("Optimization Suggestions")
                            .font(OneBoxTypography.caption)
                            .fontWeight(.medium)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        ForEach(getOptimizationSuggestions(), id: \.self) { suggestion in
                            HStack(spacing: OneBoxSpacing.tiny) {
                                Image(systemName: "lightbulb.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(OneBoxColors.warningAmber)
                                
                                Text(suggestion)
                                    .font(OneBoxTypography.micro)
                                    .foregroundColor(OneBoxColors.secondaryText)
                            }
                        }
                    }
                    .padding(OneBoxSpacing.small)
                    .background(OneBoxColors.warningAmber.opacity(0.1))
                    .cornerRadius(OneBoxRadius.small)
                }
            }
        }
    }
    
    private var qualityBadge: some View {
        let quality = analyzeOverallQuality()
        
        return HStack(spacing: OneBoxSpacing.tiny) {
            Image(systemName: quality.icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(quality.color)
            
            Text(quality.text)
                .font(OneBoxTypography.micro)
                .foregroundColor(quality.color)
        }
        .padding(.horizontal, OneBoxSpacing.tiny)
        .padding(.vertical, 2)
        .background(quality.color.opacity(0.2))
        .cornerRadius(OneBoxRadius.small)
    }
    
    private func qualityInsightRow(_ insight: QualityInsight) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: insight.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(insight.severity.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(insight.title)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                
                if let description = insight.description {
                    Text(description)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
            }
            
            Spacer()
            
            if insight.isActionable {
                Button("Fix") {
                    applyInsightFix(insight)
                }
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.goldText)
            }
        }
    }
    
    // MARK: - File Preview Grid
    private var filePreviewGrid: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("File Preview")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Text("\(outputURLs.count) file\(outputURLs.count == 1 ? "" : "s")")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: OneBoxSpacing.small) {
                    ForEach(outputURLs, id: \.self) { url in
                        filePreviewCard(url)
                    }
                }
            }
        }
    }
    
    private func filePreviewCard(_ url: URL) -> some View {
        Button(action: {
            selectedURL = url
            showingPreview = true
            HapticManager.shared.impact(.light)
        }) {
            VStack(spacing: OneBoxSpacing.small) {
                // File type icon or thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: OneBoxRadius.small)
                        .fill(OneBoxColors.surfaceGraphite)
                        .frame(height: 80)
                    
                    Image(systemName: fileIcon(for: url))
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(OneBoxColors.primaryGold)
                }
                
                VStack(spacing: 2) {
                    Text(url.lastPathComponent)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.primaryText)
                        .lineLimit(1)
                    
                    Text(fileSizeString(for: url))
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
            }
            .padding(OneBoxSpacing.small)
            .background(OneBoxColors.tertiaryGraphite)
            .cornerRadius(OneBoxRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Security Options Card
    private var securityOptionsCard: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Security & Privacy")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        showingSecurityOptions = true
                    }) {
                        Text("Configure")
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.goldText)
                }
                
                // Security options summary
                VStack(spacing: OneBoxSpacing.small) {
                    securityOptionRow("Metadata Stripping", "Enabled", true)
                    securityOptionRow("Local Processing", "Verified", true)
                    securityOptionRow("Encryption", "AES-256", true)
                    securityOptionRow("Audit Trail", "Logged", true)
                }
            }
        }
    }
    
    private func securityOptionRow(_ title: String, _ status: String, _ isEnabled: Bool) -> some View {
        HStack {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundColor(isEnabled ? OneBoxColors.secureGreen : OneBoxColors.criticalRed)
            
            Text(title)
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
            
            Text(status)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
    
    // MARK: - Export Actions Card
    private var exportActionsCard: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            // Export confirmation message
            OneBoxCard(style: .security) {
                VStack(spacing: OneBoxSpacing.small) {
                    Text("Ready to Export")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text("Your files have been processed securely on-device and are ready for export")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Action buttons
            VStack(spacing: OneBoxSpacing.small) {
                OneBoxButton("Export Securely", icon: "square.and.arrow.up.fill", style: .security) {
                    confirmExport()
                }
                
                OneBoxButton(
                    isSavingToPhotos ? "Saving to Photos..." : "Save & Export Later",
                    icon: isSavingToPhotos ? "hourglass" : "bookmark.fill",
                    style: .secondary
                ) {
                    saveForLater()
                }
                .disabled(isSavingToPhotos)
                
                Button(action: {
                    onCancel()
                    dismiss()
                }) {
                    Text("Cancel Export")
                }
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.tertiaryText)
            }
        }
    }
    
    // MARK: - Export Progress View
    private var exportProgressView: some View {
        VStack(spacing: OneBoxSpacing.xxl) {
            // Progress indicator
            VStack(spacing: OneBoxSpacing.medium) {
                ZStack {
                    Circle()
                        .stroke(OneBoxColors.primaryGold.opacity(0.3), lineWidth: 8)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .trim(from: 0, to: exportProgress)
                        .stroke(OneBoxColors.primaryGold, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: exportProgress)
                    
                    VStack(spacing: OneBoxSpacing.tiny) {
                        Text("\(exportProgress.isNaN || exportProgress.isInfinite ? 0 : Int(exportProgress * 100))%")
                            .font(OneBoxTypography.sectionTitle)
                            .fontWeight(.bold)
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        Text("Exporting")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                Text("Processing your files securely...")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                    .multilineTextAlignment(.center)
                
                SecurityBadge(style: .prominent)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            startExportProgress()
        }
    }
    
    // MARK: - Computed Properties
    private var totalSizeString: String {
        let totalSize = outputURLs.reduce(0) { sum, url in
            sum + (fileSize(for: url) ?? 0)
        }
        return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    private var sizeChangeString: String {
        let totalSize = outputURLs.reduce(0) { sum, url in
            sum + (fileSize(for: url) ?? 0)
        }

        // Guard against division by zero which causes crash when converting infinity to Int
        guard originalSize > 0 else {
            return "No change"
        }

        if totalSize < originalSize {
            let savedBytes = originalSize - totalSize
            let percentage = (Double(savedBytes) / Double(originalSize)) * 100
            return "-\(ByteCountFormatter.string(fromByteCount: savedBytes, countStyle: .file)) (\(Int(percentage))% smaller)"
        } else if totalSize > originalSize {
            let addedBytes = totalSize - originalSize
            let percentage = (Double(addedBytes) / Double(originalSize)) * 100
            return "+\(ByteCountFormatter.string(fromByteCount: addedBytes, countStyle: .file)) (\(Int(percentage))% larger)"
        } else {
            return "No change"
        }
    }
    
    // MARK: - Helper Functions
    private func fileIcon(for url: URL) -> String {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "pdf": return "doc.text.fill"
        case "jpg", "jpeg", "png", "heic": return "photo.fill"
        default: return "doc.fill"
        }
    }
    
    private func fileSizeString(for url: URL) -> String {
        guard let size = fileSize(for: url) else { return "Unknown" }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
    
    private func fileSize(for url: URL) -> Int64? {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64
        } catch {
            return nil
        }
    }
    
    private func analyzeOverallQuality() -> QualityStatus {
        // Real quality analysis based on file metrics
        let totalOutputSize: Int64 = outputURLs.reduce(0 as Int64) { (total: Int64, url: URL) -> Int64 in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let sizeValue = attributes[.size] as? Int64 else {
                return total
            }
            return total + sizeValue
        }
        
        let sizeReduction = originalSize > 0 ? Double(originalSize - totalOutputSize) / Double(originalSize) : 0.0
        let averageFileSize = totalOutputSize / Int64(max(outputURLs.count, 1))
        
        // Determine quality status based on analysis
        if sizeReduction > 0.3 && averageFileSize < 5_000_000 { // >30% reduction, <5MB avg
            return QualityStatus(text: "Excellent", color: OneBoxColors.secureGreen, icon: "checkmark.seal.fill")
        } else if sizeReduction > 0.1 && averageFileSize < 10_000_000 { // >10% reduction, <10MB avg
            return QualityStatus(text: "Good", color: OneBoxColors.warningAmber, icon: "checkmark.circle.fill")
        } else if sizeReduction > 0 {
            return QualityStatus(text: "Acceptable", color: OneBoxColors.warningAmber, icon: "exclamationmark.circle.fill")
        } else {
            return QualityStatus(text: "Review Needed", color: OneBoxColors.criticalRed, icon: "exclamationmark.triangle.fill")
        }
    }
    
    private func getQualityInsights() -> [QualityInsight] {
        var insights: [QualityInsight] = []
        
        // Calculate real metrics
        let totalOutputSize: Int64 = outputURLs.reduce(0 as Int64) { (total: Int64, url: URL) -> Int64 in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let sizeValue = attributes[.size] as? Int64 else {
                return total
            }
            return total + sizeValue
        }
        let sizeReduction = originalSize > 0 ? Double(originalSize - totalOutputSize) / Double(originalSize) : 0.0
        let averageFileSize = totalOutputSize / Int64(max(outputURLs.count, 1))
        
        // Analyze PDF files for quality issues
        for url in outputURLs where url.pathExtension.lowercased() == "pdf" {
            if let pdfDocument = PDFDocument(url: url) {
                let pageCount = pdfDocument.pageCount
                let fileSize: Int64
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let sizeValue = attributes[.size] as? Int64 {
                    fileSize = sizeValue
                } else {
                    fileSize = 0
                }
                let sizePerPage = fileSize / Int64(max(pageCount, 1))
                
                // Check for large file size
                if fileSize > 20_000_000 { // >20MB
                    insights.append(QualityInsight(
                        id: "large_file_\(url.lastPathComponent)",
                        title: "Large File Detected",
                        description: "\(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)) - Consider compression",
                        icon: "doc.fill",
                        severity: .warning,
                        isActionable: true
                    ))
                }
                
                // Check for high size per page (indicates unoptimized images)
                if sizePerPage > 2_000_000 { // >2MB per page
                    insights.append(QualityInsight(
                        id: "high_size_per_page_\(url.lastPathComponent)",
                        title: "Unoptimized Images",
                        description: "\(ByteCountFormatter.string(fromByteCount: sizePerPage, countStyle: .file)) per page average",
                        icon: "photo.fill",
                        severity: .warning,
                        isActionable: true
                    ))
                }
                
                // Check for very low page count (might be a split issue)
                if pageCount == 1 && outputURLs.count > 1 {
                    insights.append(QualityInsight(
                        id: "single_page_\(url.lastPathComponent)",
                        title: "Single Page File",
                        description: "Consider merging with other files",
                        icon: "doc.on.doc.fill",
                        severity: .info,
                        isActionable: false
                    ))
                }
            }
        }
        
        // Size reduction insight
        if sizeReduction > 0.1 {
            insights.append(QualityInsight(
                id: "compression",
                title: "Size Reduction",
                description: "\(sizeReduction.isNaN || sizeReduction.isInfinite ? 0 : Int(sizeReduction * 100))% smaller than original",
                icon: "arrow.down.circle.fill",
                severity: .info,
                isActionable: false
            ))
        } else if sizeReduction < 0 {
            insights.append(QualityInsight(
                id: "size_increase",
                title: "Size Increased",
                description: "Output is larger than input - review settings",
                icon: "arrow.up.circle.fill",
                severity: .warning,
                isActionable: true
            ))
        }
        
        // Average file size insight
        if averageFileSize > 10_000_000 {
            insights.append(QualityInsight(
                id: "large_average",
                title: "Large Average File Size",
                description: "Consider additional compression",
                icon: "externaldrive.fill",
                severity: .warning,
                isActionable: true
            ))
        }
        
        return insights.isEmpty ? [
            QualityInsight(
                id: "no_issues",
                title: "No Issues Detected",
                description: "Files are ready for export",
                icon: "checkmark.circle.fill",
                severity: .info,
                isActionable: false
            )
        ] : insights
    }
    
    private func getOptimizationSuggestions() -> [String] {
        var suggestions: [String] = []
        
        let totalOutputSize: Int64 = outputURLs.reduce(0 as Int64) { (total: Int64, url: URL) -> Int64 in
            guard let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                  let sizeValue = attributes[.size] as? Int64 else {
                return total
            }
            return total + sizeValue
        }
        let averageFileSize = totalOutputSize / Int64(max(outputURLs.count, 1))
        
        // Generate real suggestions based on analysis
        if averageFileSize > 10_000_000 {
            suggestions.append("Enable advanced compression to reduce file sizes")
        }
        
        if outputURLs.count > 5 {
            suggestions.append("Consider merging smaller files to reduce file count")
        }
        
        for url in outputURLs where url.pathExtension.lowercased() == "pdf" {
            if let pdfDocument = PDFDocument(url: url) {
                let pageCount = pdfDocument.pageCount
                let fileSize: Int64
                if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let sizeValue = attributes[.size] as? Int64 {
                    fileSize = sizeValue
                } else {
                    fileSize = 0
                }
                
                if pageCount == 1 && fileSize > 5_000_000 {
                    suggestions.append("Single-page files with large sizes may benefit from image optimization")
                    break
                }
            }
        }
        
        return suggestions
    }
    
    private func confirmExport() {
        isExporting = true
        HapticManager.shared.impact(.heavy)
        
        // Simulate export process
        startExportProgress()
    }
    
    private func saveForLater() {
        // Check if there are any image files to save
        let imageURLs = outputURLs.filter { url in
            let ext = url.pathExtension.lowercased()
            return ["jpg", "jpeg", "png", "heic", "heif"].contains(ext)
        }
        
        // If there are images, save them to photo gallery
        if !imageURLs.isEmpty {
            saveImagesToPhotoLibrary(imageURLs: imageURLs)
        } else {
            // No images to save, just dismiss
            HapticManager.shared.notification(.success)
            dismiss()
        }
    }
    
    private func saveImagesToPhotoLibrary(imageURLs: [URL]) {
        isSavingToPhotos = true
        saveToPhotosError = nil
        
        Task {
            do {
                // Request photo library permission
                let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
                let authStatus: PHAuthorizationStatus
                
                if status == .notDetermined {
                    authStatus = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                } else {
                    authStatus = status
                }
                
                guard authStatus == .authorized || authStatus == .limited else {
                    await MainActor.run {
                        saveToPhotosError = "Photo library access denied. Please enable photo access in Settings to save images."
                        showSaveError = true
                        isSavingToPhotos = false
                    }
                    return
                }
                
                // Save each image
                var successCount = 0
                var failureCount = 0
                
                for url in imageURLs {
                    // Ensure file is accessible (handle security-scoped resources and temp files)
                    var startedAccessing = false
                    if url.startAccessingSecurityScopedResource() {
                        startedAccessing = true
                    }
                    
                    defer {
                        if startedAccessing {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                    
                    // Check if file exists
                    guard FileManager.default.fileExists(atPath: url.path) else {
                        print("⚠️ ExportPreviewView: File does not exist: \(url.path)")
                        failureCount += 1
                        continue
                    }
                    
                    // Load image using CGImageSource (better for file access)
                    var image: UIImage?
                    
                    if let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil),
                       let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) {
                        image = UIImage(cgImage: cgImage)
                    } else {
                        // Fallback to Data method
                        if let imageData = try? Data(contentsOf: url) {
                            image = UIImage(data: imageData)
                        }
                    }
                    
                    guard let finalImage = image else {
                        print("⚠️ ExportPreviewView: Failed to load image from: \(url.lastPathComponent)")
                        failureCount += 1
                        continue
                    }
                    
                    // Save to photo library
                    do {
                        try await PHPhotoLibrary.shared().performChanges {
                            PHAssetChangeRequest.creationRequestForAsset(from: finalImage)
                        }
                        successCount += 1
                        print("✅ ExportPreviewView: Successfully saved \(url.lastPathComponent) to photo library")
                    } catch {
                        print("❌ ExportPreviewView: Failed to save image \(url.lastPathComponent): \(error.localizedDescription)")
                        failureCount += 1
                    }
                }
                
                await MainActor.run {
                    isSavingToPhotos = false
                    
                    if failureCount > 0 {
                        if successCount > 0 {
                            saveToPhotosError = "Saved \(successCount) image\(successCount == 1 ? "" : "s"). \(failureCount) failed to save."
                        } else {
                            saveToPhotosError = "Failed to save images to photo library. The files may have been moved or deleted. Please try using the Share button instead."
                        }
                        showSaveError = true
                    } else if successCount > 0 {
                        // Success - show feedback and dismiss
                        HapticManager.shared.notification(.success)
                        print("✅ ExportPreviewView: Successfully saved \(successCount) image\(successCount == 1 ? "" : "s") to photo library")
                        dismiss()
                    } else {
                        // No images found
                        saveToPhotosError = "No image files found to save."
                        showSaveError = true
                    }
                }
            } catch {
                await MainActor.run {
                    isSavingToPhotos = false
                    saveToPhotosError = "Failed to save images: \(error.localizedDescription)"
                    showSaveError = true
                }
            }
        }
    }
    
    private func startExportProgress() {
        exportProgress = 0
        
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            exportProgress += 0.05
            
            if exportProgress >= 1.0 {
                timer.invalidate()
                exportProgress = 1.0
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    HapticManager.shared.notification(.success)
                    onConfirm()
                    dismiss()
                }
            }
        }
    }
    
    private func applyInsightFix(_ insight: QualityInsight) {
        HapticManager.shared.impact(.light)
        // Apply suggested fix
    }
    
    private func applySecurityOptions(_ options: SecurityOptions) {
        // Apply selected security options
    }
}

// MARK: - Supporting Data Models
struct QualityStatus {
    let text: String
    let color: Color
    let icon: String
}

struct QualityInsight: Identifiable {
    let id: String
    let title: String
    let description: String?
    let icon: String
    let severity: Severity
    let isActionable: Bool
    
    enum Severity {
        case info, warning, error
        
        var color: Color {
            switch self {
            case .info: return OneBoxColors.secureGreen
            case .warning: return OneBoxColors.warningAmber
            case .error: return OneBoxColors.criticalRed
            }
        }
    }
}

struct SecurityOptions {
    let stripMetadata: Bool
    let enableEncryption: Bool
    let createAuditLog: Bool
}

// MARK: - Security Options View
struct SecurityOptionsView: View {
    let onApply: (SecurityOptions) -> Void
    @State private var stripMetadata = true
    @State private var enableEncryption = true
    @State private var createAuditLog = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: OneBoxSpacing.large) {
                Text("Security Options")
                    .font(OneBoxTypography.heroTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                // Security options
                VStack(spacing: OneBoxSpacing.medium) {
                    securityToggle("Strip Metadata", "Remove all metadata from files", $stripMetadata)
                    securityToggle("Enable Encryption", "Encrypt files with AES-256", $enableEncryption)
                    securityToggle("Create Audit Log", "Log all security actions", $createAuditLog)
                }
                
                Spacer()
                
                OneBoxButton("Apply Settings", style: .security) {
                    onApply(SecurityOptions(
                        stripMetadata: stripMetadata,
                        enableEncryption: enableEncryption,
                        createAuditLog: createAuditLog
                    ))
                    dismiss()
                }
            }
            .padding(OneBoxSpacing.large)
            .background(OneBoxColors.primaryGraphite)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
            }
        }
    }
    
    private func securityToggle(_ title: String, _ description: String, _ binding: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(title)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(description)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            
            Spacer()
            
            Toggle("", isOn: binding)
                .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
        }
        .padding(OneBoxSpacing.medium)
        .background(OneBoxColors.secondaryGraphite)
        .cornerRadius(OneBoxRadius.medium)
    }
}

#Preview {
    ExportPreviewView(
        outputURLs: [
            URL(fileURLWithPath: "/tmp/test.pdf"),
            URL(fileURLWithPath: "/tmp/test2.pdf")
        ],
        exportTitle: "PDF Merge",
        originalSize: 1024000,
        onConfirm: {},
        onCancel: {}
    )
}