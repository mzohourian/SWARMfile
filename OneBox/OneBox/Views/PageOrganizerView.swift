//
//  PageOrganizerView.swift
//  OneBox
//
//  Page organizer for PDFs - reorder, delete, and rotate pages
//

import SwiftUI
import PDFKit
import CorePDF
import JobEngine
import UIComponents
import UniformTypeIdentifiers

struct PageOrganizerView: View {
    let pdfURL: URL

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    @EnvironmentObject var paymentsManager: PaymentsManager

    @State private var pdfDocument: PDFDocument?
    @State private var pages: [PageInfo] = []
    @State private var selectedPages: Set<UUID> = []
    @State private var isProcessing = false
    @State private var showingDeleteConfirmation = false
    @State private var showingPaywall = false
    @State private var completedJob: Job?
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var detectedAnomalies: [PageAnomaly] = []
    @State private var showingAnomalies = false
    @State private var historyStack: [PageOrganizerState] = []
    @State private var redoStack: [PageOrganizerState] = []
    @State private var secureBatchMode = false

    // Drag & drop state
    @State private var draggedPage: PageInfo?

    // Security-scoped resource tracking
    @State private var didStartAccessingSecurityScoped = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Background color
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                if pdfDocument != nil, !pages.isEmpty {
                    VStack(spacing: 0) {
                        // Selection info bar
                        if !selectedPages.isEmpty {
                            selectionInfoBar
                        }

                        // Anomaly alert banner
                        if !detectedAnomalies.isEmpty {
                            anomalyBanner
                        }
                        
                        // Page grid
                        ScrollView {
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 120, maximum: 150), spacing: 16)
                            ], spacing: 16) {
                                ForEach(pages) { page in
                                    PageCell(
                                        page: page,
                                        isSelected: selectedPages.contains(page.id),
                                        onTap: { toggleSelection(page) },
                                        onDrag: { draggedPage = page },
                                        onDrop: { handleDrop(page) },
                                        hasAnomaly: detectedAnomalies.contains { $0.pageId == page.id }
                                    )
                                }
                            }
                            .padding()
                        }

                        // Bottom toolbar
                        bottomToolbar
                    }
                } else {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Loading PDF...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // Processing overlay
                if isProcessing {
                    Color.black.opacity(0.4)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        Text("Saving changes...")
                            .foregroundColor(.white)
                            .font(.headline)
                    }
                    .padding(32)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("Organize Pages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        savePDF()
                    }
                    .disabled(pages.isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                print("PageOrganizer: View appeared, loading PDF...")
                print("PageOrganizer: PDF URL: \(pdfURL)")
                print("PageOrganizer: File exists: \(FileManager.default.fileExists(atPath: pdfURL.path))")
                loadPDF()
            }
            .onChange(of: pages) { _ in
                // Anomaly detection disabled - produces too many false positives
                // and doesn't offer one-click solutions. Will be re-enabled when
                // proper detection algorithms and automated fixes are implemented.
                // detectAnomalies()
            }
            .onDisappear {
                // Stop accessing security-scoped resource when view is dismissed
                if didStartAccessingSecurityScoped {
                    print("PageOrganizer: Stopping security-scoped resource access")
                    pdfURL.stopAccessingSecurityScopedResource()
                    didStartAccessingSecurityScoped = false
                }
            }
            .sheet(isPresented: $showingPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingResult) {
                if let job = completedJob {
                    JobResultView(job: job)
                }
            }
            .alert("Delete Pages", isPresented: $showingDeleteConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    deleteSelectedPages()
                }
            } message: {
                Text("Are you sure you want to delete \(selectedPages.count) page\(selectedPages.count == 1 ? "" : "s")? This action cannot be undone.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
            .sheet(isPresented: $showingAnomalies) {
                AnomalyDetailView(anomalies: detectedAnomalies, pages: pages)
            }
        }
    }
    
    // MARK: - Anomaly Detection
    private var anomalyBanner: some View {
        Button(action: {
            showingAnomalies = true
        }) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(OneBoxColors.warningAmber)
                
                Text("\(detectedAnomalies.count) issue\(detectedAnomalies.count == 1 ? "" : "s") detected")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            .padding(OneBoxSpacing.medium)
            .background(OneBoxColors.warningAmber.opacity(0.1))
            .cornerRadius(OneBoxRadius.medium)
        }
        .padding(.horizontal, OneBoxSpacing.medium)
        .padding(.top, OneBoxSpacing.small)
    }
    
    private func detectAnomalies() {
        guard pdfDocument != nil, !pages.isEmpty else { return }
        
        var anomalies: [PageAnomaly] = []
        
        // Detect duplicate pages (similar thumbnails)
        var seenThumbnails: [String: [Int]] = [:]
        for (index, page) in pages.enumerated() {
            if let thumbnail = page.thumbnail,
               let imageData = thumbnail.pngData() {
                let hash = imageData.base64EncodedString().prefix(100)
                let hashKey = String(hash)
                
                if seenThumbnails[hashKey] != nil {
                    seenThumbnails[hashKey]?.append(index)
                } else {
                    seenThumbnails[hashKey] = [index]
                }
            }
        }
        
        for (_, indices) in seenThumbnails where indices.count > 1 {
            for index in indices {
                anomalies.append(PageAnomaly(
                    id: UUID(),
                    pageId: pages[index].id,
                    type: .duplicate,
                    message: "Similar page detected",
                    severity: .medium
                ))
            }
        }
        
        // Detect rotation issues (pages rotated differently from neighbors)
        for (index, page) in pages.enumerated() {
            if index > 0 {
                let prevRotation = pages[index - 1].rotation
                if abs(page.rotation - prevRotation) == 90 || abs(page.rotation - prevRotation) == 270 {
                    anomalies.append(PageAnomaly(
                        id: UUID(),
                        pageId: page.id,
                        type: .rotation,
                        message: "Rotation differs from previous page",
                        severity: .low
                    ))
                }
            }
        }
        
        // Detect contrast issues (very light or very dark pages)
        for page in pages {
            if let thumbnail = page.thumbnail {
                let avgBrightness = calculateAverageBrightness(thumbnail)
                if avgBrightness < 0.2 {
                    anomalies.append(PageAnomaly(
                        id: UUID(),
                        pageId: page.id,
                        type: .contrast,
                        message: "Very dark page - may be hard to read",
                        severity: .medium
                    ))
                } else if avgBrightness > 0.9 {
                    anomalies.append(PageAnomaly(
                        id: UUID(),
                        pageId: page.id,
                        type: .contrast,
                        message: "Very light page - may be blank or low contrast",
                        severity: .low
                    ))
                }
            }
        }
        
        detectedAnomalies = anomalies
    }
    
    private func calculateAverageBrightness(_ image: UIImage) -> Double {
        guard let cgImage = image.cgImage else { return 0.5 }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else {
            return 0.5
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var totalBrightness: Double = 0
        let pixelCount = width * height
        
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            let r = Double(pixelData[i])
            let g = Double(pixelData[i + 1])
            let b = Double(pixelData[i + 2])
            
            // Calculate brightness using luminance formula
            let brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            totalBrightness += brightness
        }
        
        return totalBrightness / Double(pixelCount)
    }

    // MARK: - Selection Info Bar
    private var selectionInfoBar: some View {
        HStack {
            Text("\(selectedPages.count) page\(selectedPages.count == 1 ? "" : "s") selected")
                .font(.subheadline)
                .fontWeight(.medium)

            Spacer()

            Button("Clear") {
                selectedPages.removeAll()
            }
            .font(.subheadline)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.accentColor.opacity(0.1))
    }

    // MARK: - Bottom Toolbar
    private var bottomToolbar: some View {
        VStack(spacing: 0) {
            // Secure Batch Toggle
            if !pages.isEmpty {
                HStack {
                    Toggle("Secure Batch Mode", isOn: $secureBatchMode)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if secureBatchMode {
                        Image(systemName: "lock.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            
            // Action buttons
            HStack(spacing: 20) {
                // Undo/Redo
                HStack(spacing: 12) {
                    Button(action: undo) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.title3)
                    }
                    .disabled(historyStack.isEmpty)
                    .foregroundColor(historyStack.isEmpty ? .gray : .accentColor)
                    
                    Button(action: redo) {
                        Image(systemName: "arrow.uturn.forward")
                            .font(.title3)
                    }
                    .disabled(redoStack.isEmpty)
                    .foregroundColor(redoStack.isEmpty ? .gray : .accentColor)
                }
                
                Spacer()
                
                Button(action: rotateLeft) {
                    VStack(spacing: 4) {
                        Image(systemName: "rotate.left")
                            .font(.title2)
                        Text("Rotate Left")
                            .font(.caption2)
                    }
                }
                .disabled(selectedPages.isEmpty)

                Spacer()

                Button(action: { showingDeleteConfirmation = true }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Delete")
                            .font(.caption2)
                    }
                }
                .disabled(selectedPages.isEmpty || selectedPages.count >= pages.count)
                .foregroundColor(.red)

                Spacer()

                Button(action: rotateRight) {
                    VStack(spacing: 4) {
                        Image(systemName: "rotate.right")
                            .font(.title2)
                        Text("Rotate Right")
                            .font(.caption2)
                    }
                }
                .disabled(selectedPages.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
    }

    // MARK: - Actions
    private func loadPDF(retryCount: Int = 0) {
        print("PageOrganizer: Starting to load PDF from: \(pdfURL.path)")

        // Start accessing security-scoped resource (only on first attempt)
        if retryCount == 0 && !didStartAccessingSecurityScoped {
            didStartAccessingSecurityScoped = pdfURL.startAccessingSecurityScopedResource()
            print("PageOrganizer: Security-scoped access started: \(didStartAccessingSecurityScoped)")
        }

        // Verify file exists (with retry for timing issues)
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            if retryCount < 3 {
                print("PageOrganizer: File not found yet, retrying in 0.5s (attempt \(retryCount + 1)/3)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadPDF(retryCount: retryCount + 1)
                }
                return
            }
            print("PageOrganizer Error: File not found at path after 3 retries: \(pdfURL.path)")
            errorMessage = "PDF file not found. Please try selecting the file again."
            showError = true
            dismiss()
            return
        }

        // Try to load PDF document
        guard let pdf = PDFDocument(url: pdfURL) else {
            if retryCount < 3 {
                print("PageOrganizer: Failed to load PDF, retrying in 0.5s (attempt \(retryCount + 1)/3)")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadPDF(retryCount: retryCount + 1)
                }
                return
            }
            print("PageOrganizer Error: Failed to load PDF from URL after 3 retries: \(pdfURL)")
            errorMessage = "Failed to load PDF. The file may be corrupted or password-protected."
            showError = true
            dismiss()
            return
        }

        // Check if PDF has pages
        guard pdf.pageCount > 0 else {
            print("PageOrganizer Error: PDF has no pages")
            errorMessage = "This PDF has no pages to organize."
            showError = true
            dismiss()
            return
        }

        print("PageOrganizer: Successfully loaded PDF with \(pdf.pageCount) pages")
        pdfDocument = pdf

        // Load pages and generate thumbnails asynchronously
        Task {
            var loadedPages: [PageInfo] = []

            for pageIndex in 0..<pdf.pageCount {
                guard let page = pdf.page(at: pageIndex) else {
                    print("PageOrganizer Warning: Could not load page at index \(pageIndex)")
                    continue
                }

                let thumbnail = page.thumbnail(of: CGSize(width: 200, height: 280), for: .mediaBox)

                loadedPages.append(PageInfo(
                    originalIndex: pageIndex,
                    displayIndex: pageIndex,
                    thumbnail: thumbnail,
                    rotation: 0
                ))
            }

            await MainActor.run {
                pages = loadedPages
                print("PageOrganizer: Loaded \(pages.count) page thumbnails")
            }
        }
    }

    private func toggleSelection(_ page: PageInfo) {
        if selectedPages.contains(page.id) {
            selectedPages.remove(page.id)
        } else {
            selectedPages.insert(page.id)
        }
    }
    
    // MARK: - Undo/Redo (On-Device State Management)
    
    private func saveState() {
        // Save current state to history (on-device only)
        let state = PageOrganizerState(
            pages: pages.map { PageInfoSnapshot(from: $0) },
            selectedPages: selectedPages
        )
        historyStack.append(state)
        
        // Limit history size to prevent memory issues
        if historyStack.count > 50 {
            historyStack.removeFirst()
        }
        
        // Clear redo stack when new action is performed
        redoStack.removeAll()
    }
    
    private func undo() {
        guard !historyStack.isEmpty else { return }
        
        // Save current state to redo stack
        let currentState = PageOrganizerState(
            pages: pages.map { PageInfoSnapshot(from: $0) },
            selectedPages: selectedPages
        )
        redoStack.append(currentState)
        
        // Restore previous state
        let previousState = historyStack.removeLast()
        restoreState(previousState)
        
        HapticManager.shared.impact(.light)
    }
    
    private func redo() {
        guard !redoStack.isEmpty else { return }
        
        // Save current state to history
        let currentState = PageOrganizerState(
            pages: pages.map { PageInfoSnapshot(from: $0) },
            selectedPages: selectedPages
        )
        historyStack.append(currentState)
        
        // Restore state from redo stack
        let nextState = redoStack.removeLast()
        restoreState(nextState)
        
        HapticManager.shared.impact(.light)
    }
    
    private func restoreState(_ state: PageOrganizerState) {
        // Restore pages from snapshot
        pages = state.pages.map { snapshot in
            var page = PageInfo(
                originalIndex: snapshot.originalIndex,
                displayIndex: snapshot.displayIndex,
                thumbnail: nil, // Thumbnails will be reloaded
                rotation: snapshot.rotation
            )
            // Reload thumbnail if needed
            if let pdf = pdfDocument, let thumbnail = pdf.page(at: snapshot.originalIndex)?.thumbnail(of: CGSize(width: 200, height: 280), for: .mediaBox) {
                page.thumbnail = thumbnail
            }
            return page
        }
        
        selectedPages = state.selectedPages
    }

    private func handleDrop(_ targetPage: PageInfo) {
        print("PageOrganizer: handleDrop called for target page \(targetPage.displayIndex + 1)")
        print("PageOrganizer: draggedPage state = \(draggedPage?.displayIndex ?? -999)")

        guard let draggedPage = draggedPage else {
            print("PageOrganizer: No dragged page in state!")
            return
        }

        guard let sourceIndex = pages.firstIndex(where: { $0.id == draggedPage.id }) else {
            print("PageOrganizer: Could not find source index for dragged page")
            self.draggedPage = nil
            return
        }

        guard let targetIndex = pages.firstIndex(where: { $0.id == targetPage.id }) else {
            print("PageOrganizer: Could not find target index")
            self.draggedPage = nil
            return
        }

        guard sourceIndex != targetIndex else {
            print("PageOrganizer: Source and target are the same, ignoring")
            self.draggedPage = nil
            return
        }

        print("PageOrganizer: Moving page from index \(sourceIndex) to \(targetIndex)")

        saveState() // Save state before reordering
        
        withAnimation {
            let movedPage = pages.remove(at: sourceIndex)
            pages.insert(movedPage, at: targetIndex)

            // Update display indices
            for (index, _) in pages.enumerated() {
                pages[index].displayIndex = index
            }
        }

        print("PageOrganizer: Reorder complete. New order: \(pages.map { $0.displayIndex + 1 })")
        self.draggedPage = nil
    }

    private func rotateLeft() {
        saveState() // Save state for undo
        for id in selectedPages {
            if let index = pages.firstIndex(where: { $0.id == id }) {
                pages[index].rotation = (pages[index].rotation - 90) % 360
            }
        }
        // Keep selection so user can rotate multiple times without reselecting
    }

    private func rotateRight() {
        saveState() // Save state for undo
        for id in selectedPages {
            if let index = pages.firstIndex(where: { $0.id == id }) {
                pages[index].rotation = (pages[index].rotation + 90) % 360
            }
        }
        // Keep selection so user can rotate multiple times without reselecting
    }

    private func deleteSelectedPages() {
        withAnimation {
            pages.removeAll { selectedPages.contains($0.id) }

            // Update display indices
            for (index, _) in pages.enumerated() {
                pages[index].displayIndex = index
            }
        }
        selectedPages.removeAll()
    }

    private func savePDF() {
        guard let pdf = pdfDocument else { return }

        // Check if user can export
        guard paymentsManager.canExport else {
            showingPaywall = true
            return
        }

        isProcessing = true

        Task {
            do {
                let processor = PDFProcessor()

                // Determine what operations to perform
                let hasReordering = pages.enumerated().contains { $0.offset != $0.element.originalIndex }
                let hasRotations = pages.contains { $0.rotation != 0 }
                let hasDeletions = pages.count < pdf.pageCount

                var outputURL = pdfURL

                // 1. Reorder if needed
                if hasReordering || hasDeletions {
                    let newOrder = pages.map { $0.originalIndex }
                    outputURL = try await processor.reorderPages(
                        in: pdf,
                        newOrder: newOrder,
                        progressHandler: { _ in }
                    )
                }

                // 2. Rotate if needed
                if hasRotations {
                    // Find indices of pages that need rotation
                    let rotationMap = pages.enumerated().filter { $0.element.rotation != 0 }

                    for (newIndex, pageInfo) in rotationMap {
                        // Reload PDF from current outputURL for each rotation
                        // This ensures previous rotations are preserved
                        guard let currentPDF = PDFDocument(url: outputURL) else {
                            throw PDFError.invalidPDF("Could not load PDF for rotation")
                        }

                        let indices = Set([newIndex])
                        outputURL = try await processor.rotatePages(
                            in: currentPDF,
                            indices: indices,
                            angle: pageInfo.rotation,
                            progressHandler: { _ in }
                        )
                    }
                }

                // Save output file to Documents/Exports for persistence
                // This view bypasses JobEngine's processJob(), so we need to persist manually
                let persistedURL = saveOutputToDocuments(outputURL)

                // Create job record with persisted URL
                let job = Job(
                    type: .pdfOrganize,
                    inputs: [pdfURL],
                    settings: JobSettings(),
                    status: .success,
                    progress: 1.0,
                    outputURLs: [persistedURL],
                    completedAt: Date()
                )

                await MainActor.run {
                    paymentsManager.consumeExport()
                    completedJob = job
                    isProcessing = false
                    dismiss()
                    showingResult = true
                }
                await jobManager.submitJob(job)

            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    /// Saves output file from temp directory to Documents/Exports for persistence
    private func saveOutputToDocuments(_ tempURL: URL) -> URL {
        let fileManager = FileManager.default

        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ PageOrganizerView: Could not get Documents directory")
            return tempURL
        }

        let exportsURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)

        // Create Exports directory if it doesn't exist
        do {
            try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("❌ PageOrganizerView: Failed to create Exports directory: \(error)")
            return tempURL
        }

        // Check if file exists
        guard fileManager.fileExists(atPath: tempURL.path) else {
            print("⚠️ PageOrganizerView: Temp file doesn't exist: \(tempURL.path)")
            return tempURL
        }

        // Skip if already in Documents
        if tempURL.path.hasPrefix(documentsURL.path) {
            print("📁 PageOrganizerView: File already in Documents: \(tempURL.path)")
            return tempURL
        }

        // Create clean filename with timestamp
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: ",", with: "")

        let newFilename = "organize_pages_\(timestamp).pdf"
        let destinationURL = exportsURL.appendingPathComponent(newFilename)

        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }

            // Copy file to persistent location
            try fileManager.copyItem(at: tempURL, to: destinationURL)
            print("✅ PageOrganizerView: Saved file to: \(destinationURL.path)")
            return destinationURL

        } catch {
            print("❌ PageOrganizerView: Failed to save file: \(error)")
            return tempURL
        }
    }
}

// MARK: - Page Info Model
struct PageInfo: Identifiable, Equatable {
    let id = UUID()
    let originalIndex: Int
    var displayIndex: Int
    var thumbnail: UIImage?
    var rotation: Int

    static func == (lhs: PageInfo, rhs: PageInfo) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Undo/Redo State Management

struct PageOrganizerState {
    let pages: [PageInfoSnapshot]
    let selectedPages: Set<UUID>
}

struct PageInfoSnapshot {
    let originalIndex: Int
    let displayIndex: Int
    let rotation: Int
    let id: UUID
    
    init(from page: PageInfo) {
        self.originalIndex = page.originalIndex
        self.displayIndex = page.displayIndex
        self.rotation = page.rotation
        self.id = page.id
    }
}

// MARK: - Page Cell
struct PageCell: View {
    let page: PageInfo
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: () -> Void
    let onDrop: () -> Void
    var hasAnomaly: Bool = false

    @State private var isTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                // Thumbnail
                if let thumbnail = page.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 160)
                        .cornerRadius(8)
                        .rotationEffect(.degrees(Double(page.rotation)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected ? Color.accentColor : (isTargeted ? Color.green : Color.clear), lineWidth: 3)
                        )
                        .shadow(color: isTargeted ? .green.opacity(0.5) : .clear, radius: 8)
                } else {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(height: 160)
                        .cornerRadius(8)
                }

                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                        .background(Circle().fill(Color(.systemBackground)))
                        .offset(x: 8, y: -8)
                }
                
                // Anomaly indicator
                if hasAnomaly {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .background(Circle().fill(Color(.systemBackground)))
                        .offset(x: -8, y: -8)
                }

                // Drag handle hint - make it more prominent
                if !isSelected {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.accentColor.opacity(0.7))
                        .padding(6)
                        .background(Color(.systemBackground).opacity(0.9))
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.1), radius: 2)
                        .offset(x: -8, y: 8)
                }
            }

            // Page number
            Text("Page \(page.displayIndex + 1)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    onTap()
                }
        )
        .onDrag {
            print("PageCell: Starting drag for page \(page.displayIndex + 1)")
            onDrag()
            let itemProvider = NSItemProvider()
            itemProvider.registerDataRepresentation(forTypeIdentifier: UTType.plainText.identifier, visibility: .all) { completion in
                let data = page.id.uuidString.data(using: .utf8) ?? Data()
                completion(data, nil)
                return nil
            }

            // Add a visual preview for the drag
            if let thumbnail = page.thumbnail {
                let _ = NSItemProvider(object: thumbnail)
                itemProvider.registerObject(thumbnail, visibility: .all)
            }

            return itemProvider
        } preview: {
            // Custom drag preview
            if let thumbnail = page.thumbnail {
                VStack(spacing: 4) {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 100, height: 140)
                        .cornerRadius(8)
                        .shadow(color: .black.opacity(0.3), radius: 10)

                    Text("Page \(page.displayIndex + 1)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(4)
                }
            }
        }
        .onDrop(of: [UTType.plainText], delegate: PageDropDelegate(onDrop: onDrop, isTargeted: $isTargeted))
        .animation(.easeInOut(duration: 0.2), value: isTargeted)
    }
}

// MARK: - Drop Delegate
struct PageDropDelegate: DropDelegate {
    let onDrop: () -> Void
    @Binding var isTargeted: Bool

    func performDrop(info: DropInfo) -> Bool {
        print("PageDropDelegate: performDrop called")
        isTargeted = false
        onDrop()
        return true
    }

    func dropEntered(info: DropInfo) {
        print("PageDropDelegate: dropEntered")
        isTargeted = true
    }

    func dropExited(info: DropInfo) {
        print("PageDropDelegate: dropExited")
        isTargeted = false
    }

    func validateDrop(info: DropInfo) -> Bool {
        print("PageDropDelegate: validateDrop called")
        return info.hasItemsConforming(to: [UTType.plainText])
    }
}

#Preview {
    PageOrganizerView(pdfURL: URL(fileURLWithPath: "/tmp/test.pdf"))
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
}
