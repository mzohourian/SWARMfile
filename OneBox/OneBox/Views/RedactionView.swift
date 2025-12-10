//
//  RedactionView.swift
//  OneBox
//
//  Visual-first redaction with tap-to-remove and draw-to-add
//

import SwiftUI
import UIKit
import UIComponents
import JobEngine
import CommonTypes
import PDFKit
import Vision
import NaturalLanguage

struct RedactionView: View {
    let pdfURL: URL
    var workflowMode: Bool = false
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    @EnvironmentObject var paymentsManager: PaymentsManager

    // PDF state
    @State private var pdfDocument: PDFDocument?
    @State private var currentPageIndex = 0
    @State private var loadError: String?
    @State private var didStartAccessingSecurityScoped = false

    // Analysis state
    @State private var isAnalyzing = false
    @State private var analysisProgress: Double = 0
    @State private var ocrResults: [Int: [OCRTextBlock]] = [:]

    // Redaction boxes - the core data model
    @State private var redactionBoxes: [RedactionBox] = []

    // Drawing state for adding new boxes
    @State private var isDrawing = false
    @State private var drawStartPoint: CGPoint?
    @State private var currentDrawRect: CGRect?

    // Zoom state
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    private let minZoom: CGFloat = 1.0
    private let maxZoom: CGFloat = 5.0

    // Full-screen mode
    @State private var isFullScreen = false

    // Processing state
    @State private var isProcessing = false
    @State private var completedJob: Job?
    @State private var showingResult = false

    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()

                if let error = loadError {
                    loadErrorView(error)
                } else if isAnalyzing {
                    analysisView
                } else if pdfDocument != nil {
                    visualRedactionEditor
                } else {
                    ProgressView("Loading document...")
                        .tint(OneBoxColors.primaryGold)
                }
            }
            .navigationTitle("Redact Document")
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
        .sheet(isPresented: $showingResult, onDismiss: { dismiss() }) {
            if let job = completedJob {
                JobResultView(job: job)
            }
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            fullScreenEditor
        }
        .overlay {
            if isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            let securityAccess = pdfURL.startAccessingSecurityScopedResource()
            if securityAccess {
                didStartAccessingSecurityScoped = true
            }
            loadPDFDocument()
        }
        .onDisappear {
            if didStartAccessingSecurityScoped {
                pdfURL.stopAccessingSecurityScopedResource()
                didStartAccessingSecurityScoped = false
            }
        }
    }

    // MARK: - Analysis View
    private var analysisView: some View {
        VStack(spacing: OneBoxSpacing.large) {
            Spacer()

            VStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: "brain")
                    .font(.system(size: 48))
                    .foregroundColor(OneBoxColors.primaryGold)
                    .scaleEffect(isAnalyzing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isAnalyzing)

                Text("Analyzing Document")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)

                Text("Detecting sensitive information...")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)

                ProgressView(value: analysisProgress)
                    .progressViewStyle(.linear)
                    .tint(OneBoxColors.primaryGold)
                    .frame(width: 200)
            }

            Spacer()
        }
    }

    // MARK: - Visual Redaction Editor (Main View)
    private var visualRedactionEditor: some View {
        VStack(spacing: 0) {
            // Instructions header with zoom controls
            instructionsHeader

            // PDF page with redaction overlay
            GeometryReader { geometry in
                if let document = pdfDocument, let page = document.page(at: currentPageIndex) {
                    let pageBounds = page.bounds(for: .mediaBox)
                    let pageAspect = pageBounds.width / pageBounds.height
                    let availableWidth = geometry.size.width - 32
                    let availableHeight = geometry.size.height - 20
                    let baseHeight = min(availableWidth / pageAspect, availableHeight)
                    let baseWidth = baseHeight * pageAspect
                    let finalWidth = baseWidth * zoomScale
                    let finalHeight = baseHeight * zoomScale

                    ScrollView([.horizontal, .vertical], showsIndicators: true) {
                        ZStack(alignment: .topLeading) {
                            // PDF page rendering
                            RedactionPDFPageView(page: page)
                                .frame(width: finalWidth, height: finalHeight)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)

                            // Redaction boxes overlay
                            ForEach(boxesForCurrentPage()) { box in
                                redactionBoxView(box: box, pageSize: CGSize(width: finalWidth, height: finalHeight))
                            }

                            // Current drawing rectangle (while user is dragging)
                            if let drawRect = currentDrawRect {
                                Rectangle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: drawRect.width, height: drawRect.height)
                                    .position(x: drawRect.midX, y: drawRect.midY)
                                    .overlay(
                                        Rectangle()
                                            .stroke(OneBoxColors.primaryGold, lineWidth: 2)
                                            .frame(width: drawRect.width, height: drawRect.height)
                                            .position(x: drawRect.midX, y: drawRect.midY)
                                    )
                            }
                        }
                        .frame(width: finalWidth, height: finalHeight)
                        .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 10)
                                .onChanged { value in
                                    handleDrawStart(value.startLocation, in: CGSize(width: finalWidth, height: finalHeight))
                                    handleDrawUpdate(value.location, in: CGSize(width: finalWidth, height: finalHeight))
                                }
                                .onEnded { value in
                                    handleDrawEnd(in: CGSize(width: finalWidth, height: finalHeight))
                                }
                        )
                        .simultaneousGesture(
                            MagnificationGesture()
                                .onChanged { value in
                                    let newScale = lastZoomScale * value
                                    zoomScale = min(max(newScale, minZoom), maxZoom)
                                }
                                .onEnded { value in
                                    lastZoomScale = zoomScale
                                    HapticManager.shared.selection()
                                }
                        )
                    }
                }
            }

            // Page navigation
            if let document = pdfDocument, document.pageCount > 1 {
                pageNavigationBar(totalPages: document.pageCount)
            }

            // Bottom action bar
            actionBar
        }
    }

    // MARK: - Instructions Header
    private var instructionsHeader: some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            HStack(spacing: OneBoxSpacing.medium) {
                // Tap hint
                HStack(spacing: 4) {
                    Image(systemName: "hand.tap.fill")
                        .font(.system(size: 12))
                    Text("Double-tap to remove")
                        .font(OneBoxTypography.micro)
                }
                .foregroundColor(OneBoxColors.secondaryText)

                Divider()
                    .frame(height: 12)

                // Draw hint
                HStack(spacing: 4) {
                    Image(systemName: "rectangle.badge.plus")
                        .font(.system(size: 12))
                    Text("Draw to add")
                        .font(OneBoxTypography.micro)
                }
                .foregroundColor(OneBoxColors.secondaryText)

                Divider()
                    .frame(height: 12)

                // Pinch hint
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12))
                    Text("Pinch to zoom")
                        .font(OneBoxTypography.micro)
                }
                .foregroundColor(OneBoxColors.secondaryText)
            }
            .padding(.vertical, OneBoxSpacing.small)

            // Zoom controls, full-screen button, and stats
            HStack {
                // Zoom controls
                HStack(spacing: OneBoxSpacing.small) {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomScale = max(zoomScale - 0.5, minZoom)
                            lastZoomScale = zoomScale
                        }
                        HapticManager.shared.selection()
                    }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(zoomScale > minZoom ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                    }
                    .disabled(zoomScale <= minZoom)

                    Text("\(Int(zoomScale * 100))%")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .frame(width: 40)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            zoomScale = min(zoomScale + 0.5, maxZoom)
                            lastZoomScale = zoomScale
                        }
                        HapticManager.shared.selection()
                    }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 16))
                            .foregroundColor(zoomScale < maxZoom ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                    }
                    .disabled(zoomScale >= maxZoom)

                    // Full-screen button
                    Button(action: {
                        isFullScreen = true
                        HapticManager.shared.selection()
                    }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 16))
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }

                Spacer()

                // Stats
                let selectedCount = redactionBoxes.filter { $0.isSelected }.count
                let totalCount = redactionBoxes.count
                if totalCount > 0 {
                    Text("\(selectedCount) of \(totalCount) items")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryGold)
                } else {
                    Text("No sensitive data found")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.tertiaryText)
                }
            }
        }
        .padding(.horizontal, OneBoxSpacing.medium)
        .padding(.top, OneBoxSpacing.small)
    }

    // MARK: - Redaction Box View
    private func redactionBoxView(box: RedactionBox, pageSize: CGSize) -> some View {
        // Convert normalized coordinates to view coordinates
        let x = box.normalizedRect.minX * pageSize.width
        let y = (1.0 - box.normalizedRect.maxY) * pageSize.height
        let width = box.normalizedRect.width * pageSize.width
        let height = box.normalizedRect.height * pageSize.height

        return Group {
            if box.isSelected {
                // Selected = will be redacted (solid black)
                Rectangle()
                    .fill(Color.black)
                    .frame(width: max(width, 20), height: max(height, 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(OneBoxColors.primaryGold, lineWidth: 2)
                    )
            } else {
                // Deselected = won't be redacted (gray outline)
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
                    .frame(width: max(width, 20), height: max(height, 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Color.gray, style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                    )
            }
        }
        .position(x: x + width/2, y: y + height/2)
        .onTapGesture(count: 2) {
            // Double-tap to toggle - prevents accidental toggles while scrolling/zooming
            toggleBox(box)
        }
    }

    // MARK: - Page Navigation
    private func pageNavigationBar(totalPages: Int) -> some View {
        HStack {
            Button(action: {
                if currentPageIndex > 0 {
                    currentPageIndex -= 1
                    // Reset zoom when changing pages
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                    HapticManager.shared.selection()
                }
            }) {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(currentPageIndex > 0 ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
            }
            .disabled(currentPageIndex == 0)

            Spacer()

            Text("Page \(currentPageIndex + 1) of \(totalPages)")
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryText)

            Spacer()

            Button(action: {
                if currentPageIndex < totalPages - 1 {
                    currentPageIndex += 1
                    // Reset zoom when changing pages
                    zoomScale = 1.0
                    lastZoomScale = 1.0
                    HapticManager.shared.selection()
                }
            }) {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(currentPageIndex < totalPages - 1 ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
            }
            .disabled(currentPageIndex >= totalPages - 1)
        }
        .padding(.horizontal, OneBoxSpacing.large)
        .padding(.vertical, OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite)
    }

    // MARK: - Action Bar
    private var actionBar: some View {
        let selectedCount = redactionBoxes.filter { $0.isSelected }.count

        return VStack(spacing: OneBoxSpacing.small) {
            Divider()

            HStack(spacing: OneBoxSpacing.medium) {
                // Select All / Deselect All
                Button(action: {
                    let allSelected = redactionBoxes.allSatisfy { $0.isSelected }
                    for i in redactionBoxes.indices {
                        redactionBoxes[i].isSelected = !allSelected
                    }
                    HapticManager.shared.selection()
                }) {
                    let allSelected = redactionBoxes.allSatisfy { $0.isSelected }
                    Text(allSelected ? "Deselect All" : "Select All")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }

                Spacer()

                // Apply button
                Button(action: {
                    applyRedactions()
                }) {
                    HStack(spacing: OneBoxSpacing.small) {
                        Image(systemName: "checkmark.shield.fill")
                        Text(workflowMode ? "Proceed" : "Apply \(selectedCount) Redactions")
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(selectedCount > 0 ? OneBoxColors.primaryGraphite : OneBoxColors.tertiaryText)
                    .padding(.horizontal, OneBoxSpacing.medium)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(selectedCount > 0 ? OneBoxColors.primaryGold : OneBoxColors.surfaceGraphite)
                    .cornerRadius(OneBoxRadius.medium)
                }
                .disabled(selectedCount == 0)
            }
            .padding(.horizontal, OneBoxSpacing.medium)
            .padding(.bottom, OneBoxSpacing.medium)
        }
        .background(OneBoxColors.primaryGraphite)
    }

    // MARK: - Processing Overlay
    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()

            VStack(spacing: OneBoxSpacing.medium) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: OneBoxColors.primaryGold))
                    .scaleEffect(1.5)

                Text("Applying Redactions...")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)

                Text("Permanently removing sensitive data")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            .padding(OneBoxSpacing.large)
            .background(OneBoxColors.surfaceGraphite)
            .cornerRadius(OneBoxRadius.large)
        }
    }

    // MARK: - Full-Screen Editor
    @State private var fullScreenZoom: CGFloat = 1.0
    @State private var fullScreenLastZoom: CGFloat = 1.0

    private var fullScreenEditor: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar with close button and page info
                HStack {
                    Button(action: {
                        isFullScreen = false
                        HapticManager.shared.selection()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white.opacity(0.8))
                    }

                    Spacer()

                    if let document = pdfDocument {
                        Text("Page \(currentPageIndex + 1) of \(document.pageCount)")
                            .font(OneBoxTypography.body)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Zoom indicator
                    Text("\(Int(fullScreenZoom * 100))%")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 50)
                }
                .padding(.horizontal, OneBoxSpacing.medium)
                .padding(.top, OneBoxSpacing.small)

                // Full-screen page view
                GeometryReader { geometry in
                    if let document = pdfDocument, let page = document.page(at: currentPageIndex) {
                        let pageBounds = page.bounds(for: .mediaBox)
                        let pageAspect = pageBounds.width / pageBounds.height

                        // Use full available space - calculate base dimensions
                        let availableWidth = geometry.size.width
                        let availableHeight = geometry.size.height
                        let isHeightConstrained = availableWidth / availableHeight > pageAspect
                        let baseHeight = isHeightConstrained ? availableHeight : (availableWidth / pageAspect)
                        let baseWidth = isHeightConstrained ? (baseHeight * pageAspect) : availableWidth

                        let finalWidth = baseWidth * fullScreenZoom
                        let finalHeight = baseHeight * fullScreenZoom

                        ScrollView([.horizontal, .vertical], showsIndicators: false) {
                            ZStack(alignment: .topLeading) {
                                // PDF page rendering
                                RedactionPDFPageView(page: page)
                                    .frame(width: finalWidth, height: finalHeight)
                                    .background(Color.white)

                                // Redaction boxes overlay
                                ForEach(boxesForCurrentPage()) { box in
                                    redactionBoxView(box: box, pageSize: CGSize(width: finalWidth, height: finalHeight))
                                }

                                // Current drawing rectangle
                                if let drawRect = currentDrawRect {
                                    Rectangle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: drawRect.width, height: drawRect.height)
                                        .position(x: drawRect.midX, y: drawRect.midY)
                                        .overlay(
                                            Rectangle()
                                                .stroke(OneBoxColors.primaryGold, lineWidth: 2)
                                                .frame(width: drawRect.width, height: drawRect.height)
                                                .position(x: drawRect.midX, y: drawRect.midY)
                                        )
                                }
                            }
                            .frame(width: finalWidth, height: finalHeight)
                            .frame(minWidth: geometry.size.width, minHeight: geometry.size.height)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 10)
                                    .onChanged { value in
                                        handleDrawStart(value.startLocation, in: CGSize(width: finalWidth, height: finalHeight))
                                        handleDrawUpdate(value.location, in: CGSize(width: finalWidth, height: finalHeight))
                                    }
                                    .onEnded { value in
                                        handleDrawEnd(in: CGSize(width: finalWidth, height: finalHeight))
                                    }
                            )
                            .simultaneousGesture(
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = fullScreenLastZoom * value
                                        fullScreenZoom = min(max(newScale, 1.0), 5.0)
                                    }
                                    .onEnded { value in
                                        fullScreenLastZoom = fullScreenZoom
                                        HapticManager.shared.selection()
                                    }
                            )
                        }
                    }
                }

                // Bottom controls
                HStack(spacing: OneBoxSpacing.large) {
                    // Previous page
                    Button(action: {
                        if currentPageIndex > 0 {
                            currentPageIndex -= 1
                            fullScreenZoom = 1.0
                            fullScreenLastZoom = 1.0
                            HapticManager.shared.selection()
                        }
                    }) {
                        Image(systemName: "chevron.left.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(currentPageIndex > 0 ? .white : .white.opacity(0.3))
                    }
                    .disabled(currentPageIndex == 0)

                    Spacer()

                    // Stats
                    let selectedCount = redactionBoxes.filter { $0.isSelected }.count
                    VStack(spacing: 2) {
                        Text("\(selectedCount) redactions")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryGold)
                        Text("Double-tap boxes to toggle")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(.white.opacity(0.5))
                    }

                    Spacer()

                    // Next page
                    Button(action: {
                        if let document = pdfDocument, currentPageIndex < document.pageCount - 1 {
                            currentPageIndex += 1
                            fullScreenZoom = 1.0
                            fullScreenLastZoom = 1.0
                            HapticManager.shared.selection()
                        }
                    }) {
                        Image(systemName: "chevron.right.circle.fill")
                            .font(.system(size: 36))
                            .foregroundColor(pdfDocument.map { currentPageIndex < $0.pageCount - 1 } ?? false ? .white : .white.opacity(0.3))
                    }
                    .disabled(pdfDocument.map { currentPageIndex >= $0.pageCount - 1 } ?? true)
                }
                .padding(.horizontal, OneBoxSpacing.large)
                .padding(.vertical, OneBoxSpacing.medium)
                .background(Color.black.opacity(0.8))
            }
        }
    }

    // MARK: - Load Error View
    private func loadErrorView(_ error: String) -> some View {
        VStack(spacing: OneBoxSpacing.large) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(OneBoxColors.warningAmber)

            Text("Unable to Load Document")
                .font(OneBoxTypography.sectionTitle)
                .foregroundColor(OneBoxColors.primaryText)

            Text(error)
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, OneBoxSpacing.large)

            Button("Try Again") {
                loadError = nil
                loadPDFDocument()
            }
            .foregroundColor(OneBoxColors.primaryGold)

            Spacer()
        }
    }

    // MARK: - Helper Functions

    private func boxesForCurrentPage() -> [RedactionBox] {
        redactionBoxes.filter { $0.pageIndex == currentPageIndex }
    }

    private func toggleBox(_ box: RedactionBox) {
        if let index = redactionBoxes.firstIndex(where: { $0.id == box.id }) {
            redactionBoxes[index].isSelected.toggle()
            HapticManager.shared.selection()
        }
    }

    // MARK: - Drawing Handlers

    private func handleDrawStart(_ point: CGPoint, in pageSize: CGSize) {
        drawStartPoint = point
        isDrawing = true
    }

    private func handleDrawUpdate(_ point: CGPoint, in pageSize: CGSize) {
        guard let start = drawStartPoint else { return }

        let minX = min(start.x, point.x)
        let minY = min(start.y, point.y)
        let width = abs(point.x - start.x)
        let height = abs(point.y - start.y)

        currentDrawRect = CGRect(x: minX, y: minY, width: width, height: height)
    }

    private func handleDrawEnd(in pageSize: CGSize) {
        guard let rect = currentDrawRect, rect.width > 10, rect.height > 5 else {
            drawStartPoint = nil
            currentDrawRect = nil
            isDrawing = false
            return
        }

        // Convert view coordinates to normalized coordinates
        let normalizedX = rect.minX / pageSize.width
        let normalizedY = 1.0 - (rect.maxY / pageSize.height)
        let normalizedWidth = rect.width / pageSize.width
        let normalizedHeight = rect.height / pageSize.height

        let normalizedRect = CGRect(
            x: normalizedX,
            y: normalizedY,
            width: normalizedWidth,
            height: normalizedHeight
        )

        let newBox = RedactionBox(
            pageIndex: currentPageIndex,
            normalizedRect: normalizedRect,
            source: .manual,
            detectedText: nil,
            isSelected: true
        )

        redactionBoxes.append(newBox)
        HapticManager.shared.impact(.medium)

        drawStartPoint = nil
        currentDrawRect = nil
        isDrawing = false
    }

    // MARK: - PDF Loading

    private func loadPDFDocument(retryCount: Int = 0) {
        if !FileManager.default.fileExists(atPath: pdfURL.path) {
            if retryCount < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadPDFDocument(retryCount: retryCount + 1)
                }
                return
            }
            loadError = "Could not find the PDF file."
            return
        }

        if let document = PDFDocument(url: pdfURL) {
            pdfDocument = document
            loadError = nil
            performSensitiveDataAnalysis()
        } else {
            if retryCount < 3 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.loadPDFDocument(retryCount: retryCount + 1)
                }
                return
            }
            loadError = "Could not open the PDF file."
        }
    }

    // MARK: - Sensitive Data Analysis

    private func performSensitiveDataAnalysis() {
        guard let document = pdfDocument else { return }

        isAnalyzing = true
        analysisProgress = 0
        redactionBoxes = []

        Task(priority: .userInitiated) {
            var detectedBoxes: [RedactionBox] = []
            var allOcrResults: [Int: [OCRTextBlock]] = [:]
            let pageCount = document.pageCount

            for pageIndex in 0..<pageCount {
                if Task.isCancelled { break }

                let (pageBoxes, pageOcrBlocks): ([RedactionBox], [OCRTextBlock]) = await withCheckedContinuation { continuation in
                    autoreleasepool {
                        guard let page = document.page(at: pageIndex) else {
                            continuation.resume(returning: ([], []))
                            return
                        }

                        // ALWAYS run OCR to get bounding boxes - this is essential for redaction
                        // Even PDFs with embedded text need OCR for visual bounding box locations
                        let (ocrText, textBlocks) = performOCRAndGetBlocks(on: page, pageIndex: pageIndex)

                        // IMPORTANT: Use OCR text for pattern matching since bounding boxes come from OCR
                        // Using embedded text would cause mismatches - detected text won't be found in OCR blocks
                        if let text = ocrText, !text.isEmpty {
                            let items = detectSensitiveDataWithBlocks(in: text, pageNumber: pageIndex, textBlocks: textBlocks)
                            continuation.resume(returning: (items, textBlocks))
                        } else {
                            continuation.resume(returning: ([], textBlocks))
                        }
                    }
                }

                detectedBoxes.append(contentsOf: pageBoxes)
                if !pageOcrBlocks.isEmpty {
                    allOcrResults[pageIndex] = pageOcrBlocks
                }

                await MainActor.run {
                    analysisProgress = Double(pageIndex + 1) / Double(pageCount)
                }

                try? await Task.sleep(nanoseconds: 10_000_000)
            }

            await MainActor.run {
                self.ocrResults = allOcrResults
                self.redactionBoxes = detectedBoxes
                self.isAnalyzing = false
                self.analysisProgress = 1.0
            }
        }
    }

    /// Performs OCR and returns both the recognized text and text blocks with bounding boxes
    private func performOCRAndGetBlocks(on page: PDFPage, pageIndex: Int) -> (String?, [OCRTextBlock]) {
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 2.0 // Higher resolution for better detection
        let maxDimension: CGFloat = 2500
        var finalScale = scale
        let imageSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        if imageSize.width > maxDimension || imageSize.height > maxDimension {
            finalScale = min(maxDimension / pageRect.width, maxDimension / pageRect.height)
        }
        let finalSize = CGSize(width: pageRect.width * finalScale, height: pageRect.height * finalScale)

        let renderer = UIGraphicsImageRenderer(size: finalSize)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: finalSize))
            context.cgContext.translateBy(x: 0, y: finalSize.height)
            context.cgContext.scaleBy(x: finalScale, y: -finalScale)
            page.draw(with: .mediaBox, to: context.cgContext)
        }

        guard let cgImage = image.cgImage else { return (nil, []) }

        var recognizedText: String?
        var textBlocks: [OCRTextBlock] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, _ in
            defer { semaphore.signal() }

            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }

            var allText: [String] = []
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    allText.append(candidate.string)
                    textBlocks.append(OCRTextBlock(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        pageIndex: pageIndex,
                        recognizedText: candidate
                    ))
                }
            }
            recognizedText = allText.joined(separator: " ")
        }

        request.recognitionLevel = .accurate // More accurate for better bounding boxes
        request.usesLanguageCorrection = true
        // Support multiple languages for international documents
        request.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "ar-SA", "fa-IR"]

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            _ = semaphore.wait(timeout: .now() + 10.0)
        } catch { }

        return (recognizedText?.isEmpty == true ? nil : recognizedText, textBlocks)
    }

    private func detectSensitiveDataWithBlocks(in text: String, pageNumber: Int, textBlocks: [OCRTextBlock]) -> [RedactionBox] {
        var boxes: [RedactionBox] = []

        // Patterns to detect sensitive data
        let patterns: [(String, String)] = [
            (#"(?:\d{3}-?\d{2}-?\d{4}|\d{9})"#, "SSN"),
            (#"(?:\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4})"#, "Credit Card"),
            (#"(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#, "Phone"),
            (#"\+\d{1,3}[-.\s]+\d{2,4}[-.\s]+\d{6,8}"#, "Phone (International)"),
            (#"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#, "Email"),
            (#"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#, "Date"),
            (#"\b[A-Z]{1,2}\d{6,9}\b"#, "Passport"),
            (#"[۰-۹]{8,9}"#, "Passport (Persian)"),
        ]

        // Check each block for sensitive data and get PRECISE bounding boxes
        for block in textBlocks {
            let blockText = block.text

            for (pattern, _) in patterns {
                do {
                    let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
                    let fullRange = NSRange(location: 0, length: blockText.utf16.count)

                    // Find ALL matches in this block (there could be multiple)
                    let matches = regex.matches(in: blockText, options: [], range: fullRange)

                    for match in matches {
                        guard let swiftRange = Range(match.range, in: blockText) else { continue }
                        let matchedText = String(blockText[swiftRange])

                        // Try to get PRECISE bounding box for just the matched text
                        var boundingRect: CGRect? = nil

                        if let recognizedText = block.recognizedText {
                            // Use Vision's character-level bounding box
                            do {
                                if let preciseBox = try recognizedText.boundingBox(for: swiftRange) {
                                    boundingRect = preciseBox.boundingBox
                                }
                            } catch {
                                // Fall back to approximation
                            }
                        }

                        // If precise box failed, approximate based on position in text
                        if boundingRect == nil {
                            let startIndex = blockText.distance(from: blockText.startIndex, to: swiftRange.lowerBound)
                            let matchLength = matchedText.count
                            let totalLength = blockText.count

                            if totalLength > 0 {
                                let startRatio = CGFloat(startIndex) / CGFloat(totalLength)
                                let widthRatio = CGFloat(matchLength) / CGFloat(totalLength)

                                boundingRect = CGRect(
                                    x: block.boundingBox.origin.x + block.boundingBox.width * startRatio,
                                    y: block.boundingBox.origin.y,
                                    width: block.boundingBox.width * widthRatio,
                                    height: block.boundingBox.height
                                )
                            }
                        }

                        // Add the box with precise or approximated bounds
                        if let rect = boundingRect {
                            boxes.append(RedactionBox(
                                pageIndex: pageNumber,
                                normalizedRect: rect,
                                source: .automatic,
                                detectedText: matchedText,
                                isSelected: true
                            ))
                        }
                    }
                } catch { }
            }
        }

        return boxes
    }

    // findBoundingBox is no longer needed - kept for potential future use
    private func findBoundingBox(for text: String, in textBlocks: [OCRTextBlock]) -> CGRect? {
        let textLower = text.lowercased()

        for block in textBlocks {
            let blockTextLower = block.text.lowercased()

            if let matchRange = blockTextLower.range(of: textLower) {
                // Try to get precise bounding box
                if let recognizedText = block.recognizedText {
                    let startDistance = blockTextLower.distance(from: blockTextLower.startIndex, to: matchRange.lowerBound)
                    let endDistance = blockTextLower.distance(from: blockTextLower.startIndex, to: matchRange.upperBound)
                    let originalStart = block.text.index(block.text.startIndex, offsetBy: startDistance)
                    let originalEnd = block.text.index(block.text.startIndex, offsetBy: endDistance)
                    let originalRange = originalStart..<originalEnd

                    do {
                        if let preciseBoundingBox = try recognizedText.boundingBox(for: originalRange) {
                            return preciseBoundingBox.boundingBox
                        }
                    } catch { }
                }

                // Fallback: use full block bounding box with approximation
                let matchLength = text.count
                let blockLength = block.text.count
                let startDistance = blockTextLower.distance(from: blockTextLower.startIndex, to: matchRange.lowerBound)
                let startRatio = Double(startDistance) / Double(max(blockLength, 1))
                let lengthRatio = Double(matchLength) / Double(max(blockLength, 1))

                return CGRect(
                    x: block.boundingBox.origin.x + (block.boundingBox.width * startRatio),
                    y: block.boundingBox.origin.y,
                    width: block.boundingBox.width * lengthRatio,
                    height: block.boundingBox.height
                )
            }
        }

        return nil
    }

    // MARK: - Apply Redactions

    private func applyRedactions() {
        let selectedBoxes = redactionBoxes.filter { $0.isSelected }
        guard !selectedBoxes.isEmpty, let document = pdfDocument else { return }

        isProcessing = true
        HapticManager.shared.impact(.medium)

        Task {
            do {
                let outputURL = try await createRedactedPDF(from: document, boxes: selectedBoxes)

                let persistedURL = saveOutputToDocuments(outputURL)
                let finalURL = persistedURL ?? outputURL

                var settings = JobSettings()
                settings.redactionItems = selectedBoxes.compactMap { $0.detectedText }

                let job = Job(
                    type: .pdfRedact,
                    inputs: [pdfURL],
                    settings: settings,
                    status: .success,
                    outputURLs: [finalURL],
                    completedAt: Date()
                )

                await jobManager.submitJob(job)

                await MainActor.run {
                    paymentsManager.consumeExport()
                    completedJob = job
                    isProcessing = false
                    HapticManager.shared.notification(.success)

                    if workflowMode {
                        dismiss()
                    } else {
                        showingResult = true
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    private func createRedactedPDF(from document: PDFDocument, boxes: [RedactionBox]) async throws -> URL {
        let pageCount = document.pageCount
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("redacted_\(UUID().uuidString).pdf")

        guard UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, nil) else {
            throw NSError(domain: "RedactionView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }

        for pageIndex in 0..<pageCount {
            autoreleasepool {
                guard let page = document.page(at: pageIndex) else { return }

                let pageBounds = page.bounds(for: .mediaBox)
                let pageBoxes = boxes.filter { $0.pageIndex == pageIndex }

                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

                if let pdfContext = UIGraphicsGetCurrentContext() {
                    pdfContext.saveGState()
                    pdfContext.translateBy(x: 0, y: pageBounds.height)
                    pdfContext.scaleBy(x: 1.0, y: -1.0)
                    page.draw(with: .mediaBox, to: pdfContext)
                    pdfContext.restoreGState()

                    // Draw redaction boxes
                    pdfContext.setFillColor(UIColor.black.cgColor)

                    for box in pageBoxes {
                        let x = box.normalizedRect.origin.x * pageBounds.width
                        let y = pageBounds.height * (1.0 - box.normalizedRect.origin.y - box.normalizedRect.height)
                        let width = box.normalizedRect.width * pageBounds.width
                        let height = box.normalizedRect.height * pageBounds.height

                        let padding: CGFloat = 3
                        let rect = CGRect(
                            x: x - padding,
                            y: y - padding,
                            width: width + padding * 2,
                            height: height + padding * 2
                        )
                        pdfContext.fill(rect)
                    }
                }
            }
        }

        UIGraphicsEndPDFContext()

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw NSError(domain: "RedactionView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create redacted PDF"])
        }

        return outputURL
    }

    private func saveOutputToDocuments(_ tempURL: URL?) -> URL? {
        guard let tempURL = tempURL else { return nil }

        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return tempURL
        }

        let exportsURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)

        if !fileManager.fileExists(atPath: exportsURL.path) {
            try? fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M-d-yy_h-mm_a"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "redacted_pdf_\(timestamp).pdf"
        let destinationURL = exportsURL.appendingPathComponent(filename)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: tempURL, to: destinationURL)
            return destinationURL
        } catch {
            return tempURL
        }
    }
}

// MARK: - Data Models

struct RedactionBox: Identifiable {
    let id = UUID()
    let pageIndex: Int
    let normalizedRect: CGRect // Vision-style normalized coords (0-1, origin bottom-left)
    let source: RedactionSource
    let detectedText: String?
    var isSelected: Bool

    enum RedactionSource {
        case automatic
        case manual
    }
}

struct OCRTextBlock {
    let text: String
    let boundingBox: CGRect
    let pageIndex: Int
    let recognizedText: VNRecognizedText?
}

// MARK: - PDF Page Rendering View

struct RedactionPDFPageView: UIViewRepresentable {
    let page: PDFPage

    func makeUIView(context: Context) -> RedactionPDFRenderView {
        let view = RedactionPDFRenderView()
        view.page = page
        view.backgroundColor = .white
        return view
    }

    func updateUIView(_ uiView: RedactionPDFRenderView, context: Context) {
        uiView.page = page
        uiView.setNeedsDisplay()
    }
}

class RedactionPDFRenderView: UIView {
    var page: PDFPage?

    override func draw(_ rect: CGRect) {
        guard let page = page, let context = UIGraphicsGetCurrentContext() else { return }

        UIColor.white.setFill()
        context.fill(rect)

        let pageBounds = page.bounds(for: .mediaBox)
        let scaleX = rect.width / pageBounds.width
        let scaleY = rect.height / pageBounds.height
        let scale = min(scaleX, scaleY)

        context.saveGState()
        context.translateBy(x: 0, y: rect.height)
        context.scaleBy(x: scale, y: -scale)
        page.draw(with: .mediaBox, to: context)
        context.restoreGState()
    }
}

#Preview {
    RedactionView(pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
}
