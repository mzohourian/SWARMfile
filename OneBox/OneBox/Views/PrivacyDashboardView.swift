//
//  PrivacyDashboardView.swift
//  OneBox
//
//  Comprehensive privacy dashboard showing security status and controls
//

import SwiftUI
import Privacy

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
                    icon: "vault.fill",
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
            HStack {
                Text("Advanced Features")
                    .font(.headline)
                Spacer()
                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(.orange)
            }

            VStack(spacing: 12) {
                NavigationLink(destination: FileForensicsView()) {
                    FeatureCard(
                        title: "File Forensics",
                        description: "Cryptographic proof of local processing",
                        icon: "magnifyingglass.circle.fill",
                        color: .cyan.opacity(0.6)
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: DocumentSanitizerView()) {
                    FeatureCard(
                        title: "Document Sanitizer",
                        description: "Remove metadata and hidden content",
                        icon: "doc.badge.gearshape.fill",
                        color: .orange.opacity(0.6)
                    )
                }
                .buttonStyle(.plain)

                NavigationLink(destination: EncryptionCenterView()) {
                    FeatureCard(
                        title: "Encryption Center",
                        description: "Password-protect your files",
                        icon: "key.fill",
                        color: .green.opacity(0.6)
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
                        Label("Vault", systemImage: "vault.fill")
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

// MARK: - Advanced Features Views (Coming Soon)

struct FileForensicsView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "magnifyingglass.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(.cyan.opacity(0.6))

            Text("File Forensics")
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text("Generate cryptographic proof that your files were processed entirely on-device with no network activity.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Label("Coming Soon", systemImage: "clock.fill")
                .font(.caption.bold())
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)

            Spacer()
        }
        .navigationTitle("File Forensics")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DocumentSanitizerView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.badge.gearshape.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange.opacity(0.6))

            Text("Document Sanitizer")
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text("Remove hidden metadata, author information, comments, and other identifying data from your documents.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Label("Coming Soon", systemImage: "clock.fill")
                .font(.caption.bold())
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)

            Spacer()
        }
        .navigationTitle("Document Sanitizer")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EncryptionCenterView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "key.fill")
                .font(.system(size: 64))
                .foregroundColor(.green.opacity(0.6))

            Text("Encryption Center")
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text("Password-protect your documents with AES-256 encryption. Only you can unlock them.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Label("Coming Soon", systemImage: "clock.fill")
                .font(.caption.bold())
                .foregroundColor(.orange)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)

            Spacer()
        }
        .navigationTitle("Encryption Center")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    PrivacyDashboardView()
        .environmentObject(PrivacyManager.shared)
}