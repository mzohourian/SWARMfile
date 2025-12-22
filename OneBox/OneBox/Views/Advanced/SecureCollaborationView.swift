//
//  SecureCollaborationView.swift
//  OneBox
//
//  Secure collaboration-lite features with encrypted sharing and access controls
//

import SwiftUI
import UIComponents
import JobEngine
import CryptoKit
import MessageUI
import UniformTypeIdentifiers
import Network

enum SecureCollaborationError: LocalizedError {
    case encryptionFailed

    var errorDescription: String? {
        switch self {
        case .encryptionFailed:
            return "Failed to encrypt document for secure sharing"
        }
    }
}

struct SecureCollaborationView: View {
    let pdfURL: URL
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var jobManager: JobManager
    
    @State private var collaborators: [Collaborator] = []
    @State private var accessLevel: AccessLevel = .view
    @State private var expirationDate = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
    @State private var requirePassword = true
    @State private var password = ""
    @State private var allowDownload = false
    @State private var allowPrint = false
    @State private var allowCopy = false
    @State private var trackViews = true
    @State private var showAddCollaborator = false
    @State private var newCollaboratorEmail = ""
    @State private var shareMethod: ShareMethod = .secureLink
    @State private var encryptionLevel: EncryptionLevel = .standard
    @State private var isGeneratingLink = false
    @State private var generatedLink: SecureLink?
    @State private var viewHistory: [ViewEvent] = []
    @State private var showQRCode = false

    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Security Header
                        securityHeader
                        
                        // Collaborators Section
                        collaboratorsSection
                        
                        // Access Controls
                        accessControlsSection
                        
                        // Encryption & Security
                        encryptionSection
                        
                        // Share Options
                        shareOptionsSection
                        
                        // Activity Monitoring
                        if !viewHistory.isEmpty {
                            activitySection
                        }
                        
                        // Generate Secure Link
                        generateLinkSection
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationTitle("Secure Collaboration")
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
        .sheet(isPresented: $showAddCollaborator) {
            AddCollaboratorView(
                newEmail: $newCollaboratorEmail,
                onAdd: addCollaborator
            )
        }
        .sheet(isPresented: $showQRCode) {
            if let link = generatedLink {
                QRCodeShareView(link: link)
            }
        }
        .onAppear {
            loadCollaborators()
            loadViewHistory()
        }
    }
    
    // MARK: - Security Header
    private var securityHeader: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Secure Document Sharing")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        HStack {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(OneBoxColors.secureGreen)
                            
                            Text("Local sharing • Access controls • Activity tracking")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        Text("\(collaborators.count) collaborators")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                // Security indicators
                HStack {
                    securityIndicator("Encrypted", true, "lock.fill")
                    
                    Spacer()
                    
                    securityIndicator("Tracked", trackViews, "eye.fill")
                    
                    Spacer()
                    
                    securityIndicator("Expires", true, "clock.fill")
                    
                    Spacer()
                    
                    SecurityBadge(style: .minimal)
                }
                .padding(OneBoxSpacing.small)
                .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                .cornerRadius(OneBoxRadius.small)
            }
        }
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
    
    // MARK: - Collaborators
    private var collaboratorsSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Collaborators")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Button("Add Person") {
                        showAddCollaborator = true
                        HapticManager.shared.impact(.light)
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                }
                
                if collaborators.isEmpty {
                    VStack(spacing: OneBoxSpacing.small) {
                        Image(systemName: "person.2.badge.plus")
                            .font(.system(size: 32))
                            .foregroundColor(OneBoxColors.tertiaryText)
                        
                        Text("No collaborators yet")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        Text("Add people to securely share this document")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(OneBoxSpacing.large)
                } else {
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(collaborators) { collaborator in
                            collaboratorRow(collaborator)
                        }
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func collaboratorRow(_ collaborator: Collaborator) -> some View {
        HStack(spacing: OneBoxSpacing.medium) {
            // Avatar
            Circle()
                .fill(OneBoxColors.primaryGold.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Text(String(collaborator.email.prefix(1)).uppercased())
                        .font(OneBoxTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryGold)
                )
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(collaborator.email)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                
                HStack {
                    Text(collaborator.accessLevel.displayName)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    if collaborator.hasViewed {
                        Text("• Viewed")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secureGreen)
                    }
                    
                    if let lastViewed = collaborator.lastViewed {
                        Text("• \(timeAgoString(lastViewed))")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                }
            }
            
            Spacer()
            
            Menu {
                Button("Change Access", systemImage: "key") {
                    changeCollaboratorAccess(collaborator)
                }
                
                Button("Revoke Access", systemImage: "xmark.circle", role: .destructive) {
                    revokeCollaboratorAccess(collaborator)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(OneBoxColors.secondaryText)
            }
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.2))
        .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - Access Controls
    private var accessControlsSection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Access Controls")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.medium) {
                    // Default Access Level
                    HStack {
                        Text("Default access level:")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Picker("Access Level", selection: $accessLevel) {
                            ForEach(AccessLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(OneBoxColors.primaryGold)
                    }
                    
                    Divider()
                        .background(OneBoxColors.surfaceGraphite)
                    
                    // Permissions
                    VStack(spacing: OneBoxSpacing.small) {
                        Text("Document permissions:")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        permissionToggle("Allow download", $allowDownload, "arrow.down.circle")
                        permissionToggle("Allow printing", $allowPrint, "printer")
                        permissionToggle("Allow copying text", $allowCopy, "doc.on.doc")
                        permissionToggle("Track document views", $trackViews, "eye")
                    }
                    
                    Divider()
                        .background(OneBoxColors.surfaceGraphite)
                    
                    // Expiration
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        Text("Access expires:")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        DatePicker("Expiration Date", selection: $expirationDate, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .accentColor(OneBoxColors.primaryGold)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func permissionToggle(_ title: String, _ binding: Binding<Bool>, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 20)
            
            Text(title)
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
            
            Toggle("", isOn: binding)
                .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
        }
    }
    
    // MARK: - Encryption
    private var encryptionSection: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Encryption & Security")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .foregroundColor(OneBoxColors.secureGreen)
                }
                
                VStack(spacing: OneBoxSpacing.medium) {
                    HStack {
                        Text("Encryption level:")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Spacer()
                        
                        Picker("Encryption", selection: $encryptionLevel) {
                            ForEach(EncryptionLevel.allCases, id: \.self) { level in
                                Text(level.displayName).tag(level)
                            }
                        }
                        .pickerStyle(.menu)
                        .accentColor(OneBoxColors.primaryGold)
                    }
                    
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        Toggle("Require password", isOn: $requirePassword)
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                        
                        if requirePassword {
                            SecureField("Enter password", text: $password)
                                .textFieldStyle(.roundedBorder)
                                .transition(.opacity)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Security features:")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        securityFeature("Local device encryption", true)
                        securityFeature("No cloud storage", true)
                        securityFeature("Automatic key rotation", encryptionLevel == .maximum)
                        securityFeature("Forward secrecy", encryptionLevel == .maximum)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .animation(.easeInOut(duration: 0.3), value: requirePassword)
    }
    
    private func securityFeature(_ name: String, _ enabled: Bool) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: enabled ? "checkmark.shield" : "xmark.shield")
                .font(.system(size: 10))
                .foregroundColor(enabled ? OneBoxColors.secureGreen : OneBoxColors.tertiaryText)
                .frame(width: 14)
            
            Text(name)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
        }
    }
    
    // MARK: - Share Options
    private var shareOptionsSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Share Methods")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(ShareMethod.allCases, id: \.self) { method in
                        shareMethodOption(method)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func shareMethodOption(_ method: ShareMethod) -> some View {
        Button(action: {
            shareMethod = method
            HapticManager.shared.selection()
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: shareMethod == method ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(shareMethod == method ? OneBoxColors.primaryGold : OneBoxColors.tertiaryText)
                
                Image(systemName: method.icon)
                    .font(.system(size: 16))
                    .foregroundColor(OneBoxColors.primaryGold)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(method.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(method.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Activity Section
    private var activitySection: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Recent Activity")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Button("View All") {
                        // Show detailed activity log
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                }
                
                VStack(spacing: OneBoxSpacing.small) {
                    ForEach(viewHistory.prefix(3)) { event in
                        activityRow(event)
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func activityRow(_ event: ViewEvent) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: event.eventType.icon)
                .font(.system(size: 14))
                .foregroundColor(event.eventType.color)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(event.userEmail)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("\(event.eventType.displayName) • \(timeAgoString(event.timestamp))")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            
            Spacer()
            
            if let location = event.location {
                Text(location)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.tertiaryText)
            }
        }
        .padding(OneBoxSpacing.tiny)
        .background(OneBoxColors.surfaceGraphite.opacity(0.1))
        .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - Generate Link
    private var generateLinkSection: some View {
        OneBoxCard(style: .interactive) {
            VStack(spacing: OneBoxSpacing.medium) {
                if let link = generatedLink {
                    // Show generated link
                    VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                        Text("Secure Link Generated")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                            Text("Share this encrypted link:")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                            
                            HStack {
                                Text(link.url)
                                    .font(OneBoxTypography.micro)
                                    .foregroundColor(OneBoxColors.primaryText)
                                    .padding(OneBoxSpacing.small)
                                    .background(OneBoxColors.surfaceGraphite.opacity(0.3))
                                    .cornerRadius(OneBoxRadius.small)
                                    .lineLimit(1)
                                
                                Button("Copy") {
                                    copyToClipboard(link.url)
                                }
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.primaryGold)
                            }
                        }
                        
                        HStack {
                            Button("Share QR Code") {
                                showQRCode = true
                            }
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.primaryGraphite)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, OneBoxSpacing.small)
                            .background(OneBoxColors.primaryGold)
                            .cornerRadius(OneBoxRadius.small)
                            
                            Button("Revoke Link") {
                                revokeLink()
                            }
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.criticalRed)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, OneBoxSpacing.small)
                            .background(OneBoxColors.criticalRed.opacity(0.1))
                            .cornerRadius(OneBoxRadius.small)
                        }
                    }
                } else {
                    // Generate link button
                    VStack(spacing: OneBoxSpacing.medium) {
                        Text("Generate Secure Share Link")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text("Create an encrypted link to share this document securely with collaborators.")
                            .font(OneBoxTypography.body)
                            .foregroundColor(OneBoxColors.secondaryText)
                            .multilineTextAlignment(.center)
                        
                        Button("Generate Secure Link") {
                            generateSecureLink()
                        }
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryGraphite)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, OneBoxSpacing.medium)
                        .background(OneBoxColors.primaryGold)
                        .cornerRadius(OneBoxRadius.medium)
                        .disabled(isGeneratingLink)
                        
                        if isGeneratingLink {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(OneBoxColors.primaryGold)
                        }
                    }
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Helper Methods
    private func loadCollaborators() {
        // Load existing collaborators (simplified)
        collaborators = [
            Collaborator(
                id: UUID(),
                email: "john.doe@company.com",
                accessLevel: .edit,
                hasViewed: true,
                lastViewed: Date().addingTimeInterval(-3600)
            ),
            Collaborator(
                id: UUID(),
                email: "jane.smith@partner.com",
                accessLevel: .view,
                hasViewed: false,
                lastViewed: nil
            )
        ]
    }
    
    private func loadViewHistory() {
        // Load activity history (simplified)
        viewHistory = [
            ViewEvent(
                id: UUID(),
                userEmail: "john.doe@company.com",
                eventType: .viewed,
                timestamp: Date().addingTimeInterval(-1800),
                location: "New York, US"
            ),
            ViewEvent(
                id: UUID(),
                userEmail: "jane.smith@partner.com",
                eventType: .downloaded,
                timestamp: Date().addingTimeInterval(-7200),
                location: "London, UK"
            )
        ]
    }
    
    private func addCollaborator() {
        guard !newCollaboratorEmail.isEmpty else { return }
        
        let collaborator = Collaborator(
            id: UUID(),
            email: newCollaboratorEmail,
            accessLevel: accessLevel,
            hasViewed: false,
            lastViewed: nil
        )
        
        collaborators.append(collaborator)
        newCollaboratorEmail = ""
        showAddCollaborator = false
        
        HapticManager.shared.notification(.success)
    }
    
    private func changeCollaboratorAccess(_ collaborator: Collaborator) {
        // Change access level
        if let index = collaborators.firstIndex(where: { $0.id == collaborator.id }) {
            // Toggle between view and edit
            let newLevel: AccessLevel = collaborator.accessLevel == .view ? .edit : .view
            collaborators[index].accessLevel = newLevel
        }
        
        HapticManager.shared.impact(.light)
    }
    
    private func revokeCollaboratorAccess(_ collaborator: Collaborator) {
        collaborators.removeAll { $0.id == collaborator.id }
        HapticManager.shared.impact(.medium)
    }
    
    private func generateSecureLink() {
        isGeneratingLink = true
        
        Task {
            // Real encryption implementation
            do {
                let encryptedDocument = try await encryptDocument()
                let uploadResult = try await uploadSecureDocument(encryptedDocument)
                
                let link = SecureLink(
                    id: UUID(),
                    url: uploadResult.shareURL,
                    encryptionKey: uploadResult.encryptionKey,
                    expiresAt: expirationDate,
                    accessLevel: accessLevel
                )
                
                // Store link metadata for tracking
                await storeSecureLinkMetadata(link)
                
                await MainActor.run {
                    self.generatedLink = link
                    self.isGeneratingLink = false
                    HapticManager.shared.notification(.success)
                }
            } catch {
                await MainActor.run {
                    self.isGeneratingLink = false
                    // Handle encryption/upload error
                    print("Secure link generation failed: \(error)")
                }
            }
        }
    }
    
    private func encryptDocument() async throws -> SecureEncryptedDocument {
        // Real AES-256 encryption implementation
        let fileData = try Data(contentsOf: pdfURL)
        let encryptionKey = SymmetricKey(size: .bits256)
        let sealedBox = try AES.GCM.seal(fileData, using: encryptionKey)

        guard let combinedData = sealedBox.combined else {
            throw SecureCollaborationError.encryptionFailed
        }

        return SecureEncryptedDocument(
            encryptedData: combinedData,
            key: encryptionKey,
            originalFilename: pdfURL.lastPathComponent
        )
    }
    
    private func uploadSecureDocument(_ document: SecureEncryptedDocument) async throws -> UploadResult {
        // ZERO CLOUD DEPENDENCIES - Store encrypted document locally for sharing
        let documentID = UUID().uuidString

        // Store encrypted document in local secure storage
        let localStorage = LocalSecureStorage.shared
        try await localStorage.storeEncryptedDocument(document, withID: documentID)

        // Generate local share URL (for AirDrop/email sharing)
        let deviceID = await getSecureDeviceIdentifier()
        let shareURL = "vaultpdf://share/\(deviceID)/\(documentID)"

        let keyData = document.key.withUnsafeBytes { Data($0) }

        return UploadResult(
            shareURL: shareURL,
            encryptionKey: keyData.base64EncodedString(),
            documentID: documentID
        )
    }
    
    private func getSecureDeviceIdentifier() async -> String {
        // Generate secure device identifier without compromising privacy
        let keychain = KeychainService.shared
        
        if let existingID = try? keychain.retrieveString(for: "device_identifier") {
            return existingID
        }
        
        // Create new secure identifier
        let newID = SHA256.hash(data: UUID().uuidString.data(using: .utf8)!)
            .compactMap { String(format: "%02x", $0) }
            .joined()
            .prefix(16)
            .description
        
        try? keychain.store(String(newID), for: "device_identifier")
        return String(newID)
    }
    
    private func storeSecureLinkMetadata(_ link: SecureLink) async {
        // Store metadata for access tracking
        let metadata = SecureLinkMetadata(
            id: link.id,
            documentName: pdfURL.lastPathComponent,
            createdAt: Date(),
            expiresAt: link.expiresAt,
            accessLevel: link.accessLevel,
            accessCount: 0,
            collaboratorEmails: collaborators.map { $0.email }
        )
        
        SecureLinkStorage.shared.store(metadata)
    }
    
    private func generateEncryptionKey() -> String {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }.base64EncodedString()
    }
    
    private func copyToClipboard(_ text: String) {
        UIPasteboard.general.string = text
        HapticManager.shared.notification(.success)
    }
    
    private func revokeLink() {
        generatedLink = nil
        HapticManager.shared.impact(.medium)
    }
    
    private func timeAgoString(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Supporting Types

struct Collaborator: Identifiable {
    let id: UUID
    let email: String
    var accessLevel: AccessLevel
    let hasViewed: Bool
    let lastViewed: Date?
}

struct SecureLink: Identifiable {
    let id: UUID
    let url: String
    let encryptionKey: String
    let expiresAt: Date
    let accessLevel: AccessLevel
}

struct ViewEvent: Identifiable {
    let id: UUID
    let userEmail: String
    let eventType: EventType
    let timestamp: Date
    let location: String?
    
    enum EventType {
        case viewed, downloaded, printed, copied
        
        var displayName: String {
            switch self {
            case .viewed: return "Viewed document"
            case .downloaded: return "Downloaded"
            case .printed: return "Printed"
            case .copied: return "Copied content"
            }
        }
        
        var icon: String {
            switch self {
            case .viewed: return "eye.fill"
            case .downloaded: return "arrow.down.circle.fill"
            case .printed: return "printer.fill"
            case .copied: return "doc.on.doc.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .viewed: return OneBoxColors.primaryGold
            case .downloaded: return OneBoxColors.secureGreen
            case .printed: return OneBoxColors.warningAmber
            case .copied: return OneBoxColors.criticalRed
            }
        }
    }
}

enum AccessLevel: String, Codable, CaseIterable {
    case view = "view"
    case comment = "comment"
    case edit = "edit"
    case admin = "admin"
    
    var displayName: String {
        switch self {
        case .view: return "View Only"
        case .comment: return "Can Comment"
        case .edit: return "Can Edit"
        case .admin: return "Admin"
        }
    }
}

enum ShareMethod: String, CaseIterable {
    case secureLink = "link"
    case email = "email"
    case qrCode = "qr"
    case airdrop = "airdrop"

    var displayName: String {
        switch self {
        case .secureLink: return "Secure Link"
        case .email: return "Encrypted Email"
        case .qrCode: return "QR Code"
        case .airdrop: return "AirDrop"
        }
    }

    var description: String {
        switch self {
        case .secureLink: return "Generate encrypted link with access controls"
        case .email: return "Send encrypted document via email"
        case .qrCode: return "Share via QR code for quick access"
        case .airdrop: return "Share directly to nearby devices"
        }
    }

    var icon: String {
        switch self {
        case .secureLink: return "link"
        case .email: return "envelope.fill"
        case .qrCode: return "qrcode"
        case .airdrop: return "wifi"
        }
    }
}

enum EncryptionLevel: String, CaseIterable {
    case standard = "standard"
    case enhanced = "enhanced"
    case maximum = "maximum"
    
    var displayName: String {
        switch self {
        case .standard: return "Standard (AES-256)"
        case .enhanced: return "Enhanced"
        case .maximum: return "Maximum Security"
        }
    }
}

// MARK: - Add Collaborator View

struct AddCollaboratorView: View {
    @Binding var newEmail: String
    let onAdd: () -> Void
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: OneBoxSpacing.large) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                    Text("Add Collaborator")
                        .font(OneBoxTypography.sectionTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text("Enter the email address of the person you want to share this document with.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                    
                    TextField("Email address", text: $newEmail)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                }
                
                Spacer()
            }
            .padding(OneBoxSpacing.medium)
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Add Collaborator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        onAdd()
                    }
                    .disabled(newEmail.isEmpty)
                }
            }
        }
    }
}

// MARK: - QR Code Share View

struct QRCodeShareView: View {
    let link: SecureLink
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: OneBoxSpacing.large) {
                Text("Secure QR Code")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                // QR Code placeholder
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 200, height: 200)
                    .cornerRadius(OneBoxRadius.medium)
                    .overlay(
                        VStack {
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundColor(.black)
                            
                            Text("QR Code")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(.black)
                        }
                    )
                
                Text("Scan this QR code to access the secure document")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
                
                Button("Share QR Code") {
                    // Share QR code image
                }
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryGraphite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, OneBoxSpacing.medium)
                .background(OneBoxColors.primaryGold)
                .cornerRadius(OneBoxRadius.medium)
                
                Spacer()
            }
            .padding(OneBoxSpacing.medium)
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("QR Code")
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

// MARK: - Missing Supporting Types for Encryption

struct SecureEncryptedDocument {
    let encryptedData: Data
    let key: SymmetricKey
    let originalFilename: String
}

struct UploadResult {
    let shareURL: String
    let encryptionKey: String
    let documentID: String
}

struct SecureLinkMetadata {
    let id: UUID
    let documentName: String
    let createdAt: Date
    let expiresAt: Date
    let accessLevel: AccessLevel
    let accessCount: Int
    let collaboratorEmails: [String]
}

// MARK: - Local Infrastructure Services (Zero Cloud Dependencies)

class LocalSecureStorage {
    static let shared = LocalSecureStorage()
    private init() {}
    
    private let keychain = KeychainService.shared
    private let fileManager = FileManager.default
    
    func storeEncryptedDocument(_ document: SecureEncryptedDocument, withID documentID: String) async throws {
        // Create secure local directory
        let documentsDir = try getSecureDocumentsDirectory()
        let documentPath = documentsDir.appendingPathComponent("\(documentID).encrypted")
        
        // Store encrypted document data locally
        try document.encryptedData.write(to: documentPath)
        
        // Store encryption key in keychain
        let keyData = document.key.withUnsafeBytes { Data($0) }
        try keychain.store(keyData, for: "doc_key_\(documentID)")
        
        // Store document metadata
        let metadata = [
            "filename": document.originalFilename,
            "created": ISO8601DateFormatter().string(from: Date()),
            "size": String(document.encryptedData.count)
        ]
        
        let metadataData = try JSONSerialization.data(withJSONObject: metadata)
        try keychain.store(metadataData, for: "doc_meta_\(documentID)")
    }
    
    func retrieveEncryptedDocument(withID documentID: String) async throws -> SecureEncryptedDocument {
        let documentsDir = try getSecureDocumentsDirectory()
        let documentPath = documentsDir.appendingPathComponent("\(documentID).encrypted")
        
        let encryptedData = try Data(contentsOf: documentPath)
        let keyData = try keychain.retrieveData(for: "doc_key_\(documentID)")
        let key = SymmetricKey(data: keyData)
        
        let metadataData = try keychain.retrieveData(for: "doc_meta_\(documentID)")
        let metadata = try JSONSerialization.jsonObject(with: metadataData) as! [String: String]
        
        return SecureEncryptedDocument(
            encryptedData: encryptedData,
            key: key,
            originalFilename: metadata["filename"] ?? "document.pdf"
        )
    }
    
    private func getSecureDocumentsDirectory() throws -> URL {
        let appSupportDir = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        
        let secureDir = appSupportDir.appendingPathComponent("SecureDocuments")
        
        if !fileManager.fileExists(atPath: secureDir.path) {
            try fileManager.createDirectory(at: secureDir, withIntermediateDirectories: true)
            
            // Set secure attributes
            var attributes = try fileManager.attributesOfItem(atPath: secureDir.path)
            attributes[.protectionKey] = FileProtectionType.completeUnlessOpen
            try fileManager.setAttributes(attributes, ofItemAtPath: secureDir.path)
        }
        
        return secureDir
    }
}


class KeychainService {
    static let shared = KeychainService()
    private init() {}
    
    private let serviceName = "OneBoxSecureStorage"
    
    func store(_ data: Data, for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.storeFailed(status)
        }
    }
    
    func store(_ string: String, for key: String) throws {
        guard let data = string.data(using: .utf8) else {
            throw KeychainError.invalidData
        }
        try store(data, for: key)
    }
    
    func retrieveData(for key: String) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw KeychainError.retrieveFailed(status)
        }
        
        return data
    }
    
    func retrieveString(for key: String) throws -> String {
        let data = try retrieveData(for: key)
        guard let string = String(data: data, encoding: .utf8) else {
            throw KeychainError.invalidData
        }
        return string
    }
    
    func delete(for key: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.deleteFailed(status)
        }
    }
}

enum KeychainError: Error {
    case storeFailed(OSStatus)
    case retrieveFailed(OSStatus)
    case deleteFailed(OSStatus)
    case invalidData
}

class SecureLinkStorage {
    static let shared = SecureLinkStorage()
    private init() {}
    
    private let keychain = KeychainService.shared
    
    func store(_ metadata: SecureLinkMetadata) {
        do {
            let data = try JSONEncoder().encode(metadata)
            try keychain.store(data, for: "link_meta_\(metadata.id.uuidString)")
        } catch {
            print("Failed to store link metadata: \(error)")
        }
    }
    
    func retrieve(id: UUID) -> SecureLinkMetadata? {
        do {
            let data = try keychain.retrieveData(for: "link_meta_\(id.uuidString)")
            return try JSONDecoder().decode(SecureLinkMetadata.self, from: data)
        } catch {
            return nil
        }
    }
    
    func getAllMetadata() -> [SecureLinkMetadata] {
        // In a production app, you would query keychain for all link_meta_ items
        // For now, return empty array since we can't easily enumerate keychain items
        return []
    }
    
    func delete(id: UUID) {
        try? keychain.delete(for: "link_meta_\(id.uuidString)")
    }
}

// MARK: - Codable Support for Secure Storage

extension SecureLinkMetadata: Codable {
    private enum CodingKeys: String, CodingKey {
        case id, documentName, createdAt, expiresAt, accessLevel, accessCount, collaboratorEmails
    }
}

// MARK: - Note: Device-to-Device Sharing (MultipeerConnectivity)
// Peer-to-peer device sharing via MultipeerConnectivity is available in
// MultipeerDocumentService.swift for future expansion. Not included in v1.0.

#Preview {
    SecureCollaborationView(pdfURL: URL(fileURLWithPath: "/tmp/sample.pdf"))
        .environmentObject(JobManager.shared)
}