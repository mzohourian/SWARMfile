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
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var signaturePlacements: [SignaturePlacement] = []
    @State private var detectedFields: [DetectedSignatureField] = []
    @State private var isDetectingFields = false
    @State private var selectedPlacement: SignaturePlacement?
    
    // Signature creation
    @State private var showingSignatureCanvas = false
    @State private var showingTextSignature = false
    @State private var currentSignatureData: SignatureData?
    @State private var signatureText = ""
    
    // Placement mode
    @State private var isPlacingSignature = false
    @State private var placementSize: CGSize = CGSize(width: 200, height: 80)
    
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
                            onTap: { point in
                                handlePageTap(at: point, in: pageBounds)
                            },
                            onPlacementTap: { placement in
                                selectedPlacement = placement
                                HapticManager.shared.selection()
                            },
                            onPlacementUpdate: { updatedPlacement in
                                updatePlacement(updatedPlacement)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        // Loading state
                        VStack {
                            ProgressView()
                            Text("Loading PDF...")
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.secondaryText)
                                .padding(.top)
                        }
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
                    Button("Done") {
                        processSignatures()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .fontWeight(.semibold)
                    .disabled(signaturePlacements.isEmpty)
                }
            }
            .sheet(isPresented: $showingSignatureCanvas) {
                EnhancedSignatureCanvasView(signatureData: .constant(nil)) { data in
                    if let data = data {
                        currentSignatureData = .image(data)
                        isPlacingSignature = true
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
            .onAppear {
                loadPDF()
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
    private func loadPDF() {
        pdfDocument = PDFDocument(url: pdfURL)
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
    
    private func handlePageTap(at point: CGPoint, in pageBounds: CGRect) {
        guard let signatureData = currentSignatureData else {
            // No signature ready - show alert or create one
            return
        }
        
        // Create placement at tap location
        let placement = SignaturePlacement(
            pageIndex: currentPageIndex,
            position: point,
            size: placementSize,
            signatureData: signatureData
        )
        
        signaturePlacements.append(placement)
        selectedPlacement = placement
        currentSignatureData = nil // Reset for next placement
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
        
        var settings = JobSettings()
        
        switch firstPlacement.signatureData {
        case .text(let text):
            settings.signatureText = text
        case .image(let data):
            settings.signatureImageData = data
        }
        
        settings.signaturePosition = .bottomRight // Default, will be overridden by custom position
        settings.signatureCustomPosition = firstPlacement.position
        settings.signaturePageIndex = firstPlacement.pageIndex
        settings.signatureSize = Double(firstPlacement.size.width / 612.0) // Normalize to page width
        
        let job = Job(
            type: .pdfSign,
            inputs: [pdfURL],
            settings: settings
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

