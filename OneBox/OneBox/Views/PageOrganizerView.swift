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

    // Drag & drop state
    @State private var draggedPage: PageInfo?

    var body: some View {
        NavigationStack {
            ZStack {
                if let pdf = pdfDocument, !pages.isEmpty {
                    VStack(spacing: 0) {
                        // Selection info bar
                        if !selectedPages.isEmpty {
                            selectionInfoBar
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
                                        onDrop: { handleDrop(page) }
                                    )
                                }
                            }
                            .padding()
                        }

                        // Bottom toolbar
                        bottomToolbar
                    }
                } else {
                    ProgressView("Loading PDF...")
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
                loadPDF()
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
        }
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
        HStack(spacing: 20) {
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
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
    }

    // MARK: - Actions
    private func loadPDF() {
        guard let pdf = PDFDocument(url: pdfURL) else {
            errorMessage = "Failed to load PDF"
            showError = true
            dismiss()
            return
        }

        pdfDocument = pdf

        // Load pages and generate thumbnails
        var loadedPages: [PageInfo] = []

        for pageIndex in 0..<pdf.pageCount {
            guard let page = pdf.page(at: pageIndex) else { continue }

            let thumbnail = page.thumbnail(of: CGSize(width: 200, height: 280), for: .mediaBox)

            loadedPages.append(PageInfo(
                originalIndex: pageIndex,
                displayIndex: pageIndex,
                thumbnail: thumbnail,
                rotation: 0
            ))
        }

        pages = loadedPages
    }

    private func toggleSelection(_ page: PageInfo) {
        if selectedPages.contains(page.id) {
            selectedPages.remove(page.id)
        } else {
            selectedPages.insert(page.id)
        }
    }

    private func handleDrop(_ targetPage: PageInfo) {
        guard let draggedPage = draggedPage,
              let sourceIndex = pages.firstIndex(where: { $0.id == draggedPage.id }),
              let targetIndex = pages.firstIndex(where: { $0.id == targetPage.id }),
              sourceIndex != targetIndex else {
            self.draggedPage = nil
            return
        }

        withAnimation {
            let movedPage = pages.remove(at: sourceIndex)
            pages.insert(movedPage, at: targetIndex)

            // Update display indices
            for (index, _) in pages.enumerated() {
                pages[index].displayIndex = index
            }
        }

        self.draggedPage = nil
    }

    private func rotateLeft() {
        for id in selectedPages {
            if let index = pages.firstIndex(where: { $0.id == id }) {
                pages[index].rotation = (pages[index].rotation - 90) % 360
            }
        }
        selectedPages.removeAll()
    }

    private func rotateRight() {
        for id in selectedPages {
            if let index = pages.firstIndex(where: { $0.id == id }) {
                pages[index].rotation = (pages[index].rotation + 90) % 360
            }
        }
        selectedPages.removeAll()
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
                    // Reload PDF from reordered output
                    guard let reorderedPDF = PDFDocument(url: outputURL) else {
                        throw PDFError.invalidPDF("Reordered PDF")
                    }

                    // Find indices of pages that need rotation
                    let rotationMap = pages.enumerated().filter { $0.element.rotation != 0 }

                    for (newIndex, pageInfo) in rotationMap {
                        let indices = Set([newIndex])
                        outputURL = try await processor.rotatePages(
                            in: reorderedPDF,
                            indices: indices,
                            angle: pageInfo.rotation,
                            progressHandler: { _ in }
                        )
                    }
                }

                // Create job record
                let job = Job(
                    type: .pdfOrganize,
                    inputs: [pdfURL],
                    settings: JobSettings(),
                    status: .success,
                    progress: 1.0,
                    outputURLs: [outputURL],
                    completedAt: Date()
                )

                await MainActor.run {
                    jobManager.submitJob(job)
                    paymentsManager.consumeExport()
                    completedJob = job
                    isProcessing = false
                    dismiss()
                    showingResult = true
                }

            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
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

// MARK: - Page Cell
struct PageCell: View {
    let page: PageInfo
    let isSelected: Bool
    let onTap: () -> Void
    let onDrag: () -> Void
    let onDrop: () -> Void

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
                                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                        )
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
            }

            // Page number
            Text("Page \(page.displayIndex + 1)")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
        .onDrag {
            onDrag()
            return NSItemProvider(object: page.id.uuidString as NSString)
        }
        .onDrop(of: [.text], delegate: PageDropDelegate(onDrop: onDrop))
    }
}

// MARK: - Drop Delegate
struct PageDropDelegate: DropDelegate {
    let onDrop: () -> Void

    func performDrop(info: DropInfo) -> Bool {
        onDrop()
        return true
    }

    func dropEntered(info: DropInfo) {
        // Optional: Add visual feedback
    }

    func dropExited(info: DropInfo) {
        // Optional: Remove visual feedback
    }
}

#Preview {
    PageOrganizerView(pdfURL: URL(fileURLWithPath: "/tmp/test.pdf"))
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
}
