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
    @State private var useCustomDrawing = false // Fallback flag
    @State private var customCanvasRef: CustomDrawingView?
    
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
                    
                    // Large Drawing Canvas - Use custom drawing on real devices
                    if useCustomDrawing {
                        CustomDrawingCanvasWrapper(hasDrawing: $hasDrawing, canvasRef: $customCanvasRef) { hasDrawing in
                            self.hasDrawing = hasDrawing
                        }
                        .background(Color.white)
                        .cornerRadius(OneBoxRadius.large)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .frame(height: 500)
                        .padding(.horizontal, OneBoxSpacing.medium)
                        .padding(.vertical, OneBoxSpacing.large)
                    } else {
                        EnhancedSignatureCanvasWrapper(canvasViewRef: $canvasViewRef) { hasDrawing in
                            self.hasDrawing = hasDrawing
                        }
                        .background(Color.white)
                        .cornerRadius(OneBoxRadius.large)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .frame(height: 500)
                        .padding(.horizontal, OneBoxSpacing.medium)
                        .padding(.vertical, OneBoxSpacing.large)
                    }
                    
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
            .onAppear {
                // Detect if we're on a real device and PencilKit might not work
                // Based on the logs showing "handwritingd" connection errors, use custom drawing
                #if targetEnvironment(simulator)
                // Use PencilKit on simulator
                useCustomDrawing = false
                #else
                // Use custom drawing on real devices to avoid PencilKit issues
                useCustomDrawing = true
                print("🔵 EnhancedSignatureCanvas: Using custom drawing fallback for real device")
                #endif
                
                if !useCustomDrawing {
                    // PencilKit configuration (for simulator)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        if let canvasView = canvasViewRef {
                            canvasView.isUserInteractionEnabled = true
                            canvasView.drawingPolicy = .anyInput
                            canvasView.tool = PKInkingTool(.pen, color: .black, width: 3.0)
                            canvasView.delaysContentTouches = false
                            canvasView.canCancelContentTouches = false
                            canvasView.isMultipleTouchEnabled = false
                            canvasView.setNeedsLayout()
                            canvasView.layoutIfNeeded()
                            if canvasView.canBecomeFirstResponder && !canvasView.isFirstResponder {
                                _ = canvasView.becomeFirstResponder()
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func saveSignature() {
        if useCustomDrawing {
            // Save from custom drawing
            guard let customCanvas = customCanvasRef, customCanvas.hasDrawing else { return }
            guard let image = customCanvas.getImage() else { return }
            guard let imageData = image.pngData() else { return }
            
            // Scale down if too large (preserve transparency)
            let maxDimension: CGFloat = 4096
            let finalImage: UIImage
            if image.size.width > maxDimension || image.size.height > maxDimension {
                let scale = min(maxDimension / image.size.width, maxDimension / image.size.height)
                let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)
                // Use opaque: false to preserve transparency
                UIGraphicsBeginImageContextWithOptions(newSize, false, 2.0)
                defer { UIGraphicsEndImageContext() }
                
                // Clear context to ensure transparency
                if let context = UIGraphicsGetCurrentContext() {
                    context.clear(CGRect(origin: .zero, size: newSize))
                }
                
                // Draw image with transparency preserved
                image.draw(in: CGRect(origin: .zero, size: newSize), blendMode: .normal, alpha: 1.0)
                finalImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
            } else {
                finalImage = image
            }
            
            // Always use PNG to preserve transparency (JPEG doesn't support alpha channel)
            var finalData = finalImage.pngData() ?? imageData
            let maxSize = 10 * 1024 * 1024 // 10MB
            // Note: We don't convert to JPEG here because JPEG doesn't support transparency
            // If size is too large, we'll need to reduce quality or dimensions instead
            if finalData.count > maxSize {
                // Re-scale to smaller size if PNG is too large
                let reducedScale = 0.8
                let reducedSize = CGSize(width: finalImage.size.width * reducedScale, height: finalImage.size.height * reducedScale)
                UIGraphicsBeginImageContextWithOptions(reducedSize, false, 2.0)
                defer { UIGraphicsEndImageContext() }
                
                if let context = UIGraphicsGetCurrentContext() {
                    context.clear(CGRect(origin: .zero, size: reducedSize))
                }
                
                finalImage.draw(in: CGRect(origin: .zero, size: reducedSize), blendMode: .normal, alpha: 1.0)
                if let reducedImage = UIGraphicsGetImageFromCurrentImageContext() {
                    finalData = reducedImage.pngData() ?? finalData
                }
            }
            
            signatureData = finalData
            onSave(finalData)
            SignatureManager.shared.saveSignatureImage(finalData)
            dismiss()
            return
        }
        
        // Save from PencilKit
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
            // Use opaque: false to preserve transparency
            UIGraphicsBeginImageContextWithOptions(scaledSize, false, 2.0)
            defer { UIGraphicsEndImageContext() }
            
            // Clear context to ensure transparency
            if let context = UIGraphicsGetCurrentContext() {
                context.clear(CGRect(origin: .zero, size: scaledSize))
            }
            
            // Draw image with transparency preserved
            image.draw(in: CGRect(origin: .zero, size: scaledSize), blendMode: .normal, alpha: 1.0)
            finalImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
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
        // Create canvas directly - no wrapper to avoid touch issues
        let canvasView = PKCanvasView()
        
        // CRITICAL: Configure for touch input FIRST, before anything else
        canvasView.isUserInteractionEnabled = true
        canvasView.isMultipleTouchEnabled = false
        
        // Configure canvas for better drawing experience
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3.0)
        canvasView.drawingPolicy = .anyInput // Allow finger and pencil
        canvasView.backgroundColor = .white
        canvasView.isOpaque = true
        
        // Disable scrolling and bouncing
        canvasView.alwaysBounceVertical = false
        canvasView.alwaysBounceHorizontal = false
        canvasView.showsVerticalScrollIndicator = false
        canvasView.showsHorizontalScrollIndicator = false
        canvasView.isScrollEnabled = false
        
        // CRITICAL: Ensure canvas can receive touches immediately
        canvasView.delaysContentTouches = false
        canvasView.canCancelContentTouches = false
        
        // Set up delegate
        canvasView.delegate = context.coordinator
        
        // Store reference and ensure canvas is ready
        DispatchQueue.main.async {
            canvasViewRef = canvasView
            // CRITICAL: Delay first responder until view is fully in hierarchy
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                // Re-verify all settings
                canvasView.isUserInteractionEnabled = true
                canvasView.drawingPolicy = .anyInput
                canvasView.delaysContentTouches = false
                canvasView.canCancelContentTouches = false
                // Make first responder after everything is set up
                if canvasView.canBecomeFirstResponder {
                    _ = canvasView.becomeFirstResponder()
                    print("🔵 EnhancedSignatureCanvas: Canvas configured and made first responder")
                }
            }
        }
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        // Ensure configuration is maintained on updates - CRITICAL for real devices
        uiView.isUserInteractionEnabled = true
        uiView.drawingPolicy = .anyInput
        uiView.tool = PKInkingTool(.pen, color: .black, width: 3.0)
        uiView.delaysContentTouches = false
        uiView.canCancelContentTouches = false
        uiView.backgroundColor = .white
        uiView.isOpaque = true
        
        // CRITICAL: Ensure canvas can become first responder for touch input
        if uiView.canBecomeFirstResponder && !uiView.isFirstResponder {
            DispatchQueue.main.async {
                _ = uiView.becomeFirstResponder()
            }
        }
        
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


