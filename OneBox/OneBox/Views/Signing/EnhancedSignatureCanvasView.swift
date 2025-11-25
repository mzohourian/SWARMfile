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
                    
                    // Large Drawing Canvas - simplified to avoid touch blocking
                    VStack {
                        EnhancedSignatureCanvasWrapper(canvasViewRef: $canvasViewRef) { hasDrawing in
                            self.hasDrawing = hasDrawing
                        }
                        .background(Color.white)
                        .cornerRadius(OneBoxRadius.large)
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
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
    
    func makeUIView(context: Context) -> TouchableCanvasView {
        // Use a custom wrapper view that ensures touches work
        let wrapperView = TouchableCanvasView()
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
        
        // Add canvas to wrapper
        wrapperView.addSubview(canvasView)
        wrapperView.canvasView = canvasView
        
        // Set up constraints - CRITICAL for real devices
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: wrapperView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: wrapperView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: wrapperView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: wrapperView.bottomAnchor)
        ])
        
        // CRITICAL: Force layout immediately for real devices
        wrapperView.setNeedsLayout()
        wrapperView.layoutIfNeeded()
        canvasView.setNeedsLayout()
        canvasView.layoutIfNeeded()
        
        // Store reference
        DispatchQueue.main.async {
            canvasViewRef = canvasView
        }
        
        return wrapperView
    }
    
    func updateUIView(_ uiView: TouchableCanvasView, context: Context) {
        // Ensure configuration is maintained on updates
        if let canvasView = uiView.canvasView {
            canvasView.isUserInteractionEnabled = true
            canvasView.drawingPolicy = .anyInput
            canvasView.tool = PKInkingTool(.pen, color: .black, width: 3.0)
            canvasView.delaysContentTouches = false
            canvasView.canCancelContentTouches = false
            canvasView.backgroundColor = .white
            canvasView.isOpaque = true
            
            // Update reference if needed
            if canvasViewRef != canvasView {
                DispatchQueue.main.async {
                    canvasViewRef = canvasView
                }
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

// MARK: - Touchable Canvas View Wrapper
class TouchableCanvasView: UIView {
    var canvasView: PKCanvasView?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        backgroundColor = .white
        isUserInteractionEnabled = true
        isMultipleTouchEnabled = false
        // CRITICAL for real devices
        delaysContentTouches = false
        canCancelContentTouches = false
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // CRITICAL: Ensure canvas view has proper frame after layout
        // This is essential for touch input on real devices
        if let canvasView = canvasView {
            canvasView.frame = bounds
            // Force canvas to update its internal layout
            canvasView.setNeedsLayout()
            canvasView.layoutIfNeeded()
            // Re-enable interaction after layout (sometimes gets disabled on real devices)
            canvasView.isUserInteractionEnabled = true
            canvasView.drawingPolicy = .anyInput
        }
    }
    
    // CRITICAL: Override hit testing to ensure touches reach the canvas
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Always return the canvas view if it exists and point is within bounds
        if let canvasView = canvasView, bounds.contains(point) {
            // Ensure canvas is properly configured
            canvasView.isUserInteractionEnabled = true
            let canvasPoint = convert(point, to: canvasView)
            if let hitView = canvasView.hitTest(canvasPoint, with: event) {
                return hitView
            }
            return canvasView
        }
        return super.hitTest(point, with: event)
    }
    
    // Ensure touches are passed through
    override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
        return bounds.contains(point)
    }
    
    // CRITICAL: Override touch methods to ensure they reach the canvas
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        // Forward to canvas if needed
        if let canvasView = canvasView {
            canvasView.touchesBegan(touches, with: event)
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        if let canvasView = canvasView {
            canvasView.touchesMoved(touches, with: event)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        if let canvasView = canvasView {
            canvasView.touchesEnded(touches, with: event)
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        if let canvasView = canvasView {
            canvasView.touchesCancelled(touches, with: event)
        }
    }
}

