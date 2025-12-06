//
//  RedactionView.swift
//  OneBox
//
//  Advanced redaction and sensitive data detection for OneBox Standard
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
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    @EnvironmentObject var paymentsManager: PaymentsManager

    @State private var redactionItems: [RedactionItem] = []

    init(pdfURL: URL) {
        self.pdfURL = pdfURL
        print("🟢 RedactionView: init called with URL: \(pdfURL.absoluteString)")
        print("🟢 RedactionView: File exists at init: \(FileManager.default.fileExists(atPath: pdfURL.path))")
    }

    @State private var isAnalyzing = false
    @State private var analysisProgress: Double = 0
    @State private var selectedPage = 0
    @State private var pdfDocument: PDFDocument?
    @State private var showingRedactionPreview = false
    @State private var customRedactionText = ""
    @State private var selectedPreset: RedactionPreset?
    @State private var showingPresetPicker = false
    @State private var isProcessing = false
    @State private var completedJob: Job?
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var didStartAccessingSecurityScoped = false
    @State private var loadError: String?
    // Store OCR results with bounding boxes for accurate redaction
    @State private var ocrResults: [Int: [OCRTextBlock]] = [:] // pageIndex -> text blocks
    
    var body: some View {
        let _ = print("🟢 RedactionView: body is being evaluated")
        NavigationStack {
            VStack(spacing: 0) {
                // Show error if PDF couldn't be loaded
                if let error = loadError {
                    loadErrorView(error)
                } else {
                    // Header with mode selection
                    headerSection

                    // Main content based on analysis state
                    if isAnalyzing {
                        analysisProgressView
                    } else if redactionItems.isEmpty && !isAnalyzing {
                        noDataDetectedView
                    } else {
                        redactionContentView
                    }
                }
            }
            .navigationTitle("Document Redaction")
            .navigationBarTitleDisplayMode(.inline)
            .background(OneBoxColors.primaryGraphite)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyRedactions()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(redactionItems.filter { $0.isSelected }.isEmpty || isProcessing)
                }
            }
        }
        .sheet(isPresented: $showingRedactionPreview) {
            RedactionPreviewView(
                pdfURL: pdfURL,
                redactionItems: redactionItems.filter { $0.isSelected }
            )
        }
        .sheet(isPresented: $showingResult, onDismiss: {
            // Dismiss RedactionView after result is shown
            dismiss()
        }) {
            if let job = completedJob {
                JobResultView(job: job)
            }
        }
        .overlay {
            if isProcessing {
                processingOverlay
            }
        }
        .onAppear {
            print("🟢 RedactionView: onAppear called")
            // Start security-scoped access for files from document picker
            let securityAccess = pdfURL.startAccessingSecurityScopedResource()
            print("🟢 RedactionView: startAccessingSecurityScopedResource returned: \(securityAccess)")
            if securityAccess {
                didStartAccessingSecurityScoped = true
                print("🟢 RedactionView: Started security-scoped resource access")
            }
            loadPDFDocument()
            performSensitiveDataAnalysis()
        }
        .onDisappear {
            // Stop security-scoped access when view disappears
            if didStartAccessingSecurityScoped {
                pdfURL.stopAccessingSecurityScopedResource()
                didStartAccessingSecurityScoped = false
                print("RedactionView: Stopped security-scoped resource access")
            }
        }
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
    
    // MARK: - Header Section
    private var headerSection: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(OneBoxColors.primaryGold)

                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Sensitive Data Protection")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)

                        Text("Review detected items, then tap Apply")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }

                    Spacer()
                }

                // Preset Selection for quick filtering
                HStack {
                    Text("Filter by type:")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: OneBoxSpacing.small) {
                            ForEach(RedactionPreset.allCases) { preset in
                                presetButtonView(preset)
                            }
                        }
                    }
                }
            }
        }
        .padding(OneBoxSpacing.medium)
    }
    
    // MARK: - Analysis Progress View
    private var analysisProgressView: some View {
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
                
                Text("Scanning for sensitive information...")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                ProgressView(value: analysisProgress)
                    .progressViewStyle(.linear)
                    .tint(OneBoxColors.primaryGold)
                    .frame(width: 200)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - No Data Detected View
    private var noDataDetectedView: some View {
        VStack(spacing: OneBoxSpacing.large) {
            Spacer()
            
            VStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 48))
                    .foregroundColor(OneBoxColors.secureGreen)
                
                Text("No Sensitive Data Detected")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Your document appears to be free of common sensitive information patterns.")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, OneBoxSpacing.large)

                Button("Add Manual Redaction") {
                    addManualRedaction()
                }
                .foregroundColor(OneBoxColors.primaryGold)
                .padding(.top, OneBoxSpacing.medium)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Redaction Content View
    private var redactionContentView: some View {
        VStack(spacing: 0) {
            // Statistics header
            redactionStatsHeader
            
            // Redaction items list
            ScrollView {
                LazyVStack(spacing: OneBoxSpacing.small) {
                    ForEach(redactionItems) { item in
                        redactionItemRow(item)
                    }

                    // Always show manual add option
                    addCustomRedactionButton
                }
                .padding(OneBoxSpacing.medium)
            }
        }
    }
    
    private var redactionStatsHeader: some View {
        OneBoxCard(style: .standard) {
            HStack(spacing: OneBoxSpacing.large) {
                statItem("Detected", "\(redactionItems.count)", OneBoxColors.warningAmber)
                statItem("Selected", "\(redactionItems.filter { $0.isSelected }.count)", OneBoxColors.primaryGold)
                statItem("Categories", "\(Set(redactionItems.map { $0.category }).count)", OneBoxColors.secureGreen)
            }
        }
        .padding(.horizontal, OneBoxSpacing.medium)
    }
    
    private func statItem(_ title: String, _ value: String, _ color: Color) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Text(value)
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(color)
            
            Text(title)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    private func presetButtonView(_ preset: RedactionPreset) -> some View {
        Button(action: {
            selectedPreset = preset
            applyPreset(preset)
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: preset.icon)
                    .font(.system(size: 12))
                
                Text(preset.displayName)
                    .font(OneBoxTypography.caption)
            }
            .foregroundColor(selectedPreset == preset ? OneBoxColors.primaryGold : OneBoxColors.secondaryText)
            .padding(.horizontal, OneBoxSpacing.small)
            .padding(.vertical, OneBoxSpacing.tiny)
            .background(
                RoundedRectangle(cornerRadius: OneBoxRadius.small)
                    .fill(selectedPreset == preset ? OneBoxColors.primaryGold.opacity(0.2) : OneBoxColors.surfaceGraphite.opacity(0.3))
            )
        }
    }
    
    private func applyPreset(_ preset: RedactionPreset) {
        // Apply preset categories to redaction items
        for index in redactionItems.indices {
            if preset.categories.contains(redactionItems[index].category) {
                redactionItems[index].isSelected = true
            }
        }
    }
    
    private func redactionItemRow(_ item: RedactionItem) -> some View {
        OneBoxCard(style: .interactive) {
            HStack(spacing: OneBoxSpacing.medium) {
                // Selection toggle
                Button(action: {
                    toggleRedactionSelection(item)
                }) {
                    Image(systemName: item.isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(item.isSelected ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                }
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    HStack {
                        Text(item.category.displayName)
                            .font(OneBoxTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(item.category.color)
                        
                        Spacer()
                        
                        Text("Page \(item.pageNumber + 1)")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                    
                    Text(item.detectedText)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                        .lineLimit(2)
                    
                    Text("\(Int(item.confidence * 100))% confidence")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                // Preview button
                Button(action: {
                    previewRedaction(item)
                }) {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 16))
                        .foregroundColor(OneBoxColors.secondaryText)
                }
            }
        }
        .onTapGesture {
            toggleRedactionSelection(item)
        }
    }
    
    private var addCustomRedactionButton: some View {
        OneBoxCard(style: .standard) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    TextField("Enter text to redact", text: $customRedactionText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Add") {
                        addCustomRedactionItem()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(customRedactionText.isEmpty)
                }
                
                Text("Manually specify text patterns to redact")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
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
                if pdfDocument != nil {
                    performSensitiveDataAnalysis()
                }
            }
            .foregroundColor(OneBoxColors.primaryGold)
            .padding(.top, OneBoxSpacing.medium)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helper Functions
    private func loadPDFDocument() {
        print("RedactionView: Attempting to load PDF from: \(pdfURL.path)")
        print("RedactionView: File exists: \(FileManager.default.fileExists(atPath: pdfURL.path))")

        if let document = PDFDocument(url: pdfURL) {
            pdfDocument = document
            print("RedactionView: PDF loaded successfully with \(document.pageCount) pages")
        } else {
            print("RedactionView: Failed to load PDF")
            loadError = "Could not open the PDF file. The file may be corrupted or in an unsupported format."
        }
    }
    
    private func performSensitiveDataAnalysis() {
        guard let document = pdfDocument else {
            print("⚠️ RedactionView: No PDF document to analyze")
            return
        }

        print("🔍 RedactionView: Starting sensitive data analysis on \(document.pageCount) pages")
        isAnalyzing = true
        analysisProgress = 0
        redactionItems = []

        Task(priority: .userInitiated) {
            var detectedItems: [RedactionItem] = []
            let pageCount = document.pageCount

            for pageIndex in 0..<pageCount {
                // Check if task was cancelled
                if Task.isCancelled { break }

                // Use autoreleasepool to manage memory for each page
                let pageItems: [RedactionItem] = await withCheckedContinuation { continuation in
                    autoreleasepool {
                        guard let page = document.page(at: pageIndex) else {
                            print("⚠️ RedactionView: Could not get page \(pageIndex)")
                            continuation.resume(returning: [])
                            return
                        }

                        // Try to extract text from page
                        var pageText: String? = page.string

                        // If no text found, try OCR (for scanned/image-based PDFs)
                        if pageText == nil || pageText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == true {
                            print("🔍 RedactionView: Page \(pageIndex + 1) has no embedded text, trying OCR...")

                            // Perform OCR synchronously within autoreleasepool (captures bounding boxes)
                            pageText = performOCRSync(on: page, pageIndex: pageIndex)
                        }

                        if let text = pageText, !text.isEmpty {
                            print("🔍 RedactionView: Page \(pageIndex + 1) has \(text.count) characters")

                            // Detect sensitive data synchronously
                            let items = detectSensitiveDataSync(in: text, pageNumber: pageIndex)
                            continuation.resume(returning: items)
                        } else {
                            print("⚠️ RedactionView: Page \(pageIndex + 1) - no text found even after OCR")
                            continuation.resume(returning: [])
                        }
                    }
                }

                detectedItems.append(contentsOf: pageItems)

                await MainActor.run {
                    analysisProgress = Double(pageIndex + 1) / Double(pageCount)
                }

                // Small delay to let UI update and prevent watchdog timeout
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }

            print("🔍 RedactionView: Analysis complete. Found \(detectedItems.count) total items")

            await MainActor.run {
                self.redactionItems = detectedItems.sorted { $0.confidence > $1.confidence }
                self.isAnalyzing = false
                self.analysisProgress = 1.0

                if detectedItems.isEmpty {
                    print("⚠️ RedactionView: No items detected. Document may have no recognizable sensitive data.")
                }
            }
        }
    }

    /// Perform OCR synchronously (called within autoreleasepool)
    private func performOCRSync(on page: PDFPage, pageIndex: Int = 0) -> String? {
        // Render the PDF page as an image at lower scale to reduce memory
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 1.5 // Reduced from 2.0 for better memory usage
        let imageSize = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)

        // Limit max image size to prevent memory issues
        let maxDimension: CGFloat = 2000
        var finalScale = scale
        if imageSize.width > maxDimension || imageSize.height > maxDimension {
            let widthScale = maxDimension / pageRect.width
            let heightScale = maxDimension / pageRect.height
            finalScale = min(widthScale, heightScale)
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

        guard let cgImage = image.cgImage else {
            print("⚠️ RedactionView: Failed to render page as image for OCR")
            return nil
        }

        // Perform text recognition using Vision (synchronous with semaphore)
        var recognizedText: String?
        var textBlocks: [OCRTextBlock] = []
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { [self] request, error in
            defer { semaphore.signal() }

            if let error = error {
                print("⚠️ RedactionView: OCR error: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                return
            }

            // Collect text blocks with their bounding boxes AND VNRecognizedText for precise redaction
            var allText: [String] = []
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    allText.append(candidate.string)
                    // Store the bounding box AND the VNRecognizedText for character-level access
                    let block = OCRTextBlock(
                        text: candidate.string,
                        boundingBox: observation.boundingBox,
                        pageIndex: pageIndex,
                        recognizedText: candidate // Store for precise bounding boxes later
                    )
                    textBlocks.append(block)
                }
            }
            recognizedText = allText.joined(separator: " ")

            if let text = recognizedText {
                print("🔍 RedactionView: OCR extracted \(text.count) characters, \(textBlocks.count) text blocks")
            }
        }

        // Configure for faster processing (trade accuracy for speed)
        request.recognitionLevel = .fast // Changed from .accurate
        request.usesLanguageCorrection = false // Disabled for speed

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            _ = semaphore.wait(timeout: .now() + 5.0) // 5 second timeout per page
        } catch {
            print("⚠️ RedactionView: OCR handler error: \(error.localizedDescription)")
        }

        // Store the text blocks for later use during redaction
        if !textBlocks.isEmpty {
            DispatchQueue.main.async {
                self.ocrResults[pageIndex] = textBlocks
            }
        }

        return recognizedText?.isEmpty == true ? nil : recognizedText
    }

    /// Perform OCR on a PDF page using Vision framework (100% on-device) - async version
    private func performOCR(on page: PDFPage, pageIndex: Int) async -> String? {
        return performOCRSync(on: page, pageIndex: pageIndex)
    }

    /// Synchronous version of detectSensitiveData for use in autoreleasepool
    private func detectSensitiveDataSync(in text: String, pageNumber: Int) -> [RedactionItem] {
        var items: [RedactionItem] = []

        // Debug: Log extracted text (first 200 chars to reduce log spam)
        let textPreview = String(text.prefix(200))
        print("🔍 RedactionView: Page \(pageNumber + 1) text preview: \(textPreview)...")

        // Passport Numbers (various formats)
        let passportPatterns = [
            #"\b[A-Z]{1,2}\d{6,9}\b"#,
            #"\b\d{9}\b"#,
            #"\b[A-Z]\d{8}\b"#,
            #"\b[A-Z]{2}\d{7}\b"#,
            #"(?i)passport[:\s#]*([A-Z0-9]{6,12})"#,
            #"(?i)passport\s*(?:no|number|#)?[:\s]*([A-Z0-9]{6,12})"#
        ]
        for pattern in passportPatterns {
            items.append(contentsOf: findMatches(pattern: pattern, in: text, category: .passport, pageNumber: pageNumber, minConfidence: 0.85))
        }

        // Social Security Numbers
        let ssnPattern = #"(?:\d{3}-?\d{2}-?\d{4}|\d{9})"#
        items.append(contentsOf: findMatches(pattern: ssnPattern, in: text, category: .socialSecurity, pageNumber: pageNumber))

        // Credit Card Numbers
        let creditCardPattern = #"(?:\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4})"#
        items.append(contentsOf: findMatches(pattern: creditCardPattern, in: text, category: .creditCard, pageNumber: pageNumber))

        // Phone Numbers - International patterns
        let phonePatterns = [
            #"(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#,
            #"\+\d{1,3}[-.\s]?\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{3,4}"#,
            #"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"#,
            #"\b\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{4}\b"#,
            #"(?i)(?:phone|tel|mobile|cell)[:\s]*([+\d\s\-().]{7,20})"#
        ]
        for pattern in phonePatterns {
            items.append(contentsOf: findMatches(pattern: pattern, in: text, category: .phoneNumber, pageNumber: pageNumber, minConfidence: 0.75))
        }

        // Email Addresses
        let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
        items.append(contentsOf: findMatches(pattern: emailPattern, in: text, category: .email, pageNumber: pageNumber))

        // Dates - More comprehensive patterns
        let datePatterns = [
            #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#,
            #"\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b"#,
            #"\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}\b"#,
            #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{2,4}\b"#
        ]
        for pattern in datePatterns {
            items.append(contentsOf: findMatches(pattern: pattern, in: text, category: .date, pageNumber: pageNumber, minConfidence: 0.7))
        }

        print("🔍 RedactionView: Page \(pageNumber + 1) found \(items.count) items")
        return items
    }
    
    private func detectSensitiveData(in text: String, pageNumber: Int, categories: Set<SensitiveDataCategory>? = nil) async -> [RedactionItem] {
        var items: [RedactionItem] = []
        let categoriesToDetect = categories ?? Set(SensitiveDataCategory.allCases)

        // Debug: Log extracted text (first 500 chars)
        let textPreview = String(text.prefix(500))
        print("🔍 RedactionView: Page \(pageNumber + 1) text preview: \(textPreview)")
        print("🔍 RedactionView: Page \(pageNumber + 1) total chars: \(text.count)")

        // Passport Numbers (various formats)
        // US: 9 alphanumeric, UK: 9 digits, EU: alphanumeric with possible spaces
        if categoriesToDetect.contains(.passport) {
            // Common passport patterns
            let passportPatterns = [
                #"\b[A-Z]{1,2}\d{6,9}\b"#,           // UK, EU style (letter(s) + digits)
                #"\b\d{9}\b"#,                        // US 9-digit
                #"\b[A-Z]\d{8}\b"#,                   // Single letter + 8 digits
                #"\b[A-Z]{2}\d{7}\b"#,                // Two letters + 7 digits
                #"(?i)passport[:\s#]*([A-Z0-9]{6,12})"#, // After "passport" keyword
                #"(?i)passport\s*(?:no|number|#)?[:\s]*([A-Z0-9]{6,12})"# // Passport No/Number
            ]
            for pattern in passportPatterns {
                items.append(contentsOf: findMatches(pattern: pattern, in: text, category: .passport, pageNumber: pageNumber, minConfidence: 0.85))
            }
        }

        // Social Security Numbers
        if categoriesToDetect.contains(.socialSecurity) {
            let ssnPattern = #"(?:\d{3}-?\d{2}-?\d{4}|\d{9})"#
            items.append(contentsOf: findMatches(pattern: ssnPattern, in: text, category: .socialSecurity, pageNumber: pageNumber))
        }

        // Credit Card Numbers (basic pattern)
        if categoriesToDetect.contains(.creditCard) {
            let creditCardPattern = #"(?:\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4})"#
            items.append(contentsOf: findMatches(pattern: creditCardPattern, in: text, category: .creditCard, pageNumber: pageNumber))
        }

        // Phone Numbers - International patterns
        if categoriesToDetect.contains(.phoneNumber) {
            let phonePatterns = [
                #"(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#,  // US/Canada
                #"\+\d{1,3}[-.\s]?\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{3,4}"#,           // International with +
                #"\b\d{3}[-.\s]?\d{3}[-.\s]?\d{4}\b"#,                              // Basic 10-digit
                #"\b\d{2,4}[-.\s]?\d{3,4}[-.\s]?\d{4}\b"#,                          // Various formats
                #"(?i)(?:phone|tel|mobile|cell)[:\s]*([+\d\s\-().]{7,20})"#         // After phone keyword
            ]
            for pattern in phonePatterns {
                items.append(contentsOf: findMatches(pattern: pattern, in: text, category: .phoneNumber, pageNumber: pageNumber, minConfidence: 0.75))
            }
        }

        // Email Addresses
        if categoriesToDetect.contains(.email) {
            let emailPattern = #"[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"#
            items.append(contentsOf: findMatches(pattern: emailPattern, in: text, category: .email, pageNumber: pageNumber))
        }

        // Bank Account Numbers (basic pattern)
        if categoriesToDetect.contains(.bankAccount) {
            let bankAccountPattern = #"\b\d{8,17}\b"#
            items.append(contentsOf: findMatches(pattern: bankAccountPattern, in: text, category: .bankAccount, pageNumber: pageNumber, minConfidence: 0.6))
        }

        // Addresses (simplified pattern)
        if categoriesToDetect.contains(.address) {
            let addressPattern = #"\d+\s+[A-Za-z\s]+(?:Street|St|Avenue|Ave|Road|Rd|Lane|Ln|Drive|Dr|Court|Ct|Place|Pl)\b"#
            items.append(contentsOf: findMatches(pattern: addressPattern, in: text, category: .address, pageNumber: pageNumber, minConfidence: 0.7))
        }

        // Dates - More comprehensive patterns
        if categoriesToDetect.contains(.date) {
            let datePatterns = [
                #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#,           // MM/DD/YYYY or DD/MM/YYYY
                #"\b\d{4}[/-]\d{1,2}[/-]\d{1,2}\b"#,             // YYYY-MM-DD (ISO format)
                #"\b\d{1,2}\s+(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{2,4}\b"#, // 15 Jan 2024
                #"\b(?:Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)[a-z]*\s+\d{1,2},?\s+\d{2,4}\b"# // Jan 15, 2024
            ]
            for pattern in datePatterns {
                items.append(contentsOf: findMatches(pattern: pattern, in: text, category: .date, pageNumber: pageNumber, minConfidence: 0.7))
            }
        }

        // IP Addresses
        if categoriesToDetect.contains(.ipAddress) {
            let ipPattern = #"\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b"#
            items.append(contentsOf: findMatches(pattern: ipPattern, in: text, category: .ipAddress, pageNumber: pageNumber, minConfidence: 0.8))
        }

        // Use NaturalLanguage framework for person names
        if categoriesToDetect.contains(.personalName) {
            items.append(contentsOf: await detectPersonNames(in: text, pageNumber: pageNumber))
        }

        print("🔍 RedactionView: Page \(pageNumber + 1) found \(items.count) items")
        return items
    }
    
    private func findMatches(pattern: String, in text: String, category: SensitiveDataCategory, pageNumber: Int, minConfidence: Double = 0.8) -> [RedactionItem] {
        var items: [RedactionItem] = []
        
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.count))
            
            for match in matches {
                if let range = Range(match.range, in: text) {
                    let matchedText = String(text[range])
                    
                    // Additional validation for certain categories
                    var confidence = minConfidence
                    if category == .creditCard {
                        confidence = validateCreditCard(matchedText) ? 0.9 : 0.4
                    }
                    
                    if confidence >= 0.5 {
                        items.append(RedactionItem(
                            detectedText: matchedText,
                            category: category,
                            pageNumber: pageNumber,
                            confidence: confidence,
                            textRange: range
                        ))
                    }
                }
            }
        } catch {
            print("Regex error: \(error)")
        }
        
        return items
    }
    
    private func detectPersonNames(in text: String, pageNumber: Int) async -> [RedactionItem] {
        return await withCheckedContinuation { continuation in
            let tagger = NLTagger(tagSchemes: [.nameType])
            tagger.string = text
            
            var items: [RedactionItem] = []
            
            tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .nameType) { tag, tokenRange in
                if tag == .personalName {
                    let name = String(text[tokenRange])
                    // Filter out common words that might be incorrectly tagged as names
                    if name.count > 2 && !["the", "and", "for", "with"].contains(name.lowercased()) {
                        items.append(RedactionItem(
                            detectedText: name,
                            category: .personalName,
                            pageNumber: pageNumber,
                            confidence: 0.75,
                            textRange: tokenRange
                        ))
                    }
                }
                return true
            }
            
            continuation.resume(returning: items)
        }
    }
    
    private func validateCreditCard(_ number: String) -> Bool {
        let cleanNumber = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return cleanNumber.count >= 13 && cleanNumber.count <= 19
    }
    
    private func toggleRedactionSelection(_ item: RedactionItem) {
        if let index = redactionItems.firstIndex(where: { $0.id == item.id }) {
            redactionItems[index].isSelected.toggle()
            HapticManager.shared.selection()
        }
    }
    
    private func previewRedaction(_ item: RedactionItem) {
        selectedPage = item.pageNumber
        showingRedactionPreview = true
        HapticManager.shared.impact(.light)
    }
    
    private func addManualRedaction() {
        customRedactionText = ""
        // Focus text field and allow user to add custom redaction
    }
    
    private func addCustomRedactionItem() {
        guard !customRedactionText.isEmpty,
              let document = pdfDocument else { return }
        
        // Search for the custom text across all pages
        for pageIndex in 0..<document.pageCount {
            guard let page = document.page(at: pageIndex),
                  let pageText = page.string else { continue }
            
            if pageText.localizedCaseInsensitiveContains(customRedactionText) {
                let newItem = RedactionItem(
                    detectedText: customRedactionText,
                    category: .custom,
                    pageNumber: pageIndex,
                    confidence: 1.0,
                    textRange: pageText.startIndex..<pageText.endIndex // Simplified range
                )
                redactionItems.append(newItem)
            }
        }
        
        customRedactionText = ""
        HapticManager.shared.notification(.success)
    }
    
    private func applyRedactions() {
        let selectedItems = redactionItems.filter { $0.isSelected }
        guard !selectedItems.isEmpty else {
            print("❌ RedactionView: No items selected for redaction")
            return
        }

        guard let document = pdfDocument else {
            print("❌ RedactionView: No PDF document loaded")
            return
        }

        print("🔵 RedactionView: Starting redaction with \(selectedItems.count) items")
        print("🔵 RedactionView: Items to redact: \(selectedItems.map { $0.detectedText })")

        isProcessing = true
        HapticManager.shared.impact(.medium)

        Task {
            do {
                // Create redacted PDF by rendering pages as images with redaction boxes
                let outputURL = try await createRedactedPDF(
                    from: document,
                    redactingItems: selectedItems
                )

                print("🔵 RedactionView: Processing complete. Output: \(outputURL.path)")
                print("🔵 RedactionView: Output file exists: \(FileManager.default.fileExists(atPath: outputURL.path))")
                if let attrs = try? FileManager.default.attributesOfItem(atPath: outputURL.path) {
                    print("🔵 RedactionView: Output file size: \(attrs[.size] ?? 0) bytes")
                }

                // Save to Documents/Exports for persistence
                let persistedURL = saveOutputToDocuments(outputURL)
                print("🔵 RedactionView: Persisted URL: \(persistedURL?.path ?? "nil")")
                if let url = persistedURL {
                    print("🔵 RedactionView: Persisted file exists: \(FileManager.default.fileExists(atPath: url.path))")
                }

                // Create completed job for result display
                let finalURL = persistedURL ?? outputURL
                var settings = JobSettings()
                settings.redactionItems = selectedItems.map { $0.detectedText }

                let job = Job(
                    type: .pdfRedact,
                    inputs: [pdfURL],
                    settings: settings,
                    status: .success,
                    outputURLs: [finalURL],
                    completedAt: Date()
                )

                print("🔵 RedactionView: Created completed job with output: \(finalURL.path)")

                await MainActor.run {
                    paymentsManager.consumeExport()
                    completedJob = job
                    isProcessing = false
                    showingResult = true
                    HapticManager.shared.notification(.success)
                    print("🔵 RedactionView: showingResult = true, completedJob set")
                }

                // Submit job for history tracking
                await jobManager.submitJob(job)

            } catch {
                print("❌ RedactionView: Processing error: \(error)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    /// Create a redacted PDF by rendering each page as an image and drawing black boxes over sensitive text
    private func createRedactedPDF(from document: PDFDocument, redactingItems: [RedactionItem]) async throws -> URL {
        let pageCount = document.pageCount
        let tempDir = FileManager.default.temporaryDirectory
        let outputURL = tempDir.appendingPathComponent("redacted_\(UUID().uuidString).pdf")

        print("🔵 RedactionView.createRedactedPDF: Starting with \(redactingItems.count) items across \(pageCount) pages")

        // Get all text to redact (lowercased for matching)
        let textsToRedact = Set(redactingItems.map { $0.detectedText.lowercased() })
        print("🔵 RedactionView.createRedactedPDF: Texts to redact: \(textsToRedact)")

        // Capture OCR results from main thread to avoid thread safety issues
        let capturedOCRResults = await MainActor.run { self.ocrResults }
        print("🔵 RedactionView.createRedactedPDF: OCR results available for \(capturedOCRResults.count) pages")

        // Create PDF context
        guard UIGraphicsBeginPDFContextToFile(outputURL.path, .zero, nil) else {
            throw NSError(domain: "RedactionView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create PDF context"])
        }

        for pageIndex in 0..<pageCount {
            // Use autoreleasepool for EACH page to release memory immediately
            autoreleasepool {
                guard let page = document.page(at: pageIndex) else { return }

                let pageBounds = page.bounds(for: .mediaBox)

                // Find precise bounding boxes for text to redact on this page
                var preciseRedactionRects: [CGRect] = []

                if let textBlocks = capturedOCRResults[pageIndex] {
                    print("🔍 Page \(pageIndex + 1): Searching \(textBlocks.count) OCR blocks for matches")
                    for block in textBlocks {
                        let blockText = block.text
                        let blockTextLower = blockText.lowercased()

                        // For each redaction target, find if it appears in this block
                        for textToRedact in textsToRedact {
                            // Search for the target text (case-insensitive)
                            var searchRange = blockTextLower.startIndex..<blockTextLower.endIndex

                            while let matchRange = blockTextLower.range(of: textToRedact, range: searchRange) {
                                // Convert the lowercased match range to the original string range
                                let startDistance = blockTextLower.distance(from: blockTextLower.startIndex, to: matchRange.lowerBound)
                                let endDistance = blockTextLower.distance(from: blockTextLower.startIndex, to: matchRange.upperBound)
                                let originalStart = blockText.index(blockText.startIndex, offsetBy: startDistance)
                                let originalEnd = blockText.index(blockText.startIndex, offsetBy: endDistance)
                                let originalRange = originalStart..<originalEnd

                                var gotPreciseBox = false

                                // Try to get precise bounding box using VNRecognizedText
                                if let recognizedText = block.recognizedText {
                                    do {
                                        // Get character-level bounding box for just the matched text
                                        if let preciseBoundingBox = try recognizedText.boundingBox(for: originalRange) {
                                            preciseRedactionRects.append(preciseBoundingBox.boundingBox)
                                            print("🎯 RedactionView: Found PRECISE match '\(String(blockText[originalRange]))' at box: \(preciseBoundingBox.boundingBox)")
                                            gotPreciseBox = true
                                        }
                                    } catch {
                                        print("⚠️ RedactionView: Character-level bounding box failed for '\(textToRedact)': \(error)")
                                    }
                                }

                                // FALLBACK: If character-level failed, use the FULL block bounding box
                                // This is less precise but ensures sensitive data gets redacted
                                if !gotPreciseBox {
                                    // Calculate approximate sub-box based on character position ratio
                                    let matchLength = textToRedact.count
                                    let blockLength = blockText.count
                                    let startRatio = Double(startDistance) / Double(max(blockLength, 1))
                                    let lengthRatio = Double(matchLength) / Double(max(blockLength, 1))

                                    // Create approximate bounding box within the block
                                    let approxBox = CGRect(
                                        x: block.boundingBox.origin.x + (block.boundingBox.width * startRatio),
                                        y: block.boundingBox.origin.y,
                                        width: block.boundingBox.width * lengthRatio,
                                        height: block.boundingBox.height
                                    )
                                    preciseRedactionRects.append(approxBox)
                                    print("🔶 RedactionView: Using FALLBACK approximate box for '\(textToRedact)' at: \(approxBox)")
                                }

                                // Move search range forward to find more occurrences
                                searchRange = matchRange.upperBound..<blockTextLower.endIndex
                            }
                        }
                    }
                }

                // Render page directly to PDF with redaction boxes (single render pass)
                UIGraphicsBeginPDFPageWithInfo(pageBounds, nil)

                if let pdfContext = UIGraphicsGetCurrentContext() {
                    // Draw original page
                    pdfContext.saveGState()
                    pdfContext.translateBy(x: 0, y: pageBounds.height)
                    pdfContext.scaleBy(x: 1.0, y: -1.0)
                    page.draw(with: .mediaBox, to: pdfContext)
                    pdfContext.restoreGState()

                    // Draw black boxes over PRECISE redacted areas only
                    if !preciseRedactionRects.isEmpty {
                        print("🔵 RedactionView.createRedactedPDF: Page \(pageIndex + 1) - drawing \(preciseRedactionRects.count) precise redaction boxes")

                        pdfContext.setFillColor(UIColor.black.cgColor)

                        for box in preciseRedactionRects {
                            // CRITICAL: Convert Vision's normalized coordinates to UIKit PDF context coordinates
                            // Vision: origin at BOTTOM-LEFT, Y increases UPWARD (0-1 normalized)
                            // UIKit PDF context: origin at TOP-LEFT, Y increases DOWNWARD

                            // X coordinate is straightforward (both have same X direction)
                            let x = box.origin.x * pageBounds.width

                            // Y coordinate needs flipping:
                            // Vision's box.origin.y is the BOTTOM of the box (from bottom of page)
                            // Vision's top of box = origin.y + height
                            // UIKit's origin.y should be the TOP of the box (from top of page)
                            // UIKit y = pageHeight - (Vision's top of box * pageHeight)
                            //         = pageHeight * (1 - origin.y - height)
                            let y = pageBounds.height * (1.0 - box.origin.y - box.height)

                            let width = box.width * pageBounds.width
                            let height = box.height * pageBounds.height

                            // Add small padding for complete coverage
                            let padding: CGFloat = 3
                            let rect = CGRect(
                                x: x - padding,
                                y: y - padding,
                                width: width + padding * 2,
                                height: height + padding * 2
                            )

                            print("🎯 Drawing redaction box at: x=\(Int(x)), y=\(Int(y)), w=\(Int(width)), h=\(Int(height))")

                            pdfContext.fill(rect)
                        }
                    } else {
                        print("🔵 RedactionView.createRedactedPDF: Page \(pageIndex + 1) - no precise matches found")
                    }
                }
            }

            // Small delay between pages to allow memory cleanup
            try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }

        // Close PDF context
        UIGraphicsEndPDFContext()

        // Verify the PDF was created
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw NSError(domain: "RedactionView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create redacted PDF"])
        }

        print("✅ RedactionView.createRedactedPDF: Successfully created at \(outputURL.path)")
        return outputURL
    }

    /// Save output file to Documents/Exports for persistence
    private func saveOutputToDocuments(_ tempURL: URL?) -> URL? {
        print("🔵 RedactionView.saveOutputToDocuments: Called with tempURL: \(tempURL?.path ?? "nil")")

        guard let tempURL = tempURL else {
            print("❌ RedactionView.saveOutputToDocuments: tempURL is nil")
            return nil
        }

        print("🔵 RedactionView.saveOutputToDocuments: Temp file exists: \(FileManager.default.fileExists(atPath: tempURL.path))")

        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("❌ RedactionView.saveOutputToDocuments: Could not get documents directory")
            return tempURL
        }

        let exportsURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)
        print("🔵 RedactionView.saveOutputToDocuments: Exports directory: \(exportsURL.path)")

        // Create Exports directory if needed
        if !fileManager.fileExists(atPath: exportsURL.path) {
            do {
                try fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
                print("🔵 RedactionView.saveOutputToDocuments: Created Exports directory")
            } catch {
                print("❌ RedactionView.saveOutputToDocuments: Failed to create Exports directory: \(error)")
            }
        }

        // Generate unique filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M-d-yy_h-mm_a"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "redacted_pdf_\(timestamp).pdf"
        let destinationURL = exportsURL.appendingPathComponent(filename)

        print("🔵 RedactionView.saveOutputToDocuments: Destination: \(destinationURL.path)")

        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: tempURL, to: destinationURL)
            print("✅ RedactionView.saveOutputToDocuments: Successfully copied to \(destinationURL.path)")
            print("✅ RedactionView.saveOutputToDocuments: File exists: \(fileManager.fileExists(atPath: destinationURL.path))")
            return destinationURL
        } catch {
            print("❌ RedactionView.saveOutputToDocuments: Failed to copy: \(error)")
            return tempURL
        }
    }
}

// MARK: - Supporting Types

struct RedactionItem: Identifiable {
    let id = UUID()
    let detectedText: String
    let category: SensitiveDataCategory
    let pageNumber: Int
    let confidence: Double
    let textRange: Range<String.Index>
    var isSelected = true
    var boundingBox: CGRect? // Normalized bounding box (0-1 range) for scanned PDFs
}

/// Stores OCR text with VNRecognizedText for character-level bounding box access
struct OCRTextBlock {
    let text: String
    let boundingBox: CGRect // Normalized coordinates (0-1) - full block bounding box
    let pageIndex: Int
    let recognizedText: VNRecognizedText? // Store for precise character-level bounding boxes
}

typealias RedactionCategory = SensitiveDataCategory

enum RedactionPreset: String, CaseIterable, Identifiable {
    case legal
    case finance
    case hr
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .legal: return "Legal"
        case .finance: return "Finance"
        case .hr: return "HR"
        }
    }
    
    var icon: String {
        switch self {
        case .legal: return "scale.3d"
        case .finance: return "dollarsign.circle.fill"
        case .hr: return "person.2.fill"
        }
    }
    
    var categories: Set<SensitiveDataCategory> {
        switch self {
        case .legal:
            return [.socialSecurity, .personalName, .address, .phoneNumber, .email, .date, .passport]
        case .finance:
            return [.creditCard, .bankAccount, .socialSecurity, .personalName, .email, .phoneNumber, .passport]
        case .hr:
            return [.personalName, .socialSecurity, .email, .phoneNumber, .address, .date, .passport]
        }
    }
}

enum SensitiveDataCategory: String, CaseIterable {
    case socialSecurity = "SSN"
    case creditCard = "Credit Card"
    case phoneNumber = "Phone"
    case email = "Email"
    case bankAccount = "Bank Account"
    case address = "Address"
    case personalName = "Name"
    case date = "Date"
    case ipAddress = "IP Address"
    case passport = "Passport"
    case custom = "Custom"

    var displayName: String {
        switch self {
        case .socialSecurity: return "Social Security"
        case .creditCard: return "Credit Card"
        case .phoneNumber: return "Phone Number"
        case .email: return "Email Address"
        case .bankAccount: return "Bank Account"
        case .address: return "Address"
        case .personalName: return "Personal Name"
        case .date: return "Date"
        case .ipAddress: return "IP Address"
        case .passport: return "Passport Number"
        case .custom: return "Custom"
        }
    }

    var color: Color {
        switch self {
        case .socialSecurity: return OneBoxColors.criticalRed
        case .creditCard: return OneBoxColors.criticalRed
        case .phoneNumber: return OneBoxColors.warningAmber
        case .email: return OneBoxColors.warningAmber
        case .bankAccount: return OneBoxColors.criticalRed
        case .address: return OneBoxColors.warningAmber
        case .personalName: return OneBoxColors.secondaryGold
        case .date: return OneBoxColors.warningAmber
        case .ipAddress: return OneBoxColors.warningAmber
        case .passport: return OneBoxColors.criticalRed
        case .custom: return OneBoxColors.primaryGold
        }
    }
}

// MARK: - Redaction Preview View

struct RedactionPreviewView: View {
    let pdfURL: URL
    let redactionItems: [RedactionItem]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            // Simplified preview - in a real implementation, this would show
            // the PDF with redaction overlays
            VStack {
                Text("Redaction Preview")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("\(redactionItems.count) items will be redacted")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    RedactionView(pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
        .environmentObject(JobManager.shared)
        .environmentObject(PaymentsManager.shared)
}