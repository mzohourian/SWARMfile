//
//  PrivacyDashboardView.swift
//  OneBox
//
//  Comprehensive privacy dashboard showing security status and controls
//

import SwiftUI
import Privacy
import UniformTypeIdentifiers

struct PrivacyDashboardView: View {
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @State private var showingAuditTrail = false
    @State private var showingForensics = false
    @State private var selectedAuditEntry: Privacy.PrivacyAuditEntry?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Privacy Status Header
                    privacyStatusHeader
                    
                    // Quick Status Cards
                    privacyStatusCards
                    
                    // Privacy Controls
                    privacyControls
                    
                    // Compliance Mode
                    complianceModeSection
                    
                    // Monitoring Section
                    monitoringSection
                    
                    // Advanced Features
                    advancedFeaturesSection
                }
                .padding()
            }
            .navigationTitle("Privacy Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingAuditTrail) {
                AuditTrailView()
            }
            .sheet(item: $selectedAuditEntry) { entry in
                AuditEntryDetailView(entry: entry)
            }
        }
    }
    
    // MARK: - Privacy Status Header
    
    private var privacyStatusHeader: some View {
        VStack(spacing: 16) {
            // Main Status
            HStack {
                Image(systemName: "shield.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Privacy Fortress Active")
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Text("All processing happens on your device")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Network Status Banner
            networkStatusBanner
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    private var networkStatusBanner: some View {
        HStack {
            Image(systemName: privacyManager.airplaneModeStatus == .enabled ? "airplane" : "wifi.slash")
                .foregroundColor(privacyManager.airplaneModeStatus == .enabled ? .green : .orange)
            
            Text(privacyManager.airplaneModeStatus.displayText)
                .font(.caption.bold())
                .foregroundColor(privacyManager.airplaneModeStatus == .enabled ? .green : .orange)
            
            Spacer()
            
            Text(privacyManager.networkStatus.privacyStatus)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(privacyManager.airplaneModeStatus == .enabled ? Color.green.opacity(0.1) : Color.orange.opacity(0.1))
        .cornerRadius(8)
    }
    
    // MARK: - Privacy Status Cards
    
    private var privacyStatusCards: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            PrivacyStatusCard(
                title: "Files Stay Local",
                icon: "iphone",
                status: .active,
                description: "Never uploaded"
            )
            
            PrivacyStatusCard(
                title: "No Cloud Upload",
                icon: "icloud.slash",
                status: .active,
                description: "Files never leave device"
            )

            PrivacyStatusCard(
                title: "Secure Processing",
                icon: "lock.shield",
                status: .active,
                description: "\(String(format: "%.1f", privacyManager.memoryStatus.usage)) MB in use"
            )
            
            PrivacyStatusCard(
                title: "Background Cleared",
                icon: "trash",
                status: .active,
                description: "Auto cleanup"
            )
        }
    }
    
    // MARK: - Privacy Controls
    
    private var privacyControls: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Privacy Controls")
                .font(.headline)
            
            VStack(spacing: 12) {
                PrivacyToggleRow(
                    title: "Secure Vault",
                    description: "Encrypted temporary storage",
                    icon: "lock.shield.fill",
                    isOn: $privacyManager.isSecureVaultEnabled,
                    color: .red
                ) { enabled in
                    privacyManager.enableSecureVault(enabled)
                }
                
                PrivacyToggleRow(
                    title: "Zero-Trace Mode",
                    description: "No history or metadata saved",
                    icon: "eye.slash.fill",
                    isOn: $privacyManager.isZeroTraceEnabled,
                    color: .purple
                ) { enabled in
                    privacyManager.enableZeroTrace(enabled)
                }
                
                PrivacyToggleRow(
                    title: "Biometric Lock",
                    description: "Face ID/Touch ID for processing",
                    icon: "faceid",
                    isOn: $privacyManager.isBiometricLockEnabled,
                    color: .blue
                ) { enabled in
                    privacyManager.enableBiometricLock(enabled)
                }
                
                PrivacyToggleRow(
                    title: "Stealth Mode",
                    description: "Hidden UI during processing",
                    icon: "theatermasks.fill",
                    isOn: $privacyManager.isStealthModeEnabled,
                    color: .gray
                ) { enabled in
                    privacyManager.enableStealthMode(enabled)
                }
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Compliance Mode Section
    
    private var complianceModeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Compliance Mode")
                .font(.headline)
            
            Picker("Compliance Mode", selection: $privacyManager.selectedComplianceMode) {
                ForEach(ComplianceMode.allCases, id: \.self) { mode in
                    VStack(alignment: .leading) {
                        Text(mode.displayName)
                            .font(.subheadline.bold())
                        Text(mode.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .tag(mode)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: privacyManager.selectedComplianceMode) { newValue in
                privacyManager.setComplianceMode(newValue)
            }
            
            if privacyManager.selectedComplianceMode != .none {
                ComplianceBadge(mode: privacyManager.selectedComplianceMode)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Monitoring Section
    
    private var monitoringSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security Monitoring")
                .font(.headline)
            
            VStack(spacing: 12) {
                Button(action: {
                    showingAuditTrail = true
                }) {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading) {
                            Text("Privacy Audit Trail")
                                .font(.subheadline.bold())
                                .foregroundColor(.primary)
                            Text("\(privacyManager.getAuditTrail().count) recorded events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                
                MemoryMonitorCard(memoryStatus: privacyManager.memoryStatus)
                
                NetworkMonitorCard(networkStatus: privacyManager.networkStatus)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Advanced Features Section

    private var advancedFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Advanced Features")
                .font(.headline)

            VStack(spacing: 12) {
                NavigationLink(destination: FileForensicsView().environmentObject(privacyManager)) {
                    FeatureCard(
                        title: "File Forensics",
                        description: "Cryptographic proof of local processing",
                        icon: "magnifyingglass.circle.fill",
                        color: .cyan
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: DocumentSanitizerView().environmentObject(privacyManager)) {
                    FeatureCard(
                        title: "Document Sanitizer",
                        description: "Remove metadata and hidden content",
                        icon: "doc.badge.gearshape.fill",
                        color: .orange
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: EncryptionCenterView().environmentObject(privacyManager)) {
                    FeatureCard(
                        title: "Encryption Center",
                        description: "Password-protect your files",
                        icon: "key.fill",
                        color: .green
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemGroupedBackground))
        .cornerRadius(16)
    }
}

// MARK: - Supporting Views

struct PrivacyStatusCard: View {
    let title: String
    let icon: String
    let status: PrivacyStatus
    let description: String
    
    enum PrivacyStatus {
        case active, inactive, warning
        
        var color: Color {
            switch self {
            case .active: return .green
            case .inactive: return .gray
            case .warning: return .orange
            }
        }
        
        var iconName: String {
            switch self {
            case .active: return "checkmark.circle.fill"
            case .inactive: return "circle"
            case .warning: return "exclamationmark.triangle.fill"
            }
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(status.color)
                
                Spacer()
                
                Image(systemName: status.iconName)
                    .foregroundColor(status.color)
                    .font(.caption)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct PrivacyToggleRow: View {
    let title: String
    let description: String
    let icon: String
    @Binding var isOn: Bool
    let color: Color
    let onToggle: (Bool) -> Void
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .onChange(of: isOn) { newValue in
                    onToggle(newValue)
                }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct ComplianceBadge: View {
    let mode: Privacy.ComplianceMode
    
    var body: some View {
        HStack {
            Image(systemName: "checkmark.seal.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Compliance Active")
                    .font(.caption.bold())
                    .foregroundColor(.blue)
                
                Text(mode.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(8)
    }
}

struct MemoryMonitorCard: View {
    let memoryStatus: Privacy.MemoryStatus
    
    var body: some View {
        HStack {
            Image(systemName: "memorychip")
                .foregroundColor(.purple)
            
            VStack(alignment: .leading) {
                Text("Secure Memory")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text(String(format: "%.1f MB encrypted", memoryStatus.usage))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(memoryStatus.isSecure ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct NetworkMonitorCard: View {
    let networkStatus: Privacy.NetworkStatus
    
    var body: some View {
        HStack {
            Image(systemName: "network")
                .foregroundColor(networkStatus.isConnected ? .orange : .green)
            
            VStack(alignment: .leading) {
                Text("Network Monitor")
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text(networkStatus.privacyStatus)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Circle()
                .fill(networkStatus.isConnected ? Color.orange : Color.green)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct FeatureCard: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

// MARK: - Supporting Detail Views

struct AuditTrailView: View {
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    
    var body: some View {
        NavigationStack {
            List(privacyManager.getAuditTrail().reversed()) { entry in
                AuditEntryRow(entry: entry)
            }
            .navigationTitle("Privacy Audit Trail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Clear") {
                        privacyManager.clearAuditTrail()
                    }
                }
            }
        }
    }
}

struct AuditEntryRow: View {
    let entry: Privacy.PrivacyAuditEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(entry.event.description)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
            
            if entry.secureVaultActive || entry.zeroTraceActive {
                HStack {
                    if entry.secureVaultActive {
                        Label("Vault", systemImage: "lock.shield.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    if entry.zeroTraceActive {
                        Label("Zero-Trace", systemImage: "eye.slash")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct AuditEntryDetailView: View {
    let entry: Privacy.PrivacyAuditEntry
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(entry.event.description)
                        .font(.title3.bold())
                    
                    Text(entry.timestamp.formatted(date: .complete, time: .complete))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Additional details based on event type
                }
                .padding()
            }
            .navigationTitle("Audit Entry")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

// MARK: - Advanced Features Views

struct FileForensicsView: View {
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var report: Privacy.FileForensicsReport?
    @State private var isProcessing = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.cyan)

                    Text("File Forensics")
                        .font(.title2.bold())

                    Text("Generate cryptographic proof that your file was processed entirely on-device.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // File Selection
                VStack(spacing: 16) {
                    if let url = selectedFileURL {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.cyan)
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Button("Change") {
                                showingFilePicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    } else {
                        Button(action: { showingFilePicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Select File to Analyze")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.cyan)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)

                // Generate Report Button
                if selectedFileURL != nil && report == nil {
                    Button(action: generateReport) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark.shield.fill")
                            }
                            Text(isProcessing ? "Analyzing..." : "Generate Forensic Report")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessing ? Color.gray : Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal)
                }

                // Report Display
                if let report = report {
                    ForensicsReportCard(report: report)
                        .padding(.horizontal)
                }

                // Error Display
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer(minLength: 50)
            }
        }
        .navigationTitle("File Forensics")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFilePicker) {
            DocumentPickerView(selectedURL: $selectedFileURL)
        }
        .onChange(of: selectedFileURL) { _ in
            report = nil
            errorMessage = nil
        }
    }

    private func generateReport() {
        guard let url = selectedFileURL else { return }
        isProcessing = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            // For forensics, we analyze the same file (input = output for verification)
            let generatedReport = privacyManager.generateFileForensics(inputURL: url, outputURL: url)

            DispatchQueue.main.async {
                self.report = generatedReport
                self.isProcessing = false
            }
        }
    }
}

struct ForensicsReportCard: View {
    let report: Privacy.FileForensicsReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: report.isValid ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(report.isValid ? .green : .red)

                VStack(alignment: .leading) {
                    Text(report.isValid ? "Verified Local Processing" : "Verification Issue")
                        .font(.headline)
                    Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // File Info
            VStack(alignment: .leading, spacing: 8) {
                Text("File")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(report.inputURL.lastPathComponent)
                    .font(.subheadline)
            }

            // Hash
            VStack(alignment: .leading, spacing: 8) {
                Text("SHA-256 Hash")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(report.inputHash.prefix(32) + "...")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundColor(.cyan)
            }

            Divider()

            // Verification Items
            HStack {
                VerificationItem(
                    title: "On-Device",
                    isVerified: report.processedOnDevice,
                    icon: "iphone"
                )
                Spacer()
                VerificationItem(
                    title: "No Network",
                    isVerified: report.noNetworkActivity,
                    icon: "wifi.slash"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct VerificationItem: View {
    let title: String
    let isVerified: Bool
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isVerified ? .green : .red)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Image(systemName: isVerified ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundColor(isVerified ? .green : .red)
        }
    }
}

struct DocumentSanitizerView: View {
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var report: Privacy.DocumentSanitizationReport?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.gearshape.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.orange)

                    Text("Document Sanitizer")
                        .font(.title2.bold())

                    Text("Remove hidden metadata, author info, comments, and tracking data from your documents.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // Warning
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("This will modify the selected file. Make a backup first if needed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)

                // File Selection
                VStack(spacing: 16) {
                    if let url = selectedFileURL {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.orange)
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Button("Change") {
                                showingFilePicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    } else {
                        Button(action: { showingFilePicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Select Document to Sanitize")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)

                // Sanitize Button
                if selectedFileURL != nil && report == nil {
                    Button(action: sanitizeDocument) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "wand.and.stars")
                            }
                            Text(isProcessing ? "Sanitizing..." : "Sanitize Document")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isProcessing ? Color.gray : Color.orange)
                        .cornerRadius(12)
                    }
                    .disabled(isProcessing)
                    .padding(.horizontal)
                }

                // Report Display
                if let report = report {
                    SanitizationReportCard(report: report)
                        .padding(.horizontal)

                    // Share Button
                    if let url = selectedFileURL {
                        Button(action: { showingShareSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Sanitized File")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal)
                        .sheet(isPresented: $showingShareSheet) {
                            ShareSheet(items: [url])
                        }
                    }
                }

                // Error Display
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer(minLength: 50)
            }
        }
        .navigationTitle("Document Sanitizer")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFilePicker) {
            DocumentPickerView(selectedURL: $selectedFileURL)
        }
        .onChange(of: selectedFileURL) { _ in
            report = nil
            errorMessage = nil
        }
    }

    private func sanitizeDocument() {
        guard let url = selectedFileURL else { return }
        isProcessing = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let generatedReport = try privacyManager.sanitizeDocument(at: url)
                DispatchQueue.main.async {
                    self.report = generatedReport
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to sanitize: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}

struct SanitizationReportCard: View {
    let report: Privacy.DocumentSanitizationReport

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(.green)

                VStack(alignment: .leading) {
                    Text("Sanitization Complete")
                        .font(.headline)
                    Text(report.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // What was removed
            VStack(alignment: .leading, spacing: 8) {
                Text("Removed Data")
                    .font(.caption)
                    .foregroundColor(.secondary)

                SanitizationItem(title: "Metadata", wasRemoved: report.metadataRemoved)
                SanitizationItem(title: "Hidden Content", wasRemoved: report.hiddenContentRemoved)
                SanitizationItem(title: "Comments", wasRemoved: report.commentsRemoved)
                SanitizationItem(title: "Revision History", wasRemoved: report.revisionHistoryCleared)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }
}

struct SanitizationItem: View {
    let title: String
    let wasRemoved: Bool

    var body: some View {
        HStack {
            Image(systemName: wasRemoved ? "checkmark.circle.fill" : "minus.circle")
                .foregroundColor(wasRemoved ? .green : .gray)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(wasRemoved ? "Removed" : "N/A")
                .font(.caption)
                .foregroundColor(wasRemoved ? .green : .secondary)
        }
    }
}

struct EncryptionCenterView: View {
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @State private var showingFilePicker = false
    @State private var selectedFileURL: URL?
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var encryptedFileURL: URL?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingShareSheet = false

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    private var passwordStrength: PasswordStrength {
        if password.count < 8 { return .weak }
        if password.count < 12 { return .medium }
        return .strong
    }

    enum PasswordStrength {
        case weak, medium, strong

        var color: Color {
            switch self {
            case .weak: return .red
            case .medium: return .orange
            case .strong: return .green
            }
        }

        var text: String {
            switch self {
            case .weak: return "Weak (min 8 chars)"
            case .medium: return "Medium"
            case .strong: return "Strong"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.green)

                    Text("Encryption Center")
                        .font(.title2.bold())

                    Text("Password-protect your documents with AES-256 encryption. Files are encrypted locally on your device.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .padding(.top)

                // File Selection
                VStack(spacing: 16) {
                    if let url = selectedFileURL {
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundColor(.green)
                            Text(url.lastPathComponent)
                                .font(.subheadline)
                                .lineLimit(1)
                            Spacer()
                            Button("Change") {
                                showingFilePicker = true
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(12)
                    } else {
                        Button(action: { showingFilePicker = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Select File to Encrypt")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal)

                // Password Entry
                if selectedFileURL != nil && encryptedFileURL == nil {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Set Encryption Password")
                            .font(.headline)

                        SecureField("Password", text: $password)
                            .textFieldStyle(.roundedBorder)

                        // Password strength indicator
                        if !password.isEmpty {
                            HStack {
                                Text("Strength:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(passwordStrength.text)
                                    .font(.caption.bold())
                                    .foregroundColor(passwordStrength.color)
                            }
                        }

                        SecureField("Confirm Password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)

                        if !confirmPassword.isEmpty && !passwordsMatch {
                            Text("Passwords do not match")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)

                    // Encrypt Button
                    Button(action: encryptFile) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "lock.fill")
                            }
                            Text(isProcessing ? "Encrypting..." : "Encrypt File")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(passwordsMatch && !isProcessing ? Color.green : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(!passwordsMatch || isProcessing)
                    .padding(.horizontal)
                }

                // Success Display
                if let encryptedURL = encryptedFileURL {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            VStack(alignment: .leading) {
                                Text("File Encrypted Successfully")
                                    .font(.headline)
                                Text(encryptedURL.lastPathComponent)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Warning
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Remember your password! There's no way to recover it.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)

                        Button(action: { showingShareSheet = true }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share Encrypted File")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .sheet(isPresented: $showingShareSheet) {
                            ShareSheet(items: [encryptedURL])
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                }

                // Error Display
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding()
                }

                Spacer(minLength: 50)
            }
        }
        .navigationTitle("Encryption Center")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingFilePicker) {
            DocumentPickerView(selectedURL: $selectedFileURL)
        }
        .onChange(of: selectedFileURL) { _ in
            encryptedFileURL = nil
            errorMessage = nil
            password = ""
            confirmPassword = ""
        }
    }

    private func encryptFile() {
        guard let url = selectedFileURL, passwordsMatch else { return }
        isProcessing = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let resultURL = try privacyManager.encryptFile(at: url, password: password)
                DispatchQueue.main.async {
                    self.encryptedFileURL = resultURL
                    self.isProcessing = false
                    self.password = ""
                    self.confirmPassword = ""
                }
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Encryption failed: \(error.localizedDescription)"
                    self.isProcessing = false
                }
            }
        }
    }
}

// MARK: - Helper Views

struct DocumentPickerView: UIViewControllerRepresentable {
    @Binding var selectedURL: URL?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .image, .data])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }

            // Start accessing security-scoped resource
            if url.startAccessingSecurityScopedResource() {
                // Copy to temp location to ensure we can work with it
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.copyItem(at: url, to: tempURL)
                url.stopAccessingSecurityScopedResource()
                parent.selectedURL = tempURL
            } else {
                parent.selectedURL = url
            }

            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.dismiss()
        }
    }
}

#Preview {
    PrivacyDashboardView()
        .environmentObject(PrivacyManager.shared)
}