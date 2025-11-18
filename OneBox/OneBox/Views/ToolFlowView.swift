//
//  ToolFlowView.swift
//  OneBox
//
//  Universal tool flow: Select Input → Configure → Process → Result
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import JobEngine
import UIComponents
import PDFKit

struct ToolFlowView: View {
    let tool: ToolType

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    @EnvironmentObject var paymentsManager: PaymentsManager

    @State private var step: FlowStep = .selectInput
    @State private var selectedURLs: [URL] = []
    @State private var settings = JobSettings()
    @State private var currentJob: Job?
    @State private var showPaywall = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showPageOrganizer = false

    enum FlowStep {
        case selectInput
        case configure
        case processing
        case result
    }

    var body: some View {
        NavigationStack {
            Group {
                switch step {
                case .selectInput:
                    InputSelectionView(
                        tool: tool,
                        selectedURLs: $selectedURLs,
                        onContinue: {
                            if tool == .pdfOrganize {
                                // Page Organizer uses a custom interactive flow
                                showPageOrganizer = true
                            } else {
                                // Standard flow continues to configuration
                                step = .configure
                            }
                        }
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
                case .result:
                    if let job = currentJob {
                        JobResultView(job: job)
                    }
                }
            }
            .navigationTitle(tool.displayName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if step == .selectInput {
                        Button("Cancel") {
                            dismiss()
                        }
                    } else if step == .configure {
                        Button("Back") {
                            step = .selectInput
                        }
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .fullScreenCover(isPresented: $showPageOrganizer) {
                if let pdfURL = selectedURLs.first {
                    PageOrganizerView(pdfURL: pdfURL)
                        .environmentObject(jobManager)
                        .environmentObject(paymentsManager)
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func processFiles() {
        // Check if user can export
        guard paymentsManager.canExport else {
            showPaywall = true
            return
        }

        // Create job
        let jobType: JobType
        switch tool {
        case .imagesToPDF: jobType = .imagesToPDF
        case .pdfMerge: jobType = .pdfMerge
        case .pdfSplit: jobType = .pdfSplit
        case .pdfCompress: jobType = .pdfCompress
        case .pdfWatermark: jobType = .pdfWatermark
        case .pdfSign: jobType = .pdfSign
        case .pdfOrganize: jobType = .pdfOrganize
        case .imageResize: jobType = .imageResize
        case .videoCompress: jobType = .videoCompress
        case .zip: jobType = .zip
        case .unzip: jobType = .unzip
        }

        let job = Job(
            type: jobType,
            inputs: selectedURLs,
            settings: settings
        )

        currentJob = job
        jobManager.submitJob(job)

        step = .processing

        // Monitor job progress
        observeJobCompletion(job)
    }

    private func observeJobCompletion(_ job: Job) {
        Task {
            while step == .processing {
                if let updatedJob = jobManager.jobs.first(where: { $0.id == job.id }) {
                    currentJob = updatedJob

                    if updatedJob.status == .success {
                        // Only consume export on success (not on failure)
                        paymentsManager.consumeExport()
                        step = .result
                        break
                    } else if updatedJob.status == .failed {
                        errorMessage = updatedJob.error ?? "Unknown error"
                        showError = true
                        dismiss()
                        break
                    }
                }

                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
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
    }

    private var emptyState: some View {
        VStack(spacing: 24) {
            Image(systemName: tool.icon)
                .font(.system(size: 64))
                .foregroundColor(tool.color)

            VStack(spacing: 8) {
                Text(emptyStateTitle)
                    .font(.title3)
                    .fontWeight(.semibold)

                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            selectButton
        }
        .frame(maxHeight: .infinity)
    }

    private var filesList: some View {
        ScrollView {
            VStack(spacing: 12) {
                ForEach(Array(selectedURLs.enumerated()), id: \.offset) { index, url in
                    FilePickerRow(
                        fileName: url.lastPathComponent,
                        fileSize: fileSizeString(url),
                        icon: fileIcon(url)
                    ) {
                        selectedURLs.remove(at: index)
                    }
                }

                selectButton
            }
        }
    }

    private var selectButton: some View {
        Button {
            if requiresPhotoPicker {
                showImagePicker = true
            } else {
                showFilePicker = true
            }
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text(selectedURLs.isEmpty ? "Select Files" : "Add More")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor.opacity(0.1))
            .foregroundColor(.accentColor)
            .cornerRadius(12)
        }
    }

    private var continueButton: some View {
        PrimaryButton(
            "Continue",
            icon: "arrow.right",
            isDisabled: selectedURLs.isEmpty
        ) {
            onContinue()
        }
    }

    // Helpers
    private var requiresPhotoPicker: Bool {
        tool == .imagesToPDF || tool == .imageResize
    }

    private var allowsMultipleSelection: Bool {
        tool != .pdfSplit && tool != .pdfSign && tool != .pdfOrganize && tool != .unzip
    }

    private var maxSelectionCount: Int? {
        allowsMultipleSelection ? nil : 1
    }

    private var photosFilter: PHPickerFilter {
        .images
    }

    private var allowedFileTypes: [UTType] {
        switch tool {
        case .imagesToPDF, .imageResize:
            return [.image]
        case .pdfMerge, .pdfSplit, .pdfCompress, .pdfWatermark, .pdfSign, .pdfOrganize:
            return [.pdf]
        case .videoCompress:
            return [.movie, .video]
        case .zip:
            return [.item]
        case .unzip:
            return [.zip]
        }
    }

    private var emptyStateTitle: String {
        switch tool {
        case .imagesToPDF: return "Select Images"
        case .pdfMerge: return "Select PDFs"
        case .pdfOrganize: return "Select PDF"
        case .imageResize: return "Select Images"
        case .videoCompress: return "Select Video"
        default: return "Select Files"
        }
    }

    private var emptyStateMessage: String {
        switch tool {
        case .imagesToPDF: return "Choose one or more images to convert to PDF"
        case .pdfMerge: return "Choose multiple PDFs to combine"
        case .pdfSplit: return "Choose a PDF to split"
        case .pdfCompress: return "Choose a PDF to compress"
        case .pdfOrganize: return "Choose a PDF to organize"
        default: return "Choose files to process"
        }
    }

    private func loadPhotos(_ photos: [PhotosPickerItem]) {
        Task {
            for photo in photos {
                if let data = try? await photo.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent(UUID().uuidString)
                        .appendingPathExtension("jpg")
                    try? data.write(to: tempURL)
                    selectedURLs.append(tempURL)
                }
            }
        }
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
        case "mp4", "mov": return "play.rectangle"
        case "zip": return "archivebox"
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

    private var isConfigurationValid: Bool {
        switch tool {
        case .pdfWatermark:
            return settings.watermarkText != nil && !settings.watermarkText!.isEmpty
        case .pdfSign:
            return settings.signatureText != nil && !settings.signatureText!.isEmpty
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
            if settings.signatureText == nil || settings.signatureText!.isEmpty {
                return "Please enter signature text"
            }
        default:
            break
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Tool-specific settings
                toolSettings

                // Advanced settings toggle
                Button {
                    showAdvanced.toggle()
                } label: {
                    HStack {
                        Text("Advanced Settings")
                            .fontWeight(.medium)
                        Spacer()
                        Image(systemName: showAdvanced ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }

                if showAdvanced {
                    advancedSettings
                }

                // Validation message
                if let message = validationMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.orange)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }

                Spacer()

                PrimaryButton(
                    "Process Files",
                    icon: "bolt.fill",
                    isDisabled: !isConfigurationValid,
                    action: onProcess
                )
            }
            .padding()
        }
    }

    @ViewBuilder
    private var toolSettings: some View {
        VStack(spacing: 16) {
            switch tool {
            case .imagesToPDF:
                pdfSettings
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
            case .videoCompress:
                videoSettings
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
                Picker("Orientation", selection: $settings.orientation) {
                    Text("Portrait").tag(PDFOrientation.portrait)
                    Text("Landscape").tag(PDFOrientation.landscape)
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private var compressionSettings: some View {
        PDFCompressionSettings(settings: $settings, pdfURL: selectedURLs.first)
    }

    private var imageSettings: some View {
        VStack(spacing: 16) {
            // Format
            Picker("Format", selection: $settings.imageFormat) {
                Text("JPEG").tag(ImageFormat.jpeg)
                Text("PNG").tag(ImageFormat.png)
                Text("HEIC").tag(ImageFormat.heic)
            }
            .pickerStyle(.segmented)

            // Quality
            VStack(alignment: .leading, spacing: 8) {
                Text("Quality: \(Int(settings.imageQuality * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Slider(value: $settings.imageQuality, in: 0.1...1.0, step: 0.1)
            }

            // Max Dimension
            if let maxDim = settings.maxDimension {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Max Size: \(maxDim)px")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Slider(value: Binding(
                        get: { Double(maxDim) },
                        set: { settings.maxDimension = Int($0) }
                    ), in: 512...4096, step: 256)
                }
            } else {
                Button("Set Max Size") {
                    settings.maxDimension = 2048
                }
            }
        }
    }

    private var videoSettings: some View {
        VStack(spacing: 16) {
            Picker("Preset", selection: $settings.videoPreset) {
                ForEach(VideoCompressionPreset.allCases, id: \.self) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }

            Toggle("Keep Audio", isOn: $settings.keepAudio)
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

            // Opacity
            VStack(alignment: .leading, spacing: 8) {
                Text("Opacity: \(Int(settings.watermarkOpacity * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Slider(value: $settings.watermarkOpacity, in: 0.1...1.0, step: 0.1)
            }
        }
    }

    private var signatureSettings: some View {
        VStack(spacing: 16) {
            // Info text
            Text("The signature will be added to the last page of the PDF")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)

            // Signature Text
            VStack(alignment: .leading, spacing: 8) {
                Text("Signature Text")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("Enter your name or signature text", text: Binding(
                    get: { settings.signatureText ?? "" },
                    set: { settings.signatureText = $0.isEmpty ? nil : $0 }
                ))
                .textFieldStyle(.roundedBorder)
            }

            // Position
            VStack(alignment: .leading, spacing: 8) {
                Text("Position")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Picker("Position", selection: $settings.signaturePosition) {
                    ForEach(WatermarkPosition.allCases.filter { $0 != .tiled }, id: \.self) { position in
                        Text(position.displayName).tag(position)
                    }
                }
                .pickerStyle(.menu)
            }

            // Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Size: \(Int(settings.signatureSize * 100))%")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Slider(value: $settings.signatureSize, in: 0.1...0.3, step: 0.05)
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

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView(value: job?.progress ?? 0)
                .progressViewStyle(.linear)
                .tint(.accentColor)
                .scaleEffect(y: 2)

            VStack(spacing: 8) {
                Text("Processing...")
                    .font(.title3)
                    .fontWeight(.semibold)

                if let job = job {
                    Text("\(Int(job.progress * 100))% complete")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
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

            Text("Add page ranges to create separate PDF files")
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

#Preview {
    ToolFlowView(tool: .imagesToPDF)
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
}
