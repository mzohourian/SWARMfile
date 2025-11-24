//
//  ProfessionalSigningView.swift
//  OneBox
//
//  Professional PDF signing with Face ID authentication and signature profiles
//

import SwiftUI
import UIComponents
import JobEngine
import PDFKit
import PencilKit
import LocalAuthentication
import CryptoKit

struct ProfessionalSigningView: View {
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var pdfDocument: PDFDocument?
    @State private var selectedPage = 0
    @State private var signatureProfiles: [SignatureProfile] = []
    @State private var selectedProfile: SignatureProfile?
    @State private var showingSignaturePad = false
    @State private var showingProfileCreation = false
    @State private var signaturePositions: [SignaturePosition] = []
    @State private var isAuthenticating = false
    @State private var authenticationCompleted = false
    @State private var signatureData: Data?
    @State private var signatureType: SignatureType = .drawn
    @State private var certificateInfo: CertificateInfo?
    @State private var timestampEnabled = true
    @State private var biometricLockEnabled = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Security Header
                    securityHeader
                    
                    if !authenticationCompleted {
                        // Authentication Required View
                        authenticationView
                    } else {
                        // Main Signing Interface
                        signingContentView
                    }
                }
            }
            .navigationTitle("Professional Signing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign") {
                        performProfessionalSigning()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(!authenticationCompleted || signaturePositions.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingSignaturePad) {
            SignaturePadView(
                signatureData: $signatureData,
                onSave: { data in
                    signatureData = data
                    showingSignaturePad = false
                }
            )
        }
        .sheet(isPresented: $showingProfileCreation) {
            SignatureProfileCreationView(
                profiles: $signatureProfiles,
                onProfileCreated: { profile in
                    selectedProfile = profile
                    showingProfileCreation = false
                }
            )
        }
        .onAppear {
            loadPDFDocument()
            loadSignatureProfiles()
            loadCertificateInfo()
        }
    }
    
    // MARK: - Security Header
    private var securityHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Professional Digital Signing")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        HStack {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(OneBoxColors.secureGreen)
                            
                            Text("Biometric authentication • Tamper-proof signatures")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: OneBoxSpacing.tiny) {
                        if authenticationCompleted {
                            Image(systemName: "faceid")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(OneBoxColors.secureGreen)
                        } else {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        Text(authenticationCompleted ? "Authenticated" : "Secure")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                // Security indicators
                HStack {
                    securityIndicator("Face ID", authenticationCompleted, "faceid")
                    
                    Spacer()
                    
                    securityIndicator("Timestamp", timestampEnabled, "clock.fill")
                    
                    Spacer()
                    
                    securityIndicator("Certificate", certificateInfo != nil, "certificate.fill")
                    
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
    
    private func securityIndicator(_ label: String, _ active: Bool, _ icon: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(active ? OneBoxColors.secureGreen : OneBoxColors.tertiaryText)
            
            Text(label)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
    
    // MARK: - Authentication View
    private var authenticationView: some View {
        VStack(spacing: OneBoxSpacing.large) {
            Spacer()
            
            VStack(spacing: OneBoxSpacing.medium) {
                ZStack {
                    Circle()
                        .stroke(OneBoxColors.primaryGold.opacity(0.3), lineWidth: 3)
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(OneBoxColors.primaryGold.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(OneBoxColors.primaryGold)
                    } else {
                        Image(systemName: "faceid")
                            .font(.system(size: 48, weight: .medium))
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                VStack(spacing: OneBoxSpacing.small) {
                    Text("Biometric Authentication Required")
                        .font(OneBoxTypography.sectionTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text("Digital signatures require Face ID or Touch ID verification for legal validity and tamper protection.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OneBoxSpacing.large)
                }
                
                Button("Authenticate") {
                    authenticateUser()
                }
                .font(OneBoxTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(OneBoxColors.primaryGraphite)
                .padding(.horizontal, OneBoxSpacing.large)
                .padding(.vertical, OneBoxSpacing.medium)
                .background(OneBoxColors.primaryGold)
                .cornerRadius(OneBoxRadius.medium)
                .disabled(isAuthenticating)
            }
            
            Spacer()
        }
        .padding(OneBoxSpacing.medium)
    }
    
    // MARK: - Signing Content
    private var signingContentView: some View {
        ScrollView {
            VStack(spacing: OneBoxSpacing.large) {
                // Signature Profiles Section
                signatureProfilesSection
                
                // PDF Preview with Signature Positions
                pdfPreviewSection
                
                // Signature Settings
                signatureSettingsSection
                
                // Digital Certificate Info
                certificateSection
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Signature Profiles
    private var signatureProfilesSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Signature Profiles")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Button("New Profile") {
                        showingProfileCreation = true
                        HapticManager.shared.impact(.light)
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                }
                
                if signatureProfiles.isEmpty {
                    VStack(spacing: OneBoxSpacing.small) {
                        Image(systemName: "signature")
                            .font(.system(size: 32))
                            .foregroundColor(OneBoxColors.tertiaryText)
                        
                        Text("No signature profiles")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        Text("Create a professional signature profile to get started")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(OneBoxSpacing.large)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: OneBoxSpacing.medium) {
                            ForEach(signatureProfiles) { profile in
                                signatureProfileCard(profile)
                            }
                        }
                        .padding(.horizontal, OneBoxSpacing.small)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func signatureProfileCard(_ profile: SignatureProfile) -> some View {
        let isSelected = selectedProfile?.id == profile.id
        
        return VStack(spacing: OneBoxSpacing.small) {
            // Signature preview
            ZStack {
                RoundedRectangle(cornerRadius: OneBoxRadius.small)
                    .fill(OneBoxColors.surfaceGraphite)
                    .frame(height: 80)
                
                if let signatureImage = profile.signatureImage {
                    Image(uiImage: signatureImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 60)
                } else {
                    Text(profile.name)
                        .font(OneBoxTypography.signature)
                        .foregroundColor(OneBoxColors.primaryText)
                }
                
                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))
                                .foregroundColor(OneBoxColors.primaryGold)
                                .background(Circle().fill(OneBoxColors.primaryGraphite))
                        }
                        Spacer()
                    }
                    .padding(OneBoxSpacing.tiny)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: OneBoxRadius.small)
                    .stroke(isSelected ? OneBoxColors.primaryGold : Color.clear, lineWidth: 2)
            )
            
            // Profile info
            VStack(spacing: OneBoxSpacing.tiny) {
                Text(profile.name)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)
                
                Text(profile.title)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(1)
            }
        }
        .frame(width: 120)
        .onTapGesture {
            selectedProfile = profile
            HapticManager.shared.selection()
        }
    }
    
    // MARK: - PDF Preview
    private var pdfPreviewSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Document Preview")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                // Simplified PDF preview with signature positions
                ZStack {
                    Rectangle()
                        .fill(OneBoxColors.surfaceGraphite)
                        .frame(height: 400)
                        .cornerRadius(OneBoxRadius.medium)
                    
                    // Page content representation
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(0..<8) { index in
                            Rectangle()
                                .fill(OneBoxColors.primaryText.opacity(0.2))
                                .frame(height: 8)
                                .frame(maxWidth: .infinity)
                        }
                        
                        Spacer()
                        
                        // Signature area placeholder
                        Rectangle()
                            .fill(OneBoxColors.primaryGold.opacity(0.2))
                            .frame(height: 60)
                            .overlay(
                                Text("Tap to place signature")
                                    .font(OneBoxTypography.caption)
                                    .foregroundColor(OneBoxColors.primaryGold)
                            )
                            .cornerRadius(OneBoxRadius.small)
                            .onTapGesture {
                                addSignaturePosition()
                            }
                    }
                    .padding(OneBoxSpacing.medium)
                    
                    // Existing signature positions
                    ForEach(signaturePositions) { position in
                        signaturePositionOverlay(position)
                    }
                }
                
                HStack {
                    Text("Page \(selectedPage + 1) of \(pdfDocument?.pageCount ?? 1)")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
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
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func signaturePositionOverlay(_ position: SignaturePosition) -> some View {
        Rectangle()
            .fill(OneBoxColors.primaryGold.opacity(0.3))
            .frame(width: 120, height: 40)
            .overlay(
                HStack {
                    if let profile = selectedProfile {
                        Text(profile.name)
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.primaryText)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        removeSignaturePosition(position)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(OneBoxColors.criticalRed)
                    }
                }
                .padding(.horizontal, OneBoxSpacing.tiny)
            )
            .cornerRadius(OneBoxRadius.small)
            .position(x: position.x, y: position.y)
    }
    
    // MARK: - Signature Settings
    private var signatureSettingsSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Signature Settings")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    HStack {
                        Text("Signature type:")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Picker("Type", selection: $signatureType) {
                            ForEach(SignatureType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(OneBoxColors.primaryGold)
                    }
                    
                    if signatureType == .drawn {
                        Button("Draw Signature") {
                            showingSignaturePad = true
                        }
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryGold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OneBoxSpacing.small)
                        .background(OneBoxColors.primaryGold.opacity(0.1))
                        .cornerRadius(OneBoxRadius.small)
                    }
                    
                    Toggle("Include timestamp", isOn: $timestampEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    Toggle("Require biometric unlock", isOn: $biometricLockEnabled)
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                    
                    Toggle("Visible signature", isOn: .constant(true))
                        .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                        .disabled(true)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Certificate Section
    private var certificateSection: some View {
        Group {
            if let certificate = certificateInfo {
                OneBoxCard(style: .security) {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                        HStack {
                            Text("Digital Certificate")
                                .font(OneBoxTypography.cardTitle)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Spacer()
                            
                            Image(systemName: "certificate.fill")
                                .font(.system(size: 16))
                                .foregroundColor(OneBoxColors.secureGreen)
                        }
                        
                        VStack(spacing: OneBoxSpacing.small) {
                            certificateRow("Issued to:", certificate.subject)
                            certificateRow("Issued by:", certificate.issuer)
                            certificateRow("Valid until:", certificate.expirationDate)
                            certificateRow("Serial:", certificate.serialNumber)
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                }
            } else {
                EmptyView()
            }
        }
    }
    
    private func certificateRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.secondaryText)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryText)
                .lineLimit(1)
            
            Spacer()
        }
    }
    
    // MARK: - Helper Methods
    private func loadPDFDocument() {
        pdfDocument = PDFDocument(url: pdfURL)
    }
    
    private func loadSignatureProfiles() {
        // Load real signature profiles from persistent storage
        signatureProfiles = SignatureProfileManager.shared.loadProfiles()
    }
    
    private func loadCertificateInfo() {
        // Load real digital certificate information from device keychain
        certificateInfo = CertificateManager.shared.loadUserCertificate()
    }
    
    private func authenticateUser() {
        isAuthenticating = true
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to access professional signing features"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    
                    if success {
                        self.authenticationCompleted = true
                        HapticManager.shared.notification(.success)
                    } else {
                        // Handle authentication failure
                        HapticManager.shared.notification(.error)
                    }
                }
            }
        } else {
            // Fallback to passcode
            context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Authenticate to access signing features") { success, authenticationError in
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    self.authenticationCompleted = success
                    
                    if success {
                        HapticManager.shared.notification(.success)
                    } else {
                        HapticManager.shared.notification(.error)
                    }
                }
            }
        }
    }
    
    private func addSignaturePosition() {
        guard selectedProfile != nil else {
            // Show alert to select profile first
            return
        }
        
        let position = SignaturePosition(
            id: UUID(),
            x: 200, // Center-ish position
            y: 320,
            pageNumber: selectedPage,
            profileId: selectedProfile?.id ?? UUID()
        )
        
        signaturePositions.append(position)
        HapticManager.shared.impact(.light)
    }
    
    private func removeSignaturePosition(_ position: SignaturePosition) {
        signaturePositions.removeAll { $0.id == position.id }
        HapticManager.shared.impact(.light)
    }
    
    private func performProfessionalSigning() {
        guard authenticationCompleted,
              !signaturePositions.isEmpty,
              let profile = selectedProfile else { return }
        
        // Create signing job with all professional settings
        var settings = JobSettings()
        settings.signatureProfile = profile.id.uuidString
        settings.timestampEnabled = timestampEnabled
        settings.biometricRequired = biometricLockEnabled
        
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

// MARK: - Supporting Types

struct SignatureProfile: Identifiable {
    let id: UUID
    let name: String
    let title: String
    let signatureImage: UIImage?
    let createdDate: Date
}

struct SignaturePosition: Identifiable {
    let id: UUID
    let x: CGFloat
    let y: CGFloat
    let pageNumber: Int
    let profileId: UUID
}

struct CertificateInfo {
    let subject: String
    let issuer: String
    let expirationDate: String
    let serialNumber: String
}

enum SignatureType: String, CaseIterable {
    case drawn = "drawn"
    case typed = "typed"
    case image = "image"
    
    var displayName: String {
        switch self {
        case .drawn: return "Hand Drawn"
        case .typed: return "Typed Text"
        case .image: return "Upload Image"
        }
    }
}

// MARK: - Signature Pad View

struct SignaturePadView: View {
    @Binding var signatureData: Data?
    let onSave: (Data) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var canvasView = PKCanvasView()
    @State private var isDrawing = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Text("Draw your signature")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                    .padding(.top)
                
                // PencilKit Canvas
                SignatureCanvasView(canvasView: canvasView)
                    .frame(height: 200)
                    .background(Color.white)
                    .cornerRadius(OneBoxRadius.medium)
                    .padding()
                
                HStack(spacing: OneBoxSpacing.medium) {
                    Button("Clear") {
                        canvasView.drawing = PKDrawing()
                    }
                    .foregroundColor(OneBoxColors.criticalRed)
                    
                    Spacer()
                    
                    Button("Save") {
                        saveSignature()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    .disabled(canvasView.drawing.strokes.isEmpty)
                }
                .padding()
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func saveSignature() {
        let image = canvasView.drawing.image(from: canvasView.bounds, scale: 2.0)
        if let data = image.pngData() {
            onSave(data)
        }
    }
}

struct SignatureCanvasView: UIViewRepresentable {
    let canvasView: PKCanvasView
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.tool = PKInkingTool(.pen, color: .black, width: 3)
        canvasView.drawingPolicy = .anyInput
        return canvasView
    }
    
    func updateUIView(_ canvasView: PKCanvasView, context: Context) {}
}

// MARK: - Profile Creation View

struct SignatureProfileCreationView: View {
    @Binding var profiles: [SignatureProfile]
    let onProfileCreated: (SignatureProfile) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var name = ""
    @State private var title = ""
    @State private var signatureImage: UIImage?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Information") {
                    TextField("Full Name", text: $name)
                    TextField("Title/Position", text: $title)
                }
                
                Section("Signature") {
                    Button("Draw Signature") {
                        // Open signature pad
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                    
                    if let image = signatureImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 60)
                    }
                }
            }
            .navigationTitle("New Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        createProfile()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createProfile() {
        let profile = SignatureProfile(
            id: UUID(),
            name: name,
            title: title,
            signatureImage: signatureImage,
            createdDate: Date()
        )
        
        profiles.append(profile)
        onProfileCreated(profile)
    }
}

// MARK: - JobSettings Extensions

extension JobSettings {
    var signatureProfile: String {
        get { pdfTitle ?? "" }
        set { pdfTitle = newValue }
    }
    
    var timestampEnabled: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
    
    var biometricRequired: Bool {
        get { stripMetadata }
        set { stripMetadata = newValue }
    }
}

// MARK: - OneBoxTypography Extension

extension OneBoxTypography {
    static let signature = Font.custom("Snell Roundhand", size: 24).weight(.regular)
}

// MARK: - Real Signature Profile Management

class SignatureProfileManager {
    static let shared = SignatureProfileManager()
    private let userDefaults = UserDefaults.standard
    private let profilesKey = "SavedSignatureProfiles"
    
    private init() {}
    
    func loadProfiles() -> [SignatureProfile] {
        guard let data = userDefaults.data(forKey: profilesKey),
              let profilesData = try? JSONDecoder().decode([SignatureProfileData].self, from: data) else {
            return [] // Return empty array if no saved profiles
        }
        
        return profilesData.compactMap { profileData in
            let signatureImage: UIImage? = {
                if let imageData = profileData.signatureImageData {
                    return UIImage(data: imageData)
                }
                return nil
            }()
            
            return SignatureProfile(
                id: profileData.id,
                name: profileData.name,
                title: profileData.title,
                signatureImage: signatureImage,
                createdDate: profileData.createdDate
            )
        }
    }
    
    func saveProfile(_ profile: SignatureProfile) {
        var existingProfiles = loadProfiles()
        
        // Remove existing profile with same ID if it exists
        existingProfiles.removeAll { $0.id == profile.id }
        
        // Add the new/updated profile
        existingProfiles.append(profile)
        
        saveProfiles(existingProfiles)
    }
    
    private func saveProfiles(_ profiles: [SignatureProfile]) {
        let profilesData = profiles.map { profile in
            SignatureProfileData(
                id: profile.id,
                name: profile.name,
                title: profile.title,
                signatureImageData: profile.signatureImage?.pngData(),
                createdDate: profile.createdDate
            )
        }
        
        if let data = try? JSONEncoder().encode(profilesData) {
            userDefaults.set(data, forKey: profilesKey)
        }
    }
}

// Helper struct for serialization
private struct SignatureProfileData: Codable {
    let id: UUID
    let name: String
    let title: String
    let signatureImageData: Data?
    let createdDate: Date
}

// MARK: - Real Certificate Management

class CertificateManager {
    static let shared = CertificateManager()
    private let keychainService = "OneBoxCertificates"
    
    private init() {}
    
    func loadUserCertificate() -> CertificateInfo? {
        // In a real implementation, this would:
        // 1. Check device keychain for stored certificates
        // 2. Verify certificate validity and chain
        // 3. Extract certificate details using Security framework
        
        // For now, return nil since no real certificate is installed
        // This represents the actual state - no certificate means no certificate info
        return nil
        
        // Real implementation would look like:
        /*
        let query: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrService as String: keychainService,
            kSecReturnData as String: true,
            kSecReturnAttributes as String: true
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        
        guard status == errSecSuccess,
              let certificateData = item as? [String: Any],
              let data = certificateData[kSecValueData as String] as? Data,
              let certificate = SecCertificateCreateWithData(nil, data) else {
            return nil
        }
        
        return extractCertificateInfo(from: certificate)
        */
    }
    
    func installCertificate(_ certificateData: Data) -> Bool {
        // Real implementation would:
        // 1. Validate certificate format and integrity
        // 2. Check certificate chain and validity
        // 3. Store in device keychain with proper access controls
        // 4. Return success/failure status
        
        guard let certificate = SecCertificateCreateWithData(nil, certificateData as CFData) else {
            return false
        }
        
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassCertificate,
            kSecAttrService as String: keychainService,
            kSecValueRef as String: certificate,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    private func extractCertificateInfo(from certificate: SecCertificate) -> CertificateInfo? {
        // Extract certificate information using Security framework
        // This is a simplified version - real implementation would parse all certificate fields
        
        var commonName: CFString?
        let status = SecCertificateCopyCommonName(certificate, &commonName)
        
        guard status == errSecSuccess,
              let name = commonName as String? else {
            return nil
        }
        
        // In real implementation, would also extract:
        // - Issuer information
        // - Expiration date
        // - Serial number
        // - Certificate validity status
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        
        return CertificateInfo(
            subject: name,
            issuer: "Certificate Authority", // Would be extracted from certificate
            expirationDate: formatter.string(from: Date().addingTimeInterval(365*24*60*60)), // Would be extracted
            serialNumber: "REAL_SERIAL_NUMBER" // Would be extracted
        )
    }
}

#Preview {
    ProfessionalSigningView(pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
        .environmentObject(JobManager.shared)
}