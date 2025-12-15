//
//  InteractiveSignPDFView.swift
//  OneBox
//
//  Complete interactive PDF signing experience with field detection and placement
//

import SwiftUI
import PDFKit
import UIComponents
import JobEngine

struct InteractiveSignPDFView: View {
    let pdfURL: URL
    var workflowMode: Bool = false  // When true, changes "Done" to "Proceed" for workflow clarity
    let onJobSubmitted: (Job) -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var signaturePlacements: [SignaturePlacement] = []
    @State private var detectedFields: [DetectedSignatureField] = []
    @State private var isDetectingFields = false
    @State private var selectedPlacement: SignaturePlacement?
    @State private var isLoadingPDF = true
    @State private var loadError: String?
    
    // Signature creation
    @State private var showingSignatureCanvas = false
    @State private var showingTextSignature = false
    @State private var currentSignatureData: SignatureData?
    @State private var signatureText = ""
    
    // Use fullScreenCover instead of sheet for better PencilKit compatibility on real devices
    
    // Placement mode
    @State private var isPlacingSignature = false
    @State private var placementSize: CGSize = CGSize(width: 300, height: 120) // Larger default size
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // PDF Viewer Area
                    if let document = pdfDocument, let page = document.page(at: currentPageIndex) {
                        let pageBounds = page.bounds(for: .mediaBox)
                        let pagePlacements = signaturePlacements.filter { $0.pageIndex == currentPageIndex }
                        let pageFields = detectedFields.filter { $0.pageIndex == currentPageIndex }
                        
                        InteractivePDFPageView(
                            page: page,
                            pageIndex: currentPageIndex,
                            pageBounds: pageBounds,
                            detectedFields: pageFields,
                            placements: pagePlacements,
                            onTap: { point, viewWidth in
                                handlePageTap(at: point, in: pageBounds, viewWidth: viewWidth)
                            },
                            onPlacementTap: { placement in
                                // Toggle selection - if same placement, deselect
                                // This allows users to tap a signature to select it,
                                // or tap it again to deselect and place a new one
                                if selectedPlacement?.id == placement.id {
                                    selectedPlacement = nil
                                    HapticManager.shared.selection()
                                } else {
                                    selectedPlacement = placement
                                    HapticManager.shared.selection()
                                }
                            },
                            onPlacementUpdate: { updatedPlacement in
                                updatePlacement(updatedPlacement)
                            },
                            selectedPlacement: selectedPlacement
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .id("pdf-page-\(currentPageIndex)-\(pagePlacements.count)") // Force view refresh when page or placements change
                    } else if let error = loadError {
                        // Error state
                        VStack(spacing: OneBoxSpacing.large) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 48))
                                .foregroundColor(OneBoxColors.warningAmber)
                            Text("Failed to Load PDF")
                                .font(OneBoxTypography.sectionTitle)
                                .foregroundColor(OneBoxColors.primaryText)
                            Text(error)
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            Button("Dismiss") {
                                dismiss()
                            }
                            .foregroundColor(OneBoxColors.primaryGold)
                            .padding(.top)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Loading state
                        VStack(spacing: OneBoxSpacing.medium) {
                            ProgressView()
                                .tint(OneBoxColors.primaryGold)
                                .scaleEffect(1.5)
                            Text("Loading PDF...")
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.secondaryText)
                            if isLoadingPDF {
                                Text("Please wait...")
                                    .font(OneBoxTypography.caption)
                                    .foregroundColor(OneBoxColors.tertiaryText)
                                    .padding(.top, OneBoxSpacing.tiny)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(OneBoxColors.primaryGraphite)
                    }
                    
                    // Controls Bar
                    controlsBar
                }
            }
            .navigationTitle("Sign PDF")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(workflowMode ? "Proceed" : "Done") {
                        processSignatures()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .fontWeight(.semibold)
                    .disabled(signaturePlacements.isEmpty)
                }
            }
            .fullScreenCover(isPresented: $showingSignatureCanvas) {
                EnhancedSignatureCanvasView(signatureData: .constant(nil)) { data in
                    if let data = data {
                        currentSignatureData = .image(data)
                        isPlacingSignature = true
                        showingSignatureCanvas = false // Dismiss after saving
                    }
                }
            }
            .sheet(isPresented: $showingTextSignature) {
                TextSignatureView(signatureText: $signatureText) { text in
                    if !text.isEmpty {
                        currentSignatureData = .text(text)
                        isPlacingSignature = true
                    }
                }
            }
            .task {
                print("🔵 InteractiveSignPDF: View appeared, starting PDF load...")
                await loadPDF()
            }
            .onAppear {
                print("🔵 InteractiveSignPDF: onAppear called")
                print("🔵 InteractiveSignPDF: pdfURL: \(pdfURL)")
                print("🔵 InteractiveSignPDF: pdfDocument is nil: \(pdfDocument == nil)")
                print("🔵 InteractiveSignPDF: isLoadingPDF: \(isLoadingPDF)")
                print("🔵 InteractiveSignPDF: loadError: \(loadError ?? "nil")")
                
                // Load saved signature if available and not already set
                if currentSignatureData == nil, let saved = SignatureManager.shared.getSavedSignature() {
                    currentSignatureData = saved
                    print("🔵 InteractiveSignPDF: Loaded saved signature")
                }
            }
        }
    }
    
    // MARK: - Controls Bar
    private var controlsBar: some View {
        VStack(spacing: OneBoxSpacing.small) {
            // Page Navigation
            HStack {
                Button(action: {
                    if currentPageIndex > 0 {
                        currentPageIndex -= 1
                        HapticManager.shared.selection()
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(currentPageIndex > 0 ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                }
                .disabled(currentPageIndex <= 0)
                
                Spacer()
                
                Text("Page \(currentPageIndex + 1) of \(pdfDocument?.pageCount ?? 0)")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                Button(action: {
                    if let doc = pdfDocument, currentPageIndex < doc.pageCount - 1 {
                        currentPageIndex += 1
                        HapticManager.shared.selection()
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor((pdfDocument?.pageCount ?? 0) > currentPageIndex + 1 ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                }
                .disabled((pdfDocument?.pageCount ?? 0) <= currentPageIndex + 1)
            }
            .padding(.horizontal, OneBoxSpacing.medium)
            
            Divider()
                .background(OneBoxColors.surfaceGraphite)
            
            // Mode indicator with unselect button
            if selectedPlacement != nil {
                HStack {
                    Image(systemName: "hand.draw")
                        .font(.caption)
                        .foregroundColor(OneBoxColors.primaryGold)
                    Text("Selected - Drag to move, pinch to resize")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)

                    Spacer()

                    Button(action: {
                        selectedPlacement = nil
                        HapticManager.shared.selection()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                            Text("Unselect")
                                .font(OneBoxTypography.caption)
                        }
                        .foregroundColor(OneBoxColors.primaryGold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(OneBoxColors.primaryGold.opacity(0.2))
                        .cornerRadius(OneBoxRadius.small)
                    }
                }
                .padding(.horizontal, OneBoxSpacing.medium)
                .padding(.vertical, OneBoxSpacing.tiny)
                .background(OneBoxColors.primaryGold.opacity(0.1))
                .cornerRadius(OneBoxRadius.small)
            }
            
            // Signature Creation Buttons
            HStack(spacing: OneBoxSpacing.medium) {
                // Draw Signature
                Button(action: {
                    showingSignatureCanvas = true
                }) {
                    VStack(spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "pencil.tip")
                            .font(.title2)
                        Text("Draw")
                            .font(OneBoxTypography.caption)
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.primaryGold.opacity(0.1))
                    .cornerRadius(OneBoxRadius.medium)
                }
                
                // Type Signature
                Button(action: {
                    showingTextSignature = true
                }) {
                    VStack(spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "textformat")
                            .font(.title2)
                        Text("Type")
                            .font(OneBoxTypography.caption)
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.primaryGold.opacity(0.1))
                    .cornerRadius(OneBoxRadius.medium)
                }
                
                // Auto-Detect Fields
                Button(action: {
                    detectSignatureFields()
                }) {
                    VStack(spacing: OneBoxSpacing.tiny) {
                        if isDetectingFields {
                            ProgressView()
                                .tint(OneBoxColors.primaryGold)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.title2)
                        }
                        Text("Detect")
                            .font(OneBoxTypography.caption)
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.primaryGold.opacity(0.1))
                    .cornerRadius(OneBoxRadius.medium)
                }
                .disabled(isDetectingFields)
            }
            .padding(.horizontal, OneBoxSpacing.medium)
            
            // Signature Management
            if !signaturePlacements.isEmpty {
                HStack {
                    Text("\(signaturePlacements.count) signature\(signaturePlacements.count == 1 ? "" : "s")")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    Spacer()
                    
                    Button(action: {
                        removeSelectedPlacement()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Remove Selected")
                        }
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.criticalRed)
                    }
                    .disabled(selectedPlacement == nil)
                    
                    Button(action: {
                        clearAllPlacements()
                    }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Clear All")
                        }
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.criticalRed)
                    }
                }
                .padding(.horizontal, OneBoxSpacing.medium)
                .padding(.bottom, OneBoxSpacing.small)
            }
        }
        .padding(.vertical, OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.8))
    }
    
    // MARK: - Functions
    @MainActor
    private func loadPDF(retryCount: Int = 0) async {
        print("🔵 InteractiveSignPDF: loadPDF called, retryCount: \(retryCount)")
        print("🔵 InteractiveSignPDF: PDF URL: \(pdfURL)")
        print("🔵 InteractiveSignPDF: PDF URL path: \(pdfURL.path)")
        
        isLoadingPDF = true
        loadError = nil
        
        // Start accessing security-scoped resource (only on first attempt)
        if retryCount == 0 {
            let hasAccess = pdfURL.startAccessingSecurityScopedResource()
            print("🔵 InteractiveSignPDF: Security-scoped access: \(hasAccess)")
        }
        
        // Verify file exists (with retry for timing issues)
        let fileExists = FileManager.default.fileExists(atPath: pdfURL.path)
        print("🔵 InteractiveSignPDF: File exists check: \(fileExists)")
        
        guard fileExists else {
            if retryCount < 3 {
                print("🔵 InteractiveSignPDF: File not found, retrying in 0.5s (attempt \(retryCount + 1)/3)")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                await loadPDF(retryCount: retryCount + 1)
                return
            }
            // File not found - show error
            print("❌ InteractiveSignPDF Error: File not found at path after 3 retries: \(pdfURL.path)")
            loadError = "PDF file not found. Please try selecting the file again."
            isLoadingPDF = false
            return
        }
        
        // Try to load PDF document
        print("🔵 InteractiveSignPDF: Attempting to load PDFDocument from URL...")
        guard let pdf = PDFDocument(url: pdfURL) else {
            if retryCount < 3 {
                print("🔵 InteractiveSignPDF: Failed to load PDF, retrying in 0.5s (attempt \(retryCount + 1)/3)")
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                await loadPDF(retryCount: retryCount + 1)
                return
            }
            print("❌ InteractiveSignPDF Error: Failed to load PDF from URL after 3 retries: \(pdfURL)")
            loadError = "Failed to load PDF. The file may be corrupted or password-protected."
            isLoadingPDF = false
            return
        }
        
        print("🔵 InteractiveSignPDF: PDFDocument loaded, page count: \(pdf.pageCount)")
        
        // Check if PDF has pages
        guard pdf.pageCount > 0 else {
            print("❌ InteractiveSignPDF Error: PDF has no pages")
            loadError = "This PDF has no pages."
            isLoadingPDF = false
            return
        }
        
        print("✅ InteractiveSignPDF: Successfully loaded PDF with \(pdf.pageCount) pages")
        pdfDocument = pdf
        isLoadingPDF = false
        print("✅ InteractiveSignPDF: pdfDocument state updated, isLoadingPDF: \(isLoadingPDF)")
    }
    
    private func detectSignatureFields() {
        guard let document = pdfDocument else { return }
        
        isDetectingFields = true
        HapticManager.shared.impact(.light)
        
        Task {
            let fields = await SignatureFieldDetectionService.shared.detectSignatureFields(in: document)
            
            await MainActor.run {
                detectedFields = fields
                isDetectingFields = false
                HapticManager.shared.notification(.success)
            }
        }
    }
    
    private func handlePageTap(at point: CGPoint, in pageBounds: CGRect, viewWidth: CGFloat) {
        // Use current signature or load saved one
        let signatureToUse: SignatureData
        if let current = currentSignatureData {
            signatureToUse = current
        } else if let saved = SignatureManager.shared.getSavedSignature() {
            signatureToUse = saved
            currentSignatureData = saved // Keep it available
        } else {
            // No signature ready - show alert or create one
            return
        }

        // Create placement at tap location with actual view width for accurate size calculation
        let placement = SignaturePlacement(
            pageIndex: currentPageIndex,
            position: point,
            size: placementSize,
            signatureData: signatureToUse,
            viewWidthAtPlacement: viewWidth
        )
        
        signaturePlacements.append(placement)
        selectedPlacement = placement
        // Don't clear currentSignatureData - keep it for reuse
        isPlacingSignature = false
        
        HapticManager.shared.notification(.success)
    }
    
    private func removeSelectedPlacement() {
        guard let selected = selectedPlacement else { return }
        signaturePlacements.removeAll { $0.id == selected.id }
        selectedPlacement = nil
        HapticManager.shared.impact(.medium)
    }
    
    private func clearAllPlacements() {
        signaturePlacements.removeAll()
        selectedPlacement = nil
        HapticManager.shared.impact(.medium)
    }
    
    private func updatePlacement(_ updated: SignaturePlacement) {
        if let index = signaturePlacements.firstIndex(where: { $0.id == updated.id }) {
            signaturePlacements[index] = updated
            selectedPlacement = updated
        }
    }
    
    private func processSignatures() {
        guard !signaturePlacements.isEmpty else { return }
        
        // Convert placements to job settings
        // For now, we'll use the first placement (we'll update CorePDF to support multiple later)
        let firstPlacement = signaturePlacements[0]
        
        // Get the actual page bounds for size calculation
        guard let document = pdfDocument,
              let page = document.page(at: firstPlacement.pageIndex) else {
            print("❌ InteractiveSignPDF: Cannot get page for signature placement")
            return
        }
        
        // Calculate signature size as a ratio of page width (must be between 0.0 and 1.0)
        // The placement size is in screen pixels (e.g., 300x120)
        // Use the actual view width stored at placement time for accurate calculation
        let signatureWidthInPixels = firstPlacement.size.width
        let actualViewWidth = firstPlacement.viewWidthAtPlacement
        let calculatedSize: Double

        if signatureWidthInPixels > 0 && actualViewWidth > 0 {
            // Calculate as ratio of actual view width at placement time
            // This gives us the exact visual proportion the user created
            let sizeRatio = Double(signatureWidthInPixels) / Double(actualViewWidth)
            calculatedSize = sizeRatio
        } else {
            calculatedSize = 0.25 // Safe default (1/4 of page width)
        }

        // Clamp size to reasonable range (0.1 to 0.8 of page width)
        let signatureSize = max(0.1, min(0.8, calculatedSize))
        
        // Validate signature data
        var settings = JobSettings()
        
        switch firstPlacement.signatureData {
        case .text(let text):
            guard !text.isEmpty else {
                print("❌ InteractiveSignPDF: Empty signature text")
                loadError = "Signature text cannot be empty. Please create a signature first."
                return
            }
            settings.signatureText = text
        case .image(let data):
            guard !data.isEmpty else {
                print("❌ InteractiveSignPDF: Empty signature image data")
                loadError = "Signature image is empty. Please create a signature first."
                return
            }
            // Validate image can be created from data
            guard UIImage(data: data) != nil else {
                print("❌ InteractiveSignPDF: Invalid signature image data")
                loadError = "Signature image is invalid. Please create a new signature."
                return
            }
            settings.signatureImageData = data
        }
        
        // Validate position is within bounds (0.0 to 1.0)
        // NOTE: Do NOT invert Y here - CorePDF already handles the coordinate system conversion
        // from screen coordinates (Y=0 at top) to PDF coordinates (Y=0 at bottom)
        let clampedPosition = CGPoint(
            x: max(0.0, min(1.0, firstPlacement.position.x)),
            y: max(0.0, min(1.0, firstPlacement.position.y))
        )
        
        // Validate page index
        guard firstPlacement.pageIndex >= 0 && firstPlacement.pageIndex < (document.pageCount) else {
            print("❌ InteractiveSignPDF: Invalid page index: \(firstPlacement.pageIndex)")
            loadError = "Invalid page index for signature. Please try placing the signature again."
            return
        }
        
        settings.signaturePosition = .bottomRight // Default, will be overridden by custom position
        settings.signatureCustomPosition = clampedPosition
        settings.signaturePageIndex = firstPlacement.pageIndex
        settings.signatureSize = signatureSize
        settings.signatureOpacity = 1.0 // Full opacity by default
        
        print("🔵 InteractiveSignPDF: Processing signature with size: \(signatureSize), pageIndex: \(firstPlacement.pageIndex), position: \(clampedPosition), hasImage: \(settings.signatureImageData != nil)")
        
        let job = Job(
            type: .pdfSign,
            inputs: [pdfURL],
            settings: settings
        )
        
        Task {
            do {
                await jobManager.submitJob(job)
                await MainActor.run {
                    // Notify parent that job was submitted, then dismiss
                    onJobSubmitted(job)
                    dismiss()
                }
                HapticManager.shared.notification(.success)
            } catch {
                print("❌ InteractiveSignPDF: Failed to submit job: \(error)")
                await MainActor.run {
                    // Show error to user
                    loadError = "Failed to submit signing job: \(error.localizedDescription)"
                }
            }
        }
    }
}

// MARK: - Text Signature View
struct TextSignatureView: View {
    @Binding var signatureText: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: OneBoxSpacing.large) {
                    Text("Enter Your Signature")
                        .font(OneBoxTypography.heroTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                        .padding(.top, OneBoxSpacing.large)
                    
                    TextField("Type your name", text: $signatureText)
                        .font(UIFont(name: "Snell Roundhand", size: 32) != nil ? Font.custom("Snell Roundhand", size: 32) : Font.system(.title, design: .default).italic())
                        .foregroundColor(OneBoxColors.primaryText)
                        .padding(OneBoxSpacing.large)
                        .background(OneBoxColors.surfaceGraphite)
                        .cornerRadius(OneBoxRadius.large)
                        .padding(.horizontal, OneBoxSpacing.medium)
                    
                    // Preview
                    if !signatureText.isEmpty {
                        VStack(spacing: OneBoxSpacing.small) {
                            Text("Preview:")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            Text(signatureText)
                                .font(UIFont(name: "Snell Roundhand", size: 48) != nil ? Font.custom("Snell Roundhand", size: 48) : Font.system(.largeTitle, design: .default).italic())
                                .foregroundColor(OneBoxColors.primaryText)
                                .padding(OneBoxSpacing.medium)
                                .frame(maxWidth: .infinity)
                                .background(OneBoxColors.surfaceGraphite)
                                .cornerRadius(OneBoxRadius.medium)
                                .padding(.horizontal, OneBoxSpacing.medium)
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        onSave(signatureText)
                        dismiss()
                    }) {
                        Text("Done")
                            .font(OneBoxTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(OneBoxColors.primaryGraphite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, OneBoxSpacing.medium)
                            .background(OneBoxColors.primaryGold)
                            .cornerRadius(OneBoxRadius.medium)
                    }
                    .disabled(signatureText.isEmpty)
                    .padding(.horizontal, OneBoxSpacing.medium)
                    .padding(.bottom, OneBoxSpacing.large)
                }
            }
            .navigationTitle("Text Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
            }
        }
    }
}

