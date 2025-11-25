//
//  InteractivePDFPageView.swift
//  OneBox
//
//  Interactive PDF page viewer with gesture support for signature placement
//

import SwiftUI
import PDFKit
import UIKit

struct InteractivePDFPageView: View {
    let page: PDFPage
    let pageIndex: Int
    let pageBounds: CGRect
    let detectedFields: [DetectedSignatureField]
    let placements: [SignaturePlacement]
    let onTap: (CGPoint) -> Void
    let onPlacementTap: (SignaturePlacement) -> Void
    let onPlacementUpdate: ((SignaturePlacement) -> Void)?
    
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var selectedPlacement: SignaturePlacement?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // PDF Page Content
                PDFPageViewRepresentable(
                    page: page,
                    pageBounds: pageBounds,
                    scale: scale,
                    offset: offset
                )
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                
                // Detected Signature Fields Overlay
                ForEach(detectedFields) { field in
                    DetectedFieldOverlay(field: field, pageBounds: pageBounds, geometry: geometry)
                }
                
                // Signature Placements Overlay
                ForEach(placements) { placement in
                    SignaturePlacementOverlay(
                        placement: placement,
                        pageBounds: pageBounds,
                        geometry: geometry,
                        isSelected: selectedPlacement?.id == placement.id,
                        onTap: {
                            selectedPlacement = placement
                            onPlacementTap(placement)
                        },
                        onUpdate: { updated in
                            onPlacementUpdate?(updated)
                        }
                    )
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let normalizedPoint = normalizePoint(value.location, in: geometry.size)
                        onTap(normalizedPoint)
                        HapticManager.shared.impact(.light)
                    }
            )
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = lastScale * value
                    }
                    .onEnded { _ in
                        lastScale = scale
                        // Clamp scale
                        scale = min(max(scale, 0.5), 3.0)
                        lastScale = scale
                    }
            )
        }
    }
    
    private func normalizePoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        // Account for scale and offset
        let adjustedPoint = CGPoint(
            x: (point.x - offset.width) / scale,
            y: (point.y - offset.height) / scale
        )
        
        // Normalize to 0.0-1.0
        return CGPoint(
            x: max(0.0, min(1.0, adjustedPoint.x / size.width)),
            y: max(0.0, min(1.0, adjustedPoint.y / size.height))
        )
    }
}

// MARK: - PDF Page View Representable
struct PDFPageViewRepresentable: UIViewRepresentable {
    let page: PDFPage
    let pageBounds: CGRect
    let scale: CGFloat
    let offset: CGSize
    
    func makeUIView(context: Context) -> PDFPageView {
        let view = PDFPageView()
        view.page = page
        view.pageBounds = pageBounds
        return view
    }
    
    func updateUIView(_ uiView: PDFPageView, context: Context) {
        uiView.page = page
        uiView.pageBounds = pageBounds
        uiView.transform = CGAffineTransform(scaleX: scale, y: scale)
            .translatedBy(x: offset.width, y: offset.height)
    }
}

class PDFPageView: UIView {
    var page: PDFPage? {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var pageBounds: CGRect = .zero {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard let page = page else { return }
        
        let context = UIGraphicsGetCurrentContext()!
        context.saveGState()
        
        // Draw PDF page
        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        
        page.draw(with: .mediaBox, to: context)
        
        context.restoreGState()
    }
}

// MARK: - Detected Field Overlay
struct DetectedFieldOverlay: View {
    let field: DetectedSignatureField
    let pageBounds: CGRect
    let geometry: GeometryProxy
    
    var body: some View {
        let normalizedBounds = field.normalizedBounds(in: pageBounds)
        let screenBounds = CGRect(
            x: normalizedBounds.minX * geometry.size.width,
            y: normalizedBounds.minY * geometry.size.height,
            width: normalizedBounds.width * geometry.size.width,
            height: normalizedBounds.height * geometry.size.height
        )
        
        RoundedRectangle(cornerRadius: 4)
            .stroke(OneBoxColors.primaryGold, lineWidth: 2)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(OneBoxColors.primaryGold.opacity(0.1))
            )
            .frame(width: screenBounds.width, height: screenBounds.height)
            .position(x: screenBounds.midX, y: screenBounds.midY)
            .overlay(
                HStack {
                    Image(systemName: "signature")
                        .font(.caption)
                        .foregroundColor(OneBoxColors.primaryGold)
                    if let label = field.label {
                        Text(label)
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                .padding(4)
                .background(OneBoxColors.primaryGold.opacity(0.9))
                .cornerRadius(4)
                .offset(x: 0, y: -screenBounds.height / 2 - 20)
            )
    }
}

// MARK: - Signature Placement Overlay
struct SignaturePlacementOverlay: View {
    let placement: SignaturePlacement
    let pageBounds: CGRect
    let geometry: GeometryProxy
    let isSelected: Bool
    let onTap: () -> Void
    let onUpdate: (SignaturePlacement) -> Void
    
    @State private var currentSize: CGSize
    @State private var currentPosition: CGPoint
    @State private var lastMagnification: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    
    init(placement: SignaturePlacement, pageBounds: CGRect, geometry: GeometryProxy, isSelected: Bool, onTap: @escaping () -> Void, onUpdate: @escaping (SignaturePlacement) -> Void) {
        self.placement = placement
        self.pageBounds = pageBounds
        self.geometry = geometry
        self.isSelected = isSelected
        self.onTap = onTap
        self.onUpdate = onUpdate
        _currentSize = State(initialValue: placement.size)
        _currentPosition = State(initialValue: placement.position)
        _lastScale = State(initialValue: 1.0)
    }
    
    var body: some View {
        // Use placement position as base, then apply drag offset
        let baseScreenPos = CGPoint(
            x: placement.position.x * geometry.size.width,
            y: placement.position.y * geometry.size.height
        )
        let screenPos = CGPoint(
            x: baseScreenPos.x + dragOffset.width,
            y: baseScreenPos.y + dragOffset.height
        )
        
        // Signature preview
        ZStack {
            if case .image(let data) = placement.signatureData,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: currentSize.width, height: currentSize.height)
            } else if case .text(let text) = placement.signatureData {
                Text(text)
                    .font(UIFont(name: "Snell Roundhand", size: min(24, currentSize.height * 0.3)) != nil ? Font.custom("Snell Roundhand", size: min(24, currentSize.height * 0.3)) : Font.system(.body).italic())
                    .foregroundColor(.black)
                    .frame(width: currentSize.width, height: currentSize.height)
            }
            
            // Selection indicator with resize handles
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(OneBoxColors.primaryGold, lineWidth: 2)
                    .frame(width: currentSize.width + 10, height: currentSize.height + 10)
                
                // Resize handles (corners)
                ForEach(0..<4) { index in
                    Circle()
                        .fill(OneBoxColors.primaryGold)
                        .frame(width: 12, height: 12)
                        .position(resizeHandlePosition(for: index))
                }
            }
        }
        .position(x: screenPos.x, y: screenPos.y)
        .onTapGesture {
            if !isSelected {
                onTap()
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if isSelected {
                        // Update drag offset for visual feedback
                        dragOffset = value.translation
                    }
                }
                .onEnded { value in
                    if isSelected {
                        // Calculate final screen position
                        let finalScreenX = baseScreenPos.x + value.translation.width
                        let finalScreenY = baseScreenPos.y + value.translation.height
                        
                        // Convert to normalized coordinates
                        let newPosition = CGPoint(
                            x: max(0.0, min(1.0, finalScreenX / geometry.size.width)),
                            y: max(0.0, min(1.0, finalScreenY / geometry.size.height))
                        )
                        
                        var updated = placement
                        updated.position = newPosition
                        onUpdate(updated)
                        
                        // Update current position to match
                        currentPosition = newPosition
                        dragOffset = .zero
                    }
                }
        )
        .simultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    if isSelected {
                        // Calculate scale relative to base size
                        let baseWidth = placement.size.width / lastScale
                        let baseHeight = placement.size.height / lastScale
                        let scale = value
                        
                        let newWidth = baseWidth * scale
                        let newHeight = baseHeight * scale
                        
                        // Clamp size
                        let minSize: CGFloat = 50
                        let maxSize: CGFloat = 400
                        currentSize = CGSize(
                            width: max(minSize, min(maxSize, newWidth)),
                            height: max(minSize, min(maxSize, newHeight))
                        )
                    }
                }
                .onEnded { finalValue in
                    if isSelected {
                        // Calculate final scale
                        let baseWidth = placement.size.width / lastScale
                        let baseHeight = placement.size.height / lastScale
                        let finalWidth = baseWidth * finalValue
                        let finalHeight = baseHeight * finalValue
                        
                        // Clamp and update
                        let minSize: CGFloat = 50
                        let maxSize: CGFloat = 400
                        let finalSize = CGSize(
                            width: max(minSize, min(maxSize, finalWidth)),
                            height: max(minSize, min(maxSize, finalHeight))
                        )
                        
                        var updated = placement
                        updated.size = finalSize
                        onUpdate(updated)
                        
                        // Update tracking variables
                        lastScale = finalValue
                        lastMagnification = finalSize.width / (placement.size.width / lastScale)
                        currentSize = finalSize
                    }
                }
        )
    }
    
    private func resizeHandlePosition(for index: Int) -> CGPoint {
        let halfWidth = currentSize.width / 2 + 5
        let halfHeight = currentSize.height / 2 + 5
        
        switch index {
        case 0: return CGPoint(x: -halfWidth, y: -halfHeight) // Top-left
        case 1: return CGPoint(x: halfWidth, y: -halfHeight)  // Top-right
        case 2: return CGPoint(x: -halfWidth, y: halfHeight) // Bottom-left
        case 3: return CGPoint(x: halfWidth, y: halfHeight)  // Bottom-right
        default: return .zero
        }
    }
}

