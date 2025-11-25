//
//  EnhancedSignatureCanvasView.swift
//  OneBox
//
//  Large, usable signature drawing canvas with improved UX
//

import SwiftUI
import PencilKit
import UIComponents

struct EnhancedSignatureCanvasView: View {
    @Binding var signatureData: Data?
    let onSave: (Data?) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var hasDrawing = false
    @State private var showClearConfirmation = false
    @State private var canvasViewRef: PKCanvasView?
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Instructions
                    VStack(spacing: OneBoxSpacing.small) {
                        Text("Draw Your Signature")
                            .font(OneBoxTypography.heroTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Use your finger or Apple Pencil")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    .padding(.top, OneBoxSpacing.large)
                    .padding(.horizontal, OneBoxSpacing.medium)
                    
                    // Large Drawing Canvas
                    ZStack {
                        // Background
                        RoundedRectangle(cornerRadius: OneBoxRadius.large)
                            .fill(Color.white)
                            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        
                        // Drawing Canvas - ensure it's on top and can receive touches
                        EnhancedSignatureCanvasWrapper(canvasViewRef: $canvasViewRef) { hasDrawing in
                            self.hasDrawing = hasDrawing
                        }
                        .padding(OneBoxSpacing.medium)
                        .contentShape(Rectangle()) // Ensure entire area is tappable
                        .allowsHitTesting(true) // Explicitly enable hit testing
                    }
                    .frame(height: 500) // Large, usable size
                    .padding(.horizontal, OneBoxSpacing.medium)
                    .padding(.vertical, OneBoxSpacing.large)
                    
                    // Controls
                    HStack(spacing: OneBoxSpacing.large) {
                        // Undo Button
                        Button(action: {
                            undoLastStroke()
                        }) {
                            HStack {
                                Image(systemName: "arrow.uturn.backward")
                                Text("Undo")
                            }
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                            .padding(.horizontal, OneBoxSpacing.medium)
                            .padding(.vertical, OneBoxSpacing.small)
                            .background(OneBoxColors.surfaceGraphite)
                            .cornerRadius(OneBoxRadius.medium)
                        }
                        .disabled(!hasDrawing)
                        
                        // Clear Button
                        Button(action: {
                            showClearConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear")
                            }
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.criticalRed)
                            .padding(.horizontal, OneBoxSpacing.medium)
                            .padding(.vertical, OneBoxSpacing.small)
                            .background(OneBoxColors.criticalRed.opacity(0.1))
                            .cornerRadius(OneBoxRadius.medium)
                        }
                        .disabled(!hasDrawing)
                        
                        Spacer()
                        
                        // Save Button
                        Button(action: {
                            saveSignature()
                        }) {
                            HStack {
                                Image(systemName: "checkmark")
                                Text("Done")
                            }
                            .font(OneBoxTypography.body)
                            .fontWeight(.semibold)
                            .foregroundColor(OneBoxColors.primaryGraphite)
                            .padding(.horizontal, OneBoxSpacing.large)
                            .padding(.vertical, OneBoxSpacing.medium)
                            .background(OneBoxColors.primaryGold)
                            .cornerRadius(OneBoxRadius.medium)
                        }
                        .disabled(!hasDrawing)
                    }
                    .padding(.horizontal, OneBoxSpacing.medium)
                    .padding(.bottom, OneBoxSpacing.large)
                }
            }
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
            }
            .alert("Clear Signature?", isPresented: $showClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear", role: .destructive) {
                    clearCanvas()
                }
            } message: {
                Text("This will erase your entire signature.")
            }
        }
    }
    
    private func saveSignature() {
        guard let canvasView = canvasViewRef, !canvasView.drawing.bounds.isEmpty else { return }
        
        let image = canvasView.drawing.image(
            from: canvasView.drawing.bounds,
            scale: 2.0
        )
        
        // Validate and compress if needed
        let maxDimension: CGFloat = 4096
        var finalImage = image
        
        if image.size.width > maxDimension || image.size.height > maxDimension {
            let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
            let scaledSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
            UIGraphicsBeginImageContextWithOptions(scaledSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: scaledSize))
            finalImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            UIGraphicsEndImageContext()
        }
        
        // Convert to PNG data
        var savedData: Data?
        if let data = finalImage.pngData() {
            // Limit to 10MB
            if data.count <= 10 * 1024 * 1024 {
                savedData = data
            } else {
                // Use JPEG compression if too large
                if let jpegData = finalImage.jpegData(compressionQuality: 0.8) {
                    savedData = jpegData
                }
            }
        }
        
        signatureData = savedData
        onSave(savedData)
        HapticManager.shared.notification(.success)
        dismiss()
    }
    
    private func clearCanvas() {
        guard let canvasView = canvasViewRef else { return }
        canvasView.drawing = PKDrawing()
        signatureData = nil
        hasDrawing = false
        HapticManager.shared.impact(.medium)
    }
    
    private func undoLastStroke() {
        guard let canvasView = canvasViewRef else { return }
        let strokes = canvasView.drawing.strokes
        guard !strokes.isEmpty else { return }
        
        var newDrawing = canvasView.drawing
        newDrawing.strokes.removeLast()
        canvasView.drawing = newDrawing
        
        hasDrawing = !canvasView.drawing.bounds.isEmpty
        HapticManager.shared.impact(.light)
    }
}

// MARK: - Canvas View Wrapper
struct EnhancedSignatureCanvasWrapper: UIViewRepresentable {
    @Binding var canvasViewRef: PKCanvasView?
    let onDrawingChanged: (Bool) -> Void
    
    func makeUIView(context: Context) -> PKCanvasView {
        // Create a fresh canvas view - don't reuse from state
        let canvasView = PKCanvasView()
        
        // Configure canvas for better drawing experience
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3.0)
        canvasView.drawingPolicy = .anyInput // Allow finger and pencil
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        
        // CRITICAL: Enable user interaction for touch input on real devices
        canvasView.isUserInteractionEnabled = true
        canvasView.isMultipleTouchEnabled = false // Single touch only for drawing
        
        // Disable scrolling and bouncing
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.isScrollEnabled = false
        
        // Ensure canvas can receive touches
        canvasView.delaysContentTouches = false
        canvasView.canCancelContentTouches = false
        
        // CRITICAL for real devices: Ensure proper layout
        // Don't set contentSize directly - let it be determined by the frame
        // But ensure the view has a proper frame
        canvasView.frame = CGRect(x: 0, y: 0, width: 1000, height: 500)
        
        // Set up delegate
        canvasView.delegate = context.coordinator
        
        // Store reference
        DispatchQueue.main.async {
            canvasViewRef = canvasView
        }
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Ensure configuration is maintained on updates
        uiView.isUserInteractionEnabled = true
        uiView.drawingPolicy = .anyInput
        uiView.tool = PKInkingTool(.pen, color: .black, width: 3.0)
        uiView.delaysContentTouches = false
        uiView.canCancelContentTouches = false
        
        // Update reference if needed
        if canvasViewRef != uiView {
            DispatchQueue.main.async {
                canvasViewRef = uiView
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onDrawingChanged: onDrawingChanged)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let onDrawingChanged: (Bool) -> Void
        
        init(onDrawingChanged: @escaping (Bool) -> Void) {
            self.onDrawingChanged = onDrawingChanged
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let hasDrawing = !canvasView.drawing.bounds.isEmpty
            onDrawingChanged(hasDrawing)
        }
    }
}

