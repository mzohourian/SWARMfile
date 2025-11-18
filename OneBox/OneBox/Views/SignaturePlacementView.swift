//
//  SignaturePlacementView.swift
//  OneBox
//
//  Interactive signature placement - tap pages to add signatures
//

import SwiftUI
import PDFKit
import CorePDF
import JobEngine

struct SignaturePlacementView: View {
    let pdfURL: URL
    let signatureImage: UIImage?
    let signatureText: String?

    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    @EnvironmentObject var paymentsManager: PaymentsManager

    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var signatures: [PlacedSignature] = []
    @State private var selectedSignature: UUID?
    @State private var isProcessing = false
    @State private var showingPaywall = false
    @State private var completedJob: Job?
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showInstructions = true
    @State private var signatureSize: CGFloat = 0.15 // 15% of page width

    var body: some View {
        NavigationStack {
            ZStack {
                if let pdf = pdfDocument {
                    VStack(spacing: 0) {
                        // Instructions banner
                        if showInstructions {
                            instructionsBanner
                        }

                        // PDF Page Viewer
                        pdfPageViewer(pdf: pdf)

                        // Bottom toolbar
                        bottomToolbar(pdf: pdf)
                    }
                } else {
                    ProgressView("Loading PDF...")
                }

                // Processing overlay
                if isProcessing {
                    processingOverlay
                }
            }
            .navigationTitle("Place Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        applySignatures()
                    }
                    .disabled(signatures.isEmpty)
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
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unknown error occurred")
            }
        }
    }

    // MARK: - Instructions Banner
    private var instructionsBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "hand.tap")
                .font(.title3)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text("Tap anywhere to place your signature")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Drag to reposition, pinch to resize")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                withAnimation {
                    showInstructions = false
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.accentColor.opacity(0.1))
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    // MARK: - PDF Page Viewer
    private func pdfPageViewer(pdf: PDFDocument) -> some View {
        GeometryReader { geometry in
            ZStack {
                if let page = pdf.page(at: currentPageIndex) {
                    // PDF Page Background
                    PDFPageView(page: page)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color(.systemGroupedBackground))
                        .onTapGesture { location in
                            addSignature(at: location, pageSize: geometry.size, page: page)
                        }

                    // Placed signatures on current page
                    ForEach(signatures.filter { $0.pageIndex == currentPageIndex }) { sig in
                        SignatureOverlayView(
                            signature: sig,
                            pageSize: geometry.size,
                            isSelected: selectedSignature == sig.id,
                            onTap: { selectedSignature = sig.id },
                            onDelete: { deleteSignature(sig.id) },
                            onMove: { offset in moveSignature(sig.id, by: offset) },
                            onResize: { scale in resizeSignature(sig.id, scale: scale) }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Bottom Toolbar
    private func bottomToolbar(pdf: PDFDocument) -> some View {
        VStack(spacing: 8) {
            // Page navigation
            HStack {
                Button {
                    if currentPageIndex > 0 {
                        withAnimation {
                            currentPageIndex -= 1
                            selectedSignature = nil
                        }
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                }
                .disabled(currentPageIndex == 0)

                Spacer()

                Text("Page \(currentPageIndex + 1) of \(pdf.pageCount)")
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Button {
                    if currentPageIndex < pdf.pageCount - 1 {
                        withAnimation {
                            currentPageIndex += 1
                            selectedSignature = nil
                        }
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                }
                .disabled(currentPageIndex == pdf.pageCount - 1)
            }
            .padding(.horizontal)

            // Signature count
            if !signatures.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "signature")
                        .foregroundColor(.accentColor)
                    Text("\(signatures.count) signature\(signatures.count == 1 ? "" : "s") placed")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if signatures.contains(where: { $0.pageIndex == currentPageIndex }) {
                        Text("• \(signatures.filter { $0.pageIndex == currentPageIndex }.count) on this page")
                            .font(.caption)
                            .foregroundColor(.accentColor)
                    }
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: -2)
    }

    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Applying signatures...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Actions
    private func loadPDF() {
        guard FileManager.default.fileExists(atPath: pdfURL.path) else {
            errorMessage = "PDF file not found."
            showError = true
            dismiss()
            return
        }

        guard let pdf = PDFDocument(url: pdfURL) else {
            errorMessage = "Failed to load PDF."
            showError = true
            dismiss()
            return
        }

        pdfDocument = pdf
    }

    private func addSignature(at location: CGPoint, pageSize: CGSize, page: PDFPage) {
        let pageBounds = page.bounds(for: .mediaBox)

        // Convert tap location to PDF coordinates (0-1 normalized)
        let normalizedX = location.x / pageSize.width
        let normalizedY = location.y / pageSize.height

        let newSignature = PlacedSignature(
            pageIndex: currentPageIndex,
            normalizedPosition: CGPoint(x: normalizedX, y: normalizedY),
            size: signatureSize,
            image: signatureImage,
            text: signatureText
        )

        withAnimation(.spring(response: 0.3)) {
            signatures.append(newSignature)
            selectedSignature = newSignature.id
        }

        // Auto-hide instructions after first signature
        if showInstructions {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    showInstructions = false
                }
            }
        }
    }

    private func deleteSignature(_ id: UUID) {
        withAnimation {
            signatures.removeAll { $0.id == id }
            if selectedSignature == id {
                selectedSignature = nil
            }
        }
    }

    private func moveSignature(_ id: UUID, by offset: CGSize) {
        guard let index = signatures.firstIndex(where: { $0.id == id }) else { return }

        // Update position with bounds checking
        var sig = signatures[index]
        let newX = max(0, min(1, sig.normalizedPosition.x + offset.width))
        let newY = max(0, min(1, sig.normalizedPosition.y + offset.height))
        sig.normalizedPosition = CGPoint(x: newX, y: newY)

        signatures[index] = sig
    }

    private func resizeSignature(_ id: UUID, scale: CGFloat) {
        guard let index = signatures.firstIndex(where: { $0.id == id }) else { return }

        var sig = signatures[index]
        sig.size = max(0.05, min(0.5, sig.size * scale))
        signatures[index] = sig
    }

    private func applySignatures() {
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
                var outputURL = pdfURL

                // Apply each signature
                for signature in signatures {
                    guard let page = pdf.page(at: signature.pageIndex) else { continue }
                    let pageBounds = page.bounds(for: .mediaBox)

                    // Convert normalized position to actual PDF coordinates
                    let x = signature.normalizedPosition.x * pageBounds.width
                    let y = (1 - signature.normalizedPosition.y) * pageBounds.height // Flip Y

                    // Calculate signature size
                    let sigWidth = pageBounds.width * signature.size

                    // Create position (center the signature at tap point)
                    let position = WatermarkPosition.custom(
                        x: x - (sigWidth / 2),
                        y: y - (sigWidth / 2)
                    )

                    // Apply signature to this page only
                    outputURL = try await processor.signPDF(
                        outputURL,
                        pageIndex: signature.pageIndex,
                        text: signature.text,
                        image: signature.image,
                        position: position,
                        opacity: 1.0,
                        size: signature.size,
                        progressHandler: { _ in }
                    )
                }

                // Create job record
                let job = Job(
                    type: .pdfSign,
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

// MARK: - Placed Signature Model
struct PlacedSignature: Identifiable {
    let id = UUID()
    var pageIndex: Int
    var normalizedPosition: CGPoint  // 0-1 normalized coordinates
    var size: CGFloat  // As percentage of page width
    let image: UIImage?
    let text: String?
}

// MARK: - PDF Page View
struct PDFPageView: UIViewRepresentable {
    let page: PDFPage

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument()
        pdfView.document?.insert(page, at: 0)
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .white
        pdfView.isUserInteractionEnabled = false
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {}
}

// MARK: - Signature Overlay View
struct SignatureOverlayView: View {
    let signature: PlacedSignature
    let pageSize: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onDelete: () -> Void
    let onMove: (CGSize) -> Void
    let onResize: (CGFloat) -> Void

    @State private var dragOffset: CGSize = .zero
    @State private var currentScale: CGFloat = 1.0

    var body: some View {
        let signatureWidth = pageSize.width * signature.size * currentScale
        let position = CGPoint(
            x: signature.normalizedPosition.x * pageSize.width,
            y: signature.normalizedPosition.y * pageSize.height
        )

        ZStack {
            // Signature content
            Group {
                if let image = signature.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else if let text = signature.text {
                    Text(text)
                        .font(.system(size: signatureWidth * 0.3, weight: .medium, design: .serif))
                        .foregroundColor(.black)
                        .padding(8)
                        .background(Color.white.opacity(0.9))
                }
            }
            .frame(width: signatureWidth)
            .cornerRadius(4)
            .shadow(color: .black.opacity(0.2), radius: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )

            // Delete button (when selected)
            if isSelected {
                Button {
                    onDelete()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.white)
                        .background(Circle().fill(Color.red))
                }
                .offset(x: signatureWidth / 2 + 12, y: -(signatureWidth / 4) - 12)
            }
        }
        .position(x: position.x + dragOffset.width, y: position.y + dragOffset.height)
        .onTapGesture {
            onTap()
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    dragOffset = value.translation
                }
                .onEnded { value in
                    let normalizedOffset = CGSize(
                        width: value.translation.width / pageSize.width,
                        height: value.translation.height / pageSize.height
                    )
                    onMove(normalizedOffset)
                    dragOffset = .zero
                }
        )
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    currentScale = value
                }
                .onEnded { value in
                    onResize(value)
                    currentScale = 1.0
                }
        )
    }
}

#Preview {
    SignaturePlacementView(
        pdfURL: URL(fileURLWithPath: "/tmp/test.pdf"),
        signatureImage: nil,
        signatureText: "John Doe"
    )
    .environmentObject(JobManager.shared)
    .environmentObject(PaymentsManager.shared)
}
