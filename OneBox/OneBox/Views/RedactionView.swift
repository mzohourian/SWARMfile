//
//  RedactionView.swift
//  OneBox
//
//  Advanced redaction and sensitive data detection for OneBox Standard
//

import SwiftUI
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
    @State private var isAnalyzing = false
    @State private var analysisProgress: Double = 0
    @State private var selectedPage = 0
    @State private var pdfDocument: PDFDocument?
    @State private var showingRedactionPreview = false
    @State private var customRedactionText = ""
    @State private var redactionMode: RedactionMode = .automatic
    @State private var selectedPreset: RedactionPreset?
    @State private var showingPresetPicker = false
    @State private var isProcessing = false
    @State private var completedJob: Job?
    @State private var showingResult = false
    @State private var errorMessage: String?
    @State private var didStartAccessingSecurityScoped = false
    @State private var loadError: String?

    enum RedactionMode: String, CaseIterable {
        case automatic = "Automatic Detection"
        case manual = "Manual Selection"
        case combined = "Combined Approach"
    }
    
    var body: some View {
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
            // Start security-scoped access for files from document picker
            if pdfURL.startAccessingSecurityScopedResource() {
                didStartAccessingSecurityScoped = true
                print("RedactionView: Started security-scoped resource access")
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
                        
                        Text("AI-powered detection and secure redaction")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                }
                
                // Mode Selection
                Picker("Redaction Mode", selection: $redactionMode) {
                    ForEach(RedactionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: redactionMode) { _ in
                    if redactionMode == .automatic || redactionMode == .combined {
                        performSensitiveDataAnalysis()
                    }
                }
                
                // Preset Selection
                HStack {
                    Text("Quick Presets:")
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
                
                if redactionMode != .automatic {
                    Button("Add Manual Redaction") {
                        addManualRedaction()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .padding(.top, OneBoxSpacing.medium)
                }
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
                    
                    if redactionMode != .automatic {
                        addCustomRedactionButton
                    }
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
        guard let document = pdfDocument else { return }
        
        isAnalyzing = true
        analysisProgress = 0
        redactionItems = []
        
        Task {
            var detectedItems: [RedactionItem] = []
            let pageCount = document.pageCount
            
            for pageIndex in 0..<pageCount {
                guard let page = document.page(at: pageIndex) else { continue }
                
                await MainActor.run {
                    analysisProgress = Double(pageIndex) / Double(pageCount) * 0.5
                }
                
                // Extract text from page
                guard let pageText = page.string else { continue }
                
                // Detect various types of sensitive data
                let pageItems = await detectSensitiveData(in: pageText, pageNumber: pageIndex)
                detectedItems.append(contentsOf: pageItems)
                
                await MainActor.run {
                    analysisProgress = Double(pageIndex) / Double(pageCount)
                }
            }
            
            await MainActor.run {
                self.redactionItems = detectedItems.sorted { $0.confidence > $1.confidence }
                self.isAnalyzing = false
                self.analysisProgress = 1.0
            }
        }
    }
    
    private func detectSensitiveData(in text: String, pageNumber: Int, categories: Set<SensitiveDataCategory>? = nil) async -> [RedactionItem] {
        var items: [RedactionItem] = []
        let categoriesToDetect = categories ?? Set(SensitiveDataCategory.allCases)
        
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
        
        // Phone Numbers
        if categoriesToDetect.contains(.phoneNumber) {
            let phonePattern = #"(?:\+?1[-.\s]?)?\(?[0-9]{3}\)?[-.\s]?[0-9]{3}[-.\s]?[0-9]{4}"#
            items.append(contentsOf: findMatches(pattern: phonePattern, in: text, category: .phoneNumber, pageNumber: pageNumber))
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
        
        // Dates
        if categoriesToDetect.contains(.date) {
            let datePattern = #"\b\d{1,2}[/-]\d{1,2}[/-]\d{2,4}\b"#
            items.append(contentsOf: findMatches(pattern: datePattern, in: text, category: .date, pageNumber: pageNumber, minConfidence: 0.7))
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
        guard !selectedItems.isEmpty else { return }

        isProcessing = true
        HapticManager.shared.impact(.medium)

        Task {
            do {
                // Create settings with redaction items
                var settings = JobSettings()
                settings.redactionItems = selectedItems.map { $0.detectedText }
                settings.redactionMode = redactionMode.rawValue

                // Process redaction using JobEngine
                let processor = JobProcessor()
                let tempJob = Job(
                    type: .pdfRedact,
                    inputs: [pdfURL],
                    settings: settings
                )

                let outputURLs = try await processor.process(job: tempJob) { progress in
                    // Progress is handled by the overlay
                }

                // Save to Documents/Exports for persistence
                let persistedURL = saveOutputToDocuments(outputURLs.first)

                // Create completed job for result display
                let job = Job(
                    type: .pdfRedact,
                    inputs: [pdfURL],
                    settings: settings,
                    status: .success,
                    outputURLs: [persistedURL ?? outputURLs.first!],
                    completedAt: Date()
                )

                await MainActor.run {
                    paymentsManager.consumeExport()
                    completedJob = job
                    isProcessing = false
                    showingResult = true
                    HapticManager.shared.notification(.success)
                }

                // Submit job for history tracking
                await jobManager.submitJob(job)

            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }

    /// Save output file to Documents/Exports for persistence
    private func saveOutputToDocuments(_ tempURL: URL?) -> URL? {
        guard let tempURL = tempURL else { return nil }

        let fileManager = FileManager.default
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return tempURL
        }

        let exportsURL = documentsURL.appendingPathComponent("Exports", isDirectory: true)

        // Create Exports directory if needed
        if !fileManager.fileExists(atPath: exportsURL.path) {
            try? fileManager.createDirectory(at: exportsURL, withIntermediateDirectories: true)
        }

        // Generate unique filename with timestamp
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "M-d-yy_h-mm_a"
        let timestamp = dateFormatter.string(from: Date())
        let filename = "redacted_pdf_\(timestamp).pdf"
        let destinationURL = exportsURL.appendingPathComponent(filename)

        do {
            // Remove existing file if present
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: tempURL, to: destinationURL)
            return destinationURL
        } catch {
            print("Failed to save to Documents: \(error)")
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
            return [.socialSecurity, .personalName, .address, .phoneNumber, .email, .date]
        case .finance:
            return [.creditCard, .bankAccount, .socialSecurity, .personalName, .email, .phoneNumber]
        case .hr:
            return [.personalName, .socialSecurity, .email, .phoneNumber, .address, .date]
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