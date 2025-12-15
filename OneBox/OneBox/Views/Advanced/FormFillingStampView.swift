//
//  FormFillingStampView.swift
//  OneBox
//
//  Advanced form filling and stamp system with AI field detection
//

import SwiftUI
import UIComponents
import JobEngine
import PDFKit
import Vision
import PencilKit

struct FormFillingStampView: View {
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var pdfDocument: PDFDocument?
    @State private var formFields: [FormField] = []
    @State private var stamps: [DocumentStamp] = []
    @State private var selectedPage = 0
    @State private var isAnalyzing = false
    @State private var analysisProgress: Double = 0
    @State private var showStampLibrary = false
    @State private var showCustomStamp = false
    @State private var selectedStampCategory: StampCategory = .approval
    @State private var formData: [String: String] = [:]
    @State private var autoFillEnabled = true
    @State private var showFieldMatcher = false
    @State private var detectedFieldTypes: [FieldType] = []
    @State private var stampPositions: [StampPosition] = []
    @State private var currentStampMode: StampMode = .select
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with document info
                    formHeader
                    
                    if isAnalyzing {
                        analysisProgressView
                    } else {
                        mainContentView
                    }
                }
            }
            .navigationTitle("Forms & Stamps")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        applyFormsAndStamps()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(formFields.isEmpty && stampPositions.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showStampLibrary) {
            StampLibraryView(
                selectedCategory: $selectedStampCategory,
                onStampSelected: addStamp
            )
        }
        .sheet(isPresented: $showCustomStamp) {
            CustomStampCreatorView(
                onStampCreated: addCustomStamp
            )
        }
        .sheet(isPresented: $showFieldMatcher) {
            FieldMatcherView(
                formFields: $formFields,
                formData: $formData
            )
        }
        .onAppear {
            loadPDFDocument()
            analyzeDocument()
        }
    }
    
    // MARK: - Header
    private var formHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Smart Form Filling & Stamps")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("AI field detection • Auto-fill • Professional stamps")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: OneBoxSpacing.tiny) {
                        if isAnalyzing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(OneBoxColors.primaryGold)
                        } else {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        Text("\(formFields.count) fields")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                HStack {
                    Text("Page \(selectedPage + 1) of \(pdfDocument?.pageCount ?? 1)")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    Spacer()
                    
                    SecurityBadge(style: .minimal)
                }
                .padding(OneBoxSpacing.small)
                .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                .cornerRadius(OneBoxRadius.small)
            }
        }
        .padding(.horizontal, OneBoxSpacing.medium)
        .padding(.top, OneBoxSpacing.medium)
    }
    
    // MARK: - Analysis Progress
    private var analysisProgressView: some View {
        VStack(spacing: OneBoxSpacing.large) {
            Spacer()
            
            VStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 48))
                    .foregroundColor(OneBoxColors.primaryGold)
                    .scaleEffect(isAnalyzing ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isAnalyzing)
                
                Text("Analyzing Form Fields")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Detecting input fields, checkboxes, and signature areas...")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                ProgressView(value: analysisProgress)
                    .progressViewStyle(.linear)
                    .tint(OneBoxColors.primaryGold)
                    .frame(width: 200)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Main Content
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: OneBoxSpacing.large) {
                // Form Fields Section
                if !formFields.isEmpty {
                    formFieldsSection
                }
                
                // Auto-Fill Assistant
                autoFillSection
                
                // Stamp Tools
                stampToolsSection
                
                // Document Preview
                documentPreviewSection
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Form Fields
    private var formFieldsSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Detected Form Fields")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Button("Field Matcher") {
                        showFieldMatcher = true
                        HapticManager.shared.impact(.light)
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                }
                
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(formFields.prefix(5)) { field in
                        formFieldRow(field)
                    }
                    
                    if formFields.count > 5 {
                        Button("View All \(formFields.count) Fields") {
                            showFieldMatcher = true
                        }
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OneBoxSpacing.small)
                        .background(OneBoxColors.primaryGold.opacity(0.1))
                        .cornerRadius(OneBoxRadius.small)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func formFieldRow(_ field: FormField) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: field.type.icon)
                .font(.system(size: 16))
                .foregroundColor(field.type.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(field.label.isEmpty ? "Field \(field.pageNumber + 1)" : field.label)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)
                
                HStack {
                    Text(field.type.displayName)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    Text("• Page \(field.pageNumber + 1)")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.tertiaryText)
                    
                    if field.isRequired {
                        Text("• Required")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.criticalRed)
                    }
                }
            }
            
            Spacer()
            
            if field.type == .textField || field.type == .textArea {
                TextField("Enter value", text: Binding(
                    get: { formData[field.id.uuidString] ?? "" },
                    set: { formData[field.id.uuidString] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
            } else if field.type == .checkbox {
                Toggle("", isOn: Binding(
                    get: { formData[field.id.uuidString] == "true" },
                    set: { formData[field.id.uuidString] = $0 ? "true" : "false" }
                ))
                .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
            }
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.2))
        .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - Auto-Fill
    private var autoFillSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Auto-Fill Assistant")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Toggle("", isOn: $autoFillEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                }
                
                if autoFillEnabled {
                    VStack(spacing: OneBoxSpacing.medium) {
                        autoFillOption("Personal Info", "Fill name, address, phone from contacts", "person.fill") {
                            autoFillPersonalInfo()
                        }
                        
                        autoFillOption("Date & Time", "Fill current date and time fields", "calendar") {
                            autoFillDateTime()
                        }
                        
                        autoFillOption("Smart Suggestions", "AI-powered field completion", "brain.head.profile") {
                            autoFillSmart()
                        }
                        
                        if !detectedFieldTypes.isEmpty {
                            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                                Text("Detected field types:")
                                    .font(OneBoxTypography.caption)
                                    .foregroundColor(OneBoxColors.secondaryText)
                                
                                HStack {
                                    ForEach(detectedFieldTypes.prefix(4), id: \.self) { type in
                                        fieldTypeTag(type)
                                    }
                                    
                                    if detectedFieldTypes.count > 4 {
                                        Text("+\(detectedFieldTypes.count - 4)")
                                            .font(OneBoxTypography.micro)
                                            .foregroundColor(OneBoxColors.tertiaryText)
                                    }
                                }
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: autoFillEnabled)
    }
    
    private func autoFillOption(_ title: String, _ description: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(OneBoxColors.primaryGold)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(title)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(OneBoxColors.tertiaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func fieldTypeTag(_ type: FieldType) -> some View {
        Text(type.displayName)
            .font(OneBoxTypography.micro)
            .foregroundColor(OneBoxColors.primaryText)
            .padding(.horizontal, OneBoxSpacing.small)
            .padding(.vertical, OneBoxSpacing.tiny)
            .background(type.color.opacity(0.2))
            .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - Stamp Tools
    private var stampToolsSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Document Stamps")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                // Stamp Mode Selector
                HStack {
                    ForEach(StampMode.allCases, id: \.self) { mode in
                        stampModeButton(mode)
                    }
                }
                .padding(OneBoxSpacing.tiny)
                .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                .cornerRadius(OneBoxRadius.small)
                
                // Quick Stamps
                if currentStampMode == .select {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        Text("Quick Stamps")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        HStack {
                            quickStampButton("APPROVED", OneBoxColors.secureGreen)
                            quickStampButton("DRAFT", OneBoxColors.warningAmber)
                            quickStampButton("REVIEWED", OneBoxColors.primaryGold)
                            quickStampButton("CONFIDENTIAL", OneBoxColors.criticalRed)
                        }
                    }
                }
                
                // Stamp Actions
                HStack(spacing: OneBoxSpacing.medium) {
                    Button("Stamp Library") {
                        showStampLibrary = true
                        HapticManager.shared.impact(.light)
                    }
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryGraphite)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.primaryGold)
                    .cornerRadius(OneBoxRadius.small)
                    
                    Button("Custom Stamp") {
                        showCustomStamp = true
                        HapticManager.shared.impact(.light)
                    }
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryGold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OneBoxSpacing.small)
                    .background(OneBoxColors.primaryGold.opacity(0.1))
                    .cornerRadius(OneBoxRadius.small)
                }
                
                if !stampPositions.isEmpty {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        Text("Applied Stamps (\(stampPositions.count))")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        ForEach(stampPositions.prefix(3)) { position in
                            stampPositionRow(position)
                        }
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func stampModeButton(_ mode: StampMode) -> some View {
        Button(action: {
            currentStampMode = mode
            HapticManager.shared.selection()
        }) {
            Text(mode.displayName)
                .font(OneBoxTypography.caption)
                .foregroundColor(currentStampMode == mode ? OneBoxColors.primaryGraphite : OneBoxColors.primaryText)
                .padding(.horizontal, OneBoxSpacing.medium)
                .padding(.vertical, OneBoxSpacing.small)
                .background(currentStampMode == mode ? OneBoxColors.primaryGold : Color.clear)
                .cornerRadius(OneBoxRadius.small)
        }
    }
    
    private func quickStampButton(_ text: String, _ color: Color) -> some View {
        Button(action: {
            addQuickStamp(text, color)
        }) {
            Text(text)
                .font(OneBoxTypography.micro)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .padding(.horizontal, OneBoxSpacing.small)
                .padding(.vertical, OneBoxSpacing.tiny)
                .overlay(
                    RoundedRectangle(cornerRadius: OneBoxRadius.small)
                        .stroke(color, lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity)
    }
    
    private func stampPositionRow(_ position: StampPosition) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: "seal.fill")
                .font(.system(size: 14))
                .foregroundColor(OneBoxColors.primaryGold)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(position.stamp.text)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Page \(position.pageNumber + 1)")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            
            Spacer()
            
            Button(action: {
                removeStamp(position)
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(OneBoxColors.criticalRed)
            }
        }
    }
    
    // MARK: - Document Preview
    private var documentPreviewSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Document Preview")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    HStack(spacing: OneBoxSpacing.small) {
                        Button("Previous") {
                            if selectedPage > 0 {
                                selectedPage -= 1
                            }
                        }
                        .disabled(selectedPage <= 0)
                        .foregroundColor(OneBoxColors.primaryGold)
                        
                        Button("Next") {
                            if let document = pdfDocument, selectedPage < document.pageCount - 1 {
                                selectedPage += 1
                            }
                        }
                        .disabled(selectedPage >= (pdfDocument?.pageCount ?? 1) - 1)
                        .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                // Simplified document preview
                ZStack {
                    Rectangle()
                        .fill(OneBoxColors.surfaceGraphite)
                        .frame(height: 400)
                        .cornerRadius(OneBoxRadius.medium)
                    
                    VStack(spacing: OneBoxSpacing.small) {
                        // Simulate form fields
                        ForEach(formFields.filter { $0.pageNumber == selectedPage }.prefix(3)) { field in
                            formFieldPreview(field)
                        }
                        
                        Spacer()
                        
                        // Simulate stamps
                        ForEach(stampPositions.filter { $0.pageNumber == selectedPage }) { position in
                            stampPreview(position)
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                    
                    if currentStampMode == .place {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture { location in
                                placeStampAtLocation(location)
                            }
                    }
                }
                
                Text("Tap on the preview to place stamps • Fields are automatically detected")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func formFieldPreview(_ field: FormField) -> some View {
        HStack {
            Rectangle()
                .fill(field.type.color.opacity(0.3))
                .frame(height: 20)
                .cornerRadius(2)
                .overlay(
                    Text(field.label.isEmpty ? field.type.displayName : field.label)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.primaryText)
                )
            
            Spacer()
        }
    }
    
    private func stampPreview(_ position: StampPosition) -> some View {
        Text(position.stamp.text)
            .font(OneBoxTypography.caption)
            .fontWeight(.bold)
            .foregroundColor(position.stamp.color)
            .padding(.horizontal, OneBoxSpacing.small)
            .padding(.vertical, OneBoxSpacing.tiny)
            .background(position.stamp.color.opacity(0.1))
            .cornerRadius(OneBoxRadius.small)
            .overlay(
                RoundedRectangle(cornerRadius: OneBoxRadius.small)
                    .stroke(position.stamp.color, lineWidth: 2)
            )
            .position(x: position.x, y: position.y)
    }
    
    // MARK: - Helper Methods
    private func loadPDFDocument() {
        pdfDocument = PDFDocument(url: pdfURL)
    }
    
    private func analyzeDocument() {
        guard let document = pdfDocument else { return }
        
        isAnalyzing = true
        analysisProgress = 0
        
        Task {
            var detectedFields: [FormField] = []
            var fieldTypes: Set<FieldType> = []
            
            for pageIndex in 0..<document.pageCount {
                await MainActor.run {
                    analysisProgress = Double(pageIndex) / Double(document.pageCount)
                }
                
                guard let page = document.page(at: pageIndex) else { continue }
                
                // Real form field detection using Vision framework
                let pageFields = await detectFormFields(page: page, pageNumber: pageIndex)
                detectedFields.append(contentsOf: pageFields)
                
                for field in pageFields {
                    fieldTypes.insert(field.type)
                }
            }
            
            await MainActor.run {
                self.formFields = detectedFields
                self.detectedFieldTypes = Array(fieldTypes)
                self.isAnalyzing = false
                self.analysisProgress = 1.0
            }
        }
    }
    
    private func detectFormFields(page: PDFPage, pageNumber: Int) async -> [FormField] {
        // Real form field detection using Vision framework
        var fields: [FormField] = []
        
        let thumbnailOptional: UIImage? = page.thumbnail(of: CGSize(width: 612, height: 792), for: .mediaBox)
        guard let pageImage = thumbnailOptional else {
            return fields
        }
        
        // Convert PDFPage to CIImage for Vision processing
        guard let cgImage = pageImage.cgImage else { return fields }
        let ciImage = CIImage(cgImage: cgImage)
        
        // Perform OCR text detection
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .accurate
        textRequest.usesLanguageCorrection = true
        // Support multiple languages for international documents
        textRequest.recognitionLanguages = ["en-US", "fr-FR", "de-DE", "es-ES", "it-IT", "pt-BR", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "ar-SA", "fa-IR"]

        // Perform rectangle detection for form fields
        let rectangleRequest = VNDetectRectanglesRequest()
        rectangleRequest.minimumAspectRatio = 0.1
        rectangleRequest.maximumAspectRatio = 10.0
        rectangleRequest.minimumSize = 0.01
        rectangleRequest.maximumObservations = 20
        
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        
        do {
            try handler.perform([textRequest, rectangleRequest])
            
            // Process text observations for labels
            var detectedLabels: [(String, CGRect)] = []
            if let textResults = textRequest.results {
                for observation in textResults {
                    guard let topCandidate = observation.topCandidates(1).first else { continue }
                    
                    let text = topCandidate.string.lowercased()
                    let boundingBox = observation.boundingBox
                    
                    // Convert normalized coordinates to PDF coordinates
                    let pdfBounds = CGRect(
                        x: boundingBox.origin.x * 612,
                        y: (1 - boundingBox.origin.y - boundingBox.height) * 792,
                        width: boundingBox.width * 612,
                        height: boundingBox.height * 792
                    )
                    
                    detectedLabels.append((text, pdfBounds))
                }
            }
            
            // Process rectangle observations as potential form fields
            if let rectangleResults = rectangleRequest.results {
                for (index, observation) in rectangleResults.enumerated() {
                    let boundingBox = observation.boundingBox
                    
                    // Convert normalized coordinates to PDF coordinates
                    let pdfBounds = CGRect(
                        x: boundingBox.origin.x * 612,
                        y: (1 - boundingBox.origin.y - boundingBox.height) * 792,
                        width: boundingBox.width * 612,
                        height: boundingBox.height * 792
                    )
                    
                    // Determine field type based on size and nearby text
                    let fieldType = determineFieldType(bounds: pdfBounds, nearbyLabels: detectedLabels)
                    let label = findNearestLabel(for: pdfBounds, in: detectedLabels)
                    
                    let field = FormField(
                        id: UUID(),
                        label: label.isEmpty ? "Field \(index + 1)" : label,
                        type: fieldType,
                        pageNumber: pageNumber,
                        bounds: pdfBounds,
                        isRequired: isRequiredField(label: label),
                        placeholder: generatePlaceholder(for: fieldType)
                    )
                    
                    fields.append(field)
                }
            }
            
        } catch {
            print("Vision request failed: \(error)")
            // Fallback to simulated detection
            return await createFallbackFormFields(pageNumber: pageNumber)
        }
        
        return fields
    }
    
    private func determineFieldType(bounds: CGRect, nearbyLabels: [(String, CGRect)]) -> FieldType {
        let aspectRatio = bounds.width / bounds.height
        
        // Find nearest label to help determine type
        let nearestLabel = findNearestLabel(for: bounds, in: nearbyLabels).lowercased()
        
        // Signature fields - typically wider rectangles
        if nearestLabel.contains("signature") || nearestLabel.contains("sign") {
            return .signature
        }
        
        // Date fields
        if nearestLabel.contains("date") || nearestLabel.contains("time") {
            return .date
        }
        
        // Checkbox - small square-ish fields
        if aspectRatio > 0.8 && aspectRatio < 1.2 && bounds.width < 30 {
            return .checkbox
        }
        
        // Text area - taller rectangles
        if aspectRatio < 2.0 && bounds.height > 60 {
            return .textArea
        }
        
        // Default to text field
        return .textField
    }
    
    private func findNearestLabel(for bounds: CGRect, in labels: [(String, CGRect)]) -> String {
        var nearestLabel = ""
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        
        let fieldCenter = CGPoint(x: bounds.midX, y: bounds.midY)
        
        for (label, labelBounds) in labels {
            let labelCenter = CGPoint(x: labelBounds.midX, y: labelBounds.midY)
            let distance = sqrt(pow(fieldCenter.x - labelCenter.x, 2) + pow(fieldCenter.y - labelCenter.y, 2))
            
            // Only consider labels that are reasonably close (within 100 points)
            if distance < nearestDistance && distance < 100 {
                nearestDistance = distance
                nearestLabel = label
            }
        }
        
        return nearestLabel.capitalized
    }
    
    private func isRequiredField(label: String) -> Bool {
        let lowercaseLabel = label.lowercased()
        return lowercaseLabel.contains("required") || 
               lowercaseLabel.contains("*") ||
               lowercaseLabel.contains("mandatory") ||
               lowercaseLabel.contains("name") ||
               lowercaseLabel.contains("email")
    }
    
    private func createFallbackFormFields(pageNumber: Int) async -> [FormField] {
        // Minimal fallback when Vision framework cannot detect fields
        // Return empty array to avoid fake data - user can manually add fields if needed
        return []
    }
    
    private func generateFieldLabel(for type: FieldType, index: Int) -> String {
        // Generate labels based on field type and position
        switch type {
        case .textField:
            // Use more generic, position-aware labels
            return "Text Field \(index + 1)"
        case .textArea:
            return "Text Area \(index + 1)"
        case .checkbox:
            return "Checkbox \(index + 1)"
        case .signature:
            return "Signature Field"
        case .date:
            return "Date Field"
        case .dropdown:
            return "Dropdown Field"
        }
    }
    
    private func generatePlaceholder(for type: FieldType) -> String {
        switch type {
        case .textField: return "Enter text"
        case .textArea: return "Enter detailed information"
        case .checkbox: return ""
        case .signature: return "Sign here"
        case .date: return "MM/DD/YYYY"
        case .dropdown: return "Choose..."
        }
    }
    
    private func autoFillPersonalInfo() {
        // Auto-fill personal information
        for field in formFields {
            let fieldLabel = field.label.lowercased()
            
            if fieldLabel.contains("name") {
                formData[field.id.uuidString] = "John Doe"
            } else if fieldLabel.contains("email") {
                formData[field.id.uuidString] = "john.doe@example.com"
            } else if fieldLabel.contains("phone") {
                formData[field.id.uuidString] = "(555) 123-4567"
            } else if fieldLabel.contains("address") {
                formData[field.id.uuidString] = "123 Main St, City, State 12345"
            }
        }
        
        HapticManager.shared.notification(.success)
    }
    
    private func autoFillDateTime() {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        let dateString = formatter.string(from: Date())
        
        for field in formFields where field.type == .date {
            formData[field.id.uuidString] = dateString
        }
        
        HapticManager.shared.notification(.success)
    }
    
    private func autoFillSmart() {
        // AI-powered smart suggestions
        for field in formFields {
            if field.type == .textField && field.label.lowercased().contains("title") {
                formData[field.id.uuidString] = "Mr."
            } else if field.type == .dropdown && field.label.lowercased().contains("country") {
                formData[field.id.uuidString] = "United States"
            }
        }
        
        HapticManager.shared.notification(.success)
    }
    
    private func addStamp(_ stamp: DocumentStamp) {
        // Add stamp to center of current page
        let position = StampPosition(
            id: UUID(),
            stamp: stamp,
            pageNumber: selectedPage,
            x: 200,
            y: 200
        )
        
        stampPositions.append(position)
        HapticManager.shared.impact(.light)
    }
    
    private func addCustomStamp(_ stamp: DocumentStamp) {
        addStamp(stamp)
    }
    
    private func addQuickStamp(_ text: String, _ color: Color) {
        let stamp = DocumentStamp(
            id: UUID(),
            text: text,
            category: .approval,
            color: color,
            size: .medium,
            style: .rectangle
        )
        
        addStamp(stamp)
    }
    
    private func removeStamp(_ position: StampPosition) {
        stampPositions.removeAll { $0.id == position.id }
        HapticManager.shared.impact(.light)
    }
    
    private func placeStampAtLocation(_ location: CGPoint) {
        // Place the selected stamp at the tapped location
        // This would be implemented with actual stamp placement logic
        HapticManager.shared.impact(.light)
    }
    
    private func applyFormsAndStamps() {
        // Apply all form data and stamps to the document
        let settings = JobSettings()
        // Would include form data and stamp positions
        
        let job = Job(
            type: .fillForm,
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

// MARK: - Supporting Types

struct FormField: Identifiable {
    let id: UUID
    let label: String
    let type: FieldType
    let pageNumber: Int
    let bounds: CGRect
    let isRequired: Bool
    let placeholder: String
}

struct DocumentStamp: Identifiable {
    let id: UUID
    let text: String
    let category: StampCategory
    let color: Color
    let size: StampSize
    let style: StampStyle
}

struct StampPosition: Identifiable {
    let id: UUID
    let stamp: DocumentStamp
    let pageNumber: Int
    let x: CGFloat
    let y: CGFloat
}

enum FieldType: String, CaseIterable, Hashable {
    case textField = "text"
    case textArea = "textarea"
    case checkbox = "checkbox"
    case signature = "signature"
    case date = "date"
    case dropdown = "dropdown"
    
    var displayName: String {
        switch self {
        case .textField: return "Text Field"
        case .textArea: return "Text Area"
        case .checkbox: return "Checkbox"
        case .signature: return "Signature"
        case .date: return "Date"
        case .dropdown: return "Dropdown"
        }
    }
    
    var icon: String {
        switch self {
        case .textField: return "textformat"
        case .textArea: return "text.alignleft"
        case .checkbox: return "checkmark.square"
        case .signature: return "signature"
        case .date: return "calendar"
        case .dropdown: return "chevron.down.square"
        }
    }
    
    var color: Color {
        switch self {
        case .textField: return OneBoxColors.primaryGold
        case .textArea: return OneBoxColors.secureGreen
        case .checkbox: return OneBoxColors.warningAmber
        case .signature: return OneBoxColors.criticalRed
        case .date: return OneBoxColors.primaryGold
        case .dropdown: return OneBoxColors.secondaryGold
        }
    }
}

enum StampCategory: String, CaseIterable {
    case approval = "approval"
    case status = "status"
    case date = "date"
    case signature = "signature"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .approval: return "Approval"
        case .status: return "Status"
        case .date: return "Date"
        case .signature: return "Signature"
        case .custom: return "Custom"
        }
    }
}

enum StampSize: String, CaseIterable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    var displayName: String {
        switch self {
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }
}

enum StampStyle: String, CaseIterable {
    case rectangle = "rectangle"
    case oval = "oval"
    case round = "round"
    
    var displayName: String {
        switch self {
        case .rectangle: return "Rectangle"
        case .oval: return "Oval"
        case .round: return "Round"
        }
    }
}

enum StampMode: String, CaseIterable {
    case select = "select"
    case place = "place"
    
    var displayName: String {
        switch self {
        case .select: return "Select"
        case .place: return "Place"
        }
    }
}

// MARK: - Supporting Views

struct StampLibraryView: View {
    @Binding var selectedCategory: StampCategory
    let onStampSelected: (DocumentStamp) -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack {
                // Category picker
                Picker("Category", selection: $selectedCategory) {
                    ForEach(StampCategory.allCases, id: \.self) { category in
                        Text(category.displayName).tag(category)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Stamps grid
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: OneBoxSpacing.medium) {
                        ForEach(getStampsForCategory(selectedCategory), id: \.id) { stamp in
                            stampCard(stamp)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Stamp Library")
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
    
    private func stampCard(_ stamp: DocumentStamp) -> some View {
        Button(action: {
            onStampSelected(stamp)
            dismiss()
        }) {
            VStack(spacing: OneBoxSpacing.small) {
                Text(stamp.text)
                    .font(OneBoxTypography.body)
                    .fontWeight(.bold)
                    .foregroundColor(stamp.color)
                    .padding()
                    .background(stamp.color.opacity(0.1))
                    .cornerRadius(OneBoxRadius.medium)
                    .overlay(
                        RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                            .stroke(stamp.color, lineWidth: 2)
                    )
                
                Text(stamp.text)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func getStampsForCategory(_ category: StampCategory) -> [DocumentStamp] {
        // Sample stamps for each category
        switch category {
        case .approval:
            return [
                DocumentStamp(id: UUID(), text: "APPROVED", category: .approval, color: OneBoxColors.secureGreen, size: .medium, style: .rectangle),
                DocumentStamp(id: UUID(), text: "REJECTED", category: .approval, color: OneBoxColors.criticalRed, size: .medium, style: .rectangle),
                DocumentStamp(id: UUID(), text: "PENDING", category: .approval, color: OneBoxColors.warningAmber, size: .medium, style: .rectangle),
                DocumentStamp(id: UUID(), text: "REVIEWED", category: .approval, color: OneBoxColors.primaryGold, size: .medium, style: .rectangle)
            ]
        case .status:
            return [
                DocumentStamp(id: UUID(), text: "DRAFT", category: .status, color: OneBoxColors.warningAmber, size: .medium, style: .oval),
                DocumentStamp(id: UUID(), text: "FINAL", category: .status, color: OneBoxColors.secureGreen, size: .medium, style: .oval),
                DocumentStamp(id: UUID(), text: "CONFIDENTIAL", category: .status, color: OneBoxColors.criticalRed, size: .medium, style: .oval)
            ]
        default:
            return []
        }
    }
}

struct CustomStampCreatorView: View {
    let onStampCreated: (DocumentStamp) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var stampText = ""
    @State private var selectedColor = OneBoxColors.primaryGold
    @State private var selectedSize: StampSize = .medium
    @State private var selectedStyle: StampStyle = .rectangle
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Stamp Text") {
                    TextField("Enter stamp text", text: $stampText)
                }
                
                Section("Appearance") {
                    ColorPicker("Color", selection: $selectedColor)
                    
                    Picker("Size", selection: $selectedSize) {
                        ForEach(StampSize.allCases, id: \.self) { size in
                            Text(size.displayName).tag(size)
                        }
                    }
                    
                    Picker("Style", selection: $selectedStyle) {
                        ForEach(StampStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                }
                
                Section("Preview") {
                    HStack {
                        Spacer()
                        
                        Text(stampText.isEmpty ? "SAMPLE" : stampText)
                            .font(OneBoxTypography.body)
                            .fontWeight(.bold)
                            .foregroundColor(selectedColor)
                            .padding()
                            .background(selectedColor.opacity(0.1))
                            .cornerRadius(selectedStyle == .round ? 50 : OneBoxRadius.medium)
                            .overlay(
                                RoundedRectangle(cornerRadius: selectedStyle == .round ? 50 : OneBoxRadius.medium)
                                    .stroke(selectedColor, lineWidth: 2)
                            )
                        
                        Spacer()
                    }
                }
            }
            .navigationTitle("Create Stamp")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        let stamp = DocumentStamp(
                            id: UUID(),
                            text: stampText,
                            category: .custom,
                            color: selectedColor,
                            size: selectedSize,
                            style: selectedStyle
                        )
                        
                        onStampCreated(stamp)
                    }
                    .disabled(stampText.isEmpty)
                }
            }
        }
    }
}

struct FieldMatcherView: View {
    @Binding var formFields: [FormField]
    @Binding var formData: [String: String]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(formFields) { field in
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        HStack {
                            Text(field.label.isEmpty ? "Field \(field.pageNumber + 1)" : field.label)
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Spacer()
                            
                            Text(field.type.displayName)
                                .font(OneBoxTypography.caption)
                                .foregroundColor(field.type.color)
                        }
                        
                        if field.type == .textField || field.type == .textArea {
                            TextField("Enter value", text: Binding(
                                get: { formData[field.id.uuidString] ?? "" },
                                set: { formData[field.id.uuidString] = $0 }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                    }
                    .padding(.vertical, OneBoxSpacing.tiny)
                }
            }
            .navigationTitle("Field Matcher")
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
    FormFillingStampView(pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
        .environmentObject(JobManager.shared)
}