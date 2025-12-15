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
    let onTap: (CGPoint, CGFloat) -> Void  // (normalizedPoint relative to PDF page, pdfDisplayWidth)
    let onPlacementTap: (SignaturePlacement) -> Void
    let onPlacementUpdate: ((SignaturePlacement) -> Void)?
    let selectedPlacement: SignaturePlacement? // Pass from parent

    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var viewSize: CGSize = .zero
    @State private var initialFitScale: CGFloat = 1.0 // Store the initial fit scale

    // Calculate the PDF page's display rectangle within the view
    private func pdfDisplayRect(in viewSize: CGSize) -> CGRect {
        let scaledWidth = pageBounds.width * scale
        let scaledHeight = pageBounds.height * scale
        return CGRect(
            x: offset.width + (viewSize.width - scaledWidth) / 2,
            y: offset.height + (viewSize.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }
    
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
                .onAppear {
                    // Store view size and calculate initial scale with a small delay
                    // to ensure geometry is fully laid out
                    viewSize = geometry.size
                    DispatchQueue.main.async {
                        if self.viewSize != .zero {
                            self.calculateInitialScale(viewSize: self.viewSize)
                        }
                    }
                }
                .onChange(of: geometry.size) { newSize in
                    // Recalculate when view size changes
                    viewSize = newSize
                    if viewSize != .zero && viewSize.width > 0 && viewSize.height > 0 {
                        calculateInitialScale(viewSize: newSize)
                    }
                }
                .onChange(of: pageIndex) { _ in
                    // Reset zoom and recalculate when page changes
                    // This ensures each page starts at the correct fit scale
                    if viewSize != .zero && viewSize.width > 0 && viewSize.height > 0 {
                        // Reset zoom state first
                        scale = 1.0
                        lastScale = 1.0
                        offset = .zero
                        lastOffset = .zero
                        // Then recalculate for new page
                        calculateInitialScale(viewSize: viewSize)
                    }
                }
                
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
                        pdfScale: scale,
                        pdfOffset: offset,
                        isSelected: selectedPlacement?.id == placement.id,
                        onTap: {
                            onPlacementTap(placement)
                        },
                        onUpdate: { updated in
                            onPlacementUpdate?(updated)
                        }
                    )
                }
            }
            .gesture(
                // Pan gesture for page navigation (only when zoomed in and no signature selected)
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        // Only pan if zoomed in (scale > initial fit scale) and no signature is selected
                        if scale > initialFitScale * 1.1 && selectedPlacement == nil {
                            offset = CGSize(
                                width: lastOffset.width + value.translation.width,
                                height: lastOffset.height + value.translation.height
                            )
                        }
                    }
                    .onEnded { _ in
                        if scale > initialFitScale * 1.1 && selectedPlacement == nil {
                            lastOffset = offset
                        }
                    }
            )
            .gesture(
                // Tap gesture for signature placement
                DragGesture(minimumDistance: 0)
                    .onEnded { value in
                        let pdfRect = pdfDisplayRect(in: geometry.size)

                        // Check if tap is on an existing signature
                        let tapPoint = value.location
                        var tappedOnSignature = false
                        for placement in placements {
                            // Calculate signature screen position relative to PDF page
                            let screenPos = CGPoint(
                                x: pdfRect.minX + (placement.position.x * pdfRect.width),
                                y: pdfRect.minY + (placement.position.y * pdfRect.height)
                            )
                            let scaledWidth = max(100, placement.size.width)
                            let scaledHeight = max(50, placement.size.height)
                            let sigRect = CGRect(
                                x: screenPos.x - scaledWidth / 2,
                                y: screenPos.y - scaledHeight / 2,
                                width: scaledWidth,
                                height: scaledHeight
                            )
                            if sigRect.contains(tapPoint) {
                                tappedOnSignature = true
                                break
                            }
                        }

                        if !tappedOnSignature {
                            // Check if tap is within the PDF page area
                            if pdfRect.contains(value.location) {
                                // Normalize tap position relative to PDF page (not view)
                                let normalizedX = (value.location.x - pdfRect.minX) / pdfRect.width
                                let normalizedY = (value.location.y - pdfRect.minY) / pdfRect.height
                                let normalizedPoint = CGPoint(
                                    x: max(0.0, min(1.0, normalizedX)),
                                    y: max(0.0, min(1.0, normalizedY))
                                )
                                // Pass PDF display width for accurate size calculation
                                onTap(normalizedPoint, pdfRect.width)
                                HapticManager.shared.impact(.light)
                            }
                        }
                    }
            )
            .gesture(pageZoomGesture)
        }
    }
    
    // Page zoom gesture - only active when NO signature is selected
    // This prevents gesture conflicts between page zoom and signature resize
    private var pageZoomGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                // Only zoom page if no signature is selected
                guard selectedPlacement == nil else { return }
                let newScale = lastScale * value
                // Allow zoom from 2% (very small) to 500% (5x)
                scale = min(max(newScale, 0.02), 5.0)
            }
            .onEnded { value in
                // Only zoom page if no signature is selected
                guard selectedPlacement == nil else { return }
                let finalScale = lastScale * value
                scale = min(max(finalScale, 0.02), 5.0)
                lastScale = scale
                lastOffset = offset
            }
    }

    private func calculateInitialScale(viewSize: CGSize) {
        guard viewSize.width > 0 && viewSize.height > 0 else { return }
        guard pageBounds.width > 0 && pageBounds.height > 0 else { return }
        
        let pageSize = pageBounds.size
        
        // Calculate scale to fit page within view (with padding)
        let padding: CGFloat = 20 // Small padding around edges
        let availableWidth = max(1, viewSize.width - (padding * 2))
        let availableHeight = max(1, viewSize.height - (padding * 2))
        
        let scaleX = availableWidth / pageSize.width
        let scaleY = availableHeight / pageSize.height
        
        // Use the smaller scale to ensure page fits completely
        let fitScale = min(scaleX, scaleY)
        
        // Set initial scale (clamp to reasonable range - always fit, never zoom in)
        let initialScale = min(max(fitScale, 0.1), 1.0) // Allow zoom out if needed, but never zoom in
        scale = initialScale
        lastScale = initialScale
        initialFitScale = initialScale // Store for later comparison
        
        // Center the page (no offset needed when fitting)
        offset = .zero
        lastOffset = .zero
        
        print("🔵 InteractivePDFPageView: Calculated initial scale: \(initialScale) for page size: \(pageSize), view size: \(viewSize)")
    }
    
    private func normalizePoint(_ point: CGPoint, in size: CGSize) -> CGPoint {
        // Simplified: Convert screen tap point directly to normalized coordinates (0.0-1.0)
        // This matches the simplified coordinate system used in SignaturePlacementOverlay
        // No need to account for PDF scale/offset since we're using screen-relative coordinates
        
        let normalizedX = max(0.0, min(1.0, point.x / size.width))
        let normalizedY = max(0.0, min(1.0, point.y / size.height))
        
        return CGPoint(x: normalizedX, y: normalizedY)
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
        view.scale = scale
        view.offset = offset
        return view
    }
    
    func updateUIView(_ uiView: PDFPageView, context: Context) {
        // Only update if values actually changed to avoid unnecessary redraws
        if uiView.page !== page {
            uiView.page = page
        }
        if uiView.pageBounds != pageBounds {
            uiView.pageBounds = pageBounds
        }
        if uiView.scale != scale {
            uiView.scale = scale
        }
        if uiView.offset != offset {
            uiView.offset = offset
        }
        uiView.setNeedsDisplay()
    }
}

class PDFPageView: UIView {
    var page: PDFPage? {
        didSet {
            // Clear previous content when page changes
            if oldValue !== page {
                layer.contents = nil
            }
            setNeedsDisplay()
        }
    }
    
    var pageBounds: CGRect = .zero {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var scale: CGFloat = 1.0 {
        didSet {
            setNeedsDisplay()
        }
    }
    
    var offset: CGSize = .zero {
        didSet {
            setNeedsDisplay()
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard let page = page else {
            // Clear the view if no page
            UIColor.clear.setFill()
            UIRectFill(rect)
            return
        }
        
        // Clear the background first to prevent previous page showing through
        backgroundColor?.setFill()
        UIRectFill(rect)
        
        let context = UIGraphicsGetCurrentContext()!
        context.saveGState()
        
        // Calculate scaled page dimensions
        let scaledWidth = pageBounds.width * scale
        let scaledHeight = pageBounds.height * scale
        
        // Calculate the drawing rect (centered with offset)
        let drawRect = CGRect(
            x: offset.width + (bounds.width - scaledWidth) / 2,
            y: offset.height + (bounds.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
        
        // Set up coordinate system for PDF drawing
        // PDF coordinate system has origin at bottom-left, so we need to flip
        context.translateBy(x: drawRect.origin.x, y: drawRect.origin.y + drawRect.height)
        context.scaleBy(x: scale, y: -scale) // Negative Y to flip coordinate system
        
        // Draw the PDF page
        page.draw(with: .mediaBox, to: context)
        
        context.restoreGState()
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isOpaque = false
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
        isOpaque = false
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
    let pdfScale: CGFloat
    let pdfOffset: CGSize
    let isSelected: Bool
    let onTap: () -> Void
    let onUpdate: (SignaturePlacement) -> Void
    
    @State private var currentSize: CGSize
    @State private var currentPosition: CGPoint
    @State private var lastMagnification: CGFloat = 1.0
    @State private var dragOffset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    
    init(placement: SignaturePlacement, pageBounds: CGRect, geometry: GeometryProxy, pdfScale: CGFloat, pdfOffset: CGSize, isSelected: Bool, onTap: @escaping () -> Void, onUpdate: @escaping (SignaturePlacement) -> Void) {
        self.placement = placement
        self.pageBounds = pageBounds
        self.geometry = geometry
        self.pdfScale = pdfScale
        self.pdfOffset = pdfOffset
        self.isSelected = isSelected
        self.onTap = onTap
        self.onUpdate = onUpdate
        _currentSize = State(initialValue: placement.size)
        _currentPosition = State(initialValue: placement.position)
        _lastScale = State(initialValue: 1.0)
    }
    
    // Calculate the PDF page's display rectangle within the view
    private var pdfDisplayRect: CGRect {
        let scaledWidth = pageBounds.width * pdfScale
        let scaledHeight = pageBounds.height * pdfScale
        return CGRect(
            x: pdfOffset.width + (geometry.size.width - scaledWidth) / 2,
            y: pdfOffset.height + (geometry.size.height - scaledHeight) / 2,
            width: scaledWidth,
            height: scaledHeight
        )
    }

    var body: some View {
        // Calculate position relative to PDF page (not the entire view)
        let pdfRect = pdfDisplayRect
        let baseScreenPos = CGPoint(
            x: pdfRect.minX + (placement.position.x * pdfRect.width),
            y: pdfRect.minY + (placement.position.y * pdfRect.height)
        )
        let screenPos = CGPoint(
            x: baseScreenPos.x + dragOffset.width,
            y: baseScreenPos.y + dragOffset.height
        )

        // Signature size - use placement size directly (it's already in screen pixels)
        let baseWidth = currentSize.width
        let baseHeight = currentSize.height
        let scaledSignatureWidth = max(80, baseWidth)
        let scaledSignatureHeight = max(40, baseHeight)
        
        ZStack {
            if case .image(let data) = placement.signatureData {
                if let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .renderingMode(.original) // Preserve transparency
                        .aspectRatio(contentMode: .fit)
                        .frame(width: scaledSignatureWidth, height: scaledSignatureHeight)
                } else {
                    // Fallback if image fails to load
                    Rectangle()
                        .fill(Color.red.opacity(0.5))
                        .frame(width: scaledSignatureWidth, height: scaledSignatureHeight)
                        .overlay(
                            Text("Image Error")
                                .font(.caption)
                                .foregroundColor(.white)
                        )
                }
            } else if case .text(let text) = placement.signatureData {
                Text(text)
                    .font(UIFont(name: "Snell Roundhand", size: min(24, scaledSignatureHeight * 0.3)) != nil ? Font.custom("Snell Roundhand", size: min(24, scaledSignatureHeight * 0.3)) : Font.system(.body).italic())
                    .foregroundColor(.black)
                    .frame(width: scaledSignatureWidth, height: scaledSignatureHeight)
            } else {
                // Fallback for unknown signature type
                Rectangle()
                    .fill(Color.blue.opacity(0.5))
                    .frame(width: scaledSignatureWidth, height: scaledSignatureHeight)
                    .overlay(
                        Text("Signature")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
            
            // Selection indicator with resize handles
            if isSelected {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(OneBoxColors.primaryGold, lineWidth: 2)
                    .frame(width: scaledSignatureWidth + 10, height: scaledSignatureHeight + 10)

                // Resize handles (corners) - use offset instead of position
                // so handles appear relative to the signature center, not absolute on page
                ForEach(0..<4) { index in
                    Circle()
                        .fill(OneBoxColors.primaryGold)
                        .frame(width: 16, height: 16)
                        .offset(x: resizeHandleOffset(for: index, width: scaledSignatureWidth, height: scaledSignatureHeight).x,
                                y: resizeHandleOffset(for: index, width: scaledSignatureWidth, height: scaledSignatureHeight).y)
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
                        let pdfRect = pdfDisplayRect

                        // Calculate base position in PDF rect
                        let basePdfX = pdfRect.minX + (placement.position.x * pdfRect.width)
                        let basePdfY = pdfRect.minY + (placement.position.y * pdfRect.height)

                        // Calculate final screen position
                        let finalScreenX = basePdfX + value.translation.width
                        let finalScreenY = basePdfY + value.translation.height

                        // Convert back to normalized coordinates relative to PDF page
                        let newPosition = CGPoint(
                            x: max(0.0, min(1.0, (finalScreenX - pdfRect.minX) / pdfRect.width)),
                            y: max(0.0, min(1.0, (finalScreenY - pdfRect.minY) / pdfRect.height))
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
        .gesture(
            // Signature resize gesture (only works when signature is selected)
            // Use regular gesture (not simultaneous) so it takes priority when selected
            MagnificationGesture()
                .onChanged { value in
                    guard isSelected else { return }
                    // Calculate scale relative to current size for smoother interaction
                    let scale = value
                    let newWidth = placement.size.width * scale
                    let newHeight = placement.size.height * scale

                    // Clamp size - larger range for better usability
                    let minSize: CGFloat = 60
                    let maxSize: CGFloat = 600
                    currentSize = CGSize(
                        width: max(minSize, min(maxSize, newWidth)),
                        height: max(minSize, min(maxSize, newHeight))
                    )
                    // Haptic feedback during resize
                    if abs(scale - lastMagnification) > 0.1 {
                        HapticManager.shared.impact(.light)
                        lastMagnification = scale
                    }
                }
                .onEnded { finalValue in
                    guard isSelected else { return }
                    // Calculate final size based on original placement size
                    let finalWidth = placement.size.width * finalValue
                    let finalHeight = placement.size.height * finalValue

                    // Clamp and update
                    let minSize: CGFloat = 60
                    let maxSize: CGFloat = 600
                    let finalSize = CGSize(
                        width: max(minSize, min(maxSize, finalWidth)),
                        height: max(minSize, min(maxSize, finalHeight))
                    )

                    var updated = placement
                    updated.size = finalSize
                    onUpdate(updated)

                    // Update tracking variables
                    currentSize = finalSize
                    lastScale = finalValue
                    lastMagnification = 1.0
                    HapticManager.shared.impact(.medium)
                }
        )
    }
    
    // Calculate offset for resize handles relative to signature center
    private func resizeHandleOffset(for index: Int, width: CGFloat, height: CGFloat) -> CGPoint {
        let halfWidth = width / 2 + 5
        let halfHeight = height / 2 + 5

        switch index {
        case 0: return CGPoint(x: -halfWidth, y: -halfHeight) // Top-left
        case 1: return CGPoint(x: halfWidth, y: -halfHeight)  // Top-right
        case 2: return CGPoint(x: -halfWidth, y: halfHeight)  // Bottom-left
        case 3: return CGPoint(x: halfWidth, y: halfHeight)   // Bottom-right
        default: return .zero
        }
    }
}

