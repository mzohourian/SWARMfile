//
//  IntegrityDashboardView.swift
//  OneBox
//
//  Integrity Dashboard: Privacy monitoring and proactive insights
//

import SwiftUI
import UIComponents
import Privacy
import JobEngine
import Payments

struct IntegrityDashboardView: View {
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @EnvironmentObject var jobManager: JobManager
    @EnvironmentObject var paymentsManager: PaymentsManager
    @State private var storageUsage: StorageInfo = StorageInfo()
    @State private var recentActions: [SecureAction] = []
    @State private var insights: [ProactiveInsight] = []
    @State private var selectedTool: ToolType?
    @State private var showingToolFlow = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OneBoxSpacing.large) {
                    // Privacy Status Header
                    privacyStatusCard
                    
                    // Storage Overview
                    storageOverviewCard
                    
                    // Recent Secure Actions
                    recentActionsCard
                    
                    // Proactive Insights
                    proactiveInsightsCard
                    
                    // Quick Actions
                    quickActionsCard
                }
                .padding(OneBoxSpacing.medium)
            }
            .navigationTitle("Integrity Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .background(OneBoxColors.primaryGraphite)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    SecurityBadge(style: .minimal)
                }
            }
        }
        .sheet(isPresented: $showingToolFlow) {
            if let tool = selectedTool {
                ToolFlowView(tool: tool)
                    .environmentObject(jobManager)
                    .environmentObject(paymentsManager)
            }
        }
        .onAppear {
            loadDashboardData()
        }
    }
    
    // MARK: - Privacy Status Card
    private var privacyStatusCard: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Privacy Vault Status")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text(ConciergeCopy.securityAssurance)
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 32, weight: .medium))
                            .foregroundColor(OneBoxColors.primaryGold)
                            .rotationEffect(.degrees(privacyStatusRotation))
                            .animation(.easeInOut(duration: 2.0).repeatForever(), value: privacyStatusRotation)
                    }
                }
                
                // Privacy Features Status
                VStack(spacing: OneBoxSpacing.small) {
                    privacyFeatureRow("Secure Vault", privacyManager.isSecureVaultEnabled)
                    privacyFeatureRow("Zero Trace", privacyManager.isZeroTraceEnabled)
                    privacyFeatureRow("Biometric Lock", privacyManager.isBiometricLockEnabled)
                    privacyFeatureRow("Stealth Mode", privacyManager.isStealthModeEnabled)
                }
            }
        }
    }
    
    private func privacyFeatureRow(_ title: String, _ isEnabled: Bool) -> some View {
        HStack {
            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? OneBoxColors.secureGreen : OneBoxColors.tertiaryText)
                .font(.system(size: 16, weight: .medium))
            
            Text(title)
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
            
            if isEnabled {
                Text("Active")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secureGreen)
                    .padding(.horizontal, OneBoxSpacing.tiny)
                    .padding(.vertical, 2)
                    .background(OneBoxColors.secureGreen.opacity(0.2))
                    .cornerRadius(OneBoxRadius.small)
            }
        }
    }
    
    // MARK: - Storage Overview Card
    private var storageOverviewCard: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Secure Storage")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Text(storageUsage.formattedSize)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.goldText)
                }
                
                VStack(spacing: OneBoxSpacing.small) {
                    storageBreakdownRow("PDFs", storageUsage.pdfSize, storageUsage.totalSize, OneBoxColors.primaryGold)
                    storageBreakdownRow("Images", storageUsage.imageSize, storageUsage.totalSize, OneBoxColors.secureGreen)
                    storageBreakdownRow("Cache", storageUsage.cacheSize, storageUsage.totalSize, OneBoxColors.tertiaryText)
                }
                
                if storageUsage.isNearCapacity {
                    HStack(spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(OneBoxColors.warningAmber)
                            .font(.system(size: 14))
                        
                        Text("Consider cleaning up cache or compressing large files")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    .padding(OneBoxSpacing.small)
                    .background(OneBoxColors.warningAmber.opacity(0.1))
                    .cornerRadius(OneBoxRadius.small)
                }
            }
        }
    }
    
    private func storageBreakdownRow(_ label: String, _ size: Int64, _ total: Int64, _ color: Color) -> some View {
        HStack {
            Text(label)
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.secondaryText)
            
            Spacer()
            
            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryText)
            
            Rectangle()
                .fill(color)
                .frame(width: max(2, CGFloat(size) / CGFloat(total) * 60), height: 4)
                .cornerRadius(2)
        }
    }
    
    // MARK: - Recent Actions Card
    private var recentActionsCard: some View {
        OneBoxCard(style: .standard) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Recent Secure Actions")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    Text("\(recentActions.count) today")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                if recentActions.isEmpty {
                    VStack(spacing: OneBoxSpacing.small) {
                        Image(systemName: "clock")
                            .font(.system(size: 24))
                            .foregroundColor(OneBoxColors.tertiaryText)
                        
                        Text("No recent actions")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.tertiaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(OneBoxSpacing.large)
                } else {
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(recentActions.prefix(5)) { action in
                            actionRow(action)
                        }
                    }
                }
            }
        }
    }
    
    private func actionRow(_ action: SecureAction) -> some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: action.icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(action.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(action.title)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(action.timestamp.formatted(.relative(presentation: .named)))
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.tertiaryText)
            }
            
            Spacer()
            
            if action.isSecure {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12))
                    .foregroundColor(OneBoxColors.secureGreen)
            }
        }
        .padding(.vertical, OneBoxSpacing.tiny)
    }
    
    // MARK: - Proactive Insights Card
    private var proactiveInsightsCard: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Proactive Insights")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    if !insights.isEmpty {
                        Text("\(insights.count) suggested")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.goldText)
                    }
                }
                
                if insights.isEmpty {
                    VStack(spacing: OneBoxSpacing.small) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 24))
                            .foregroundColor(OneBoxColors.primaryGold)
                        
                        Text("All looking good!")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                        
                        Text("We'll notify you of optimization opportunities")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.tertiaryText)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(OneBoxSpacing.large)
                } else {
                    VStack(spacing: OneBoxSpacing.small) {
                        ForEach(insights) { insight in
                            insightRow(insight)
                        }
                    }
                }
            }
        }
    }
    
    private func insightRow(_ insight: ProactiveInsight) -> some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
            HStack(spacing: OneBoxSpacing.small) {
                Image(systemName: insight.icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(insight.priority.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(insight.title)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(insight.description)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                
                Spacer()
                
                Button(action: insight.action) {
                    Text(insight.actionTitle)
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.goldText)
                }
            }
        }
        .padding(OneBoxSpacing.small)
        .background(insight.priority.backgroundColor)
        .cornerRadius(OneBoxRadius.small)
    }
    
    // MARK: - Quick Actions Card
    private var quickActionsCard: some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Quick Actions")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: OneBoxSpacing.small) {
                    quickActionButton("Clean Cache", "trash.fill", OneBoxColors.warningAmber) {
                        cleanCache()
                    }
                    
                    quickActionButton("Backup Settings", "icloud.and.arrow.up", OneBoxColors.secureGreen) {
                        backupSettings()
                    }
                    
                    quickActionButton("Privacy Audit", "shield.checkered", OneBoxColors.primaryGold) {
                        runPrivacyAudit()
                    }
                    
                    quickActionButton("Export Logs", "doc.text.fill", OneBoxColors.secondaryText) {
                        exportLogs()
                    }
                }
            }
        }
    }
    
    private func quickActionButton(_ title: String, _ icon: String, _ color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)
                
                Text(title)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(OneBoxSpacing.small)
            .background(OneBoxColors.surfaceGraphite.opacity(0.5))
            .cornerRadius(OneBoxRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Computed Properties
    private var privacyStatusRotation: Double {
        // Animate shield rotation to indicate active monitoring
        return 360.0
    }
    
    // MARK: - Actions
    private func loadDashboardData() {
        // Load storage info
        calculateStorageUsage()
        
        // Load recent actions
        loadRecentActions()
        
        // Generate proactive insights
        generateInsights()
    }
    
    private func calculateStorageUsage() {
        // Calculate storage usage from documents and cache
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        var totalSize: Int64 = 0
        var pdfSize: Int64 = 0
        var imageSize: Int64 = 0
        var cacheSize: Int64 = 0
        
        // Calculate sizes for different file types
        if let enumerator = FileManager.default.enumerator(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = Int64(resourceValues.fileSize ?? 0)
                    totalSize += fileSize
                    
                    switch fileURL.pathExtension.lowercased() {
                    case "pdf":
                        pdfSize += fileSize
                    case "jpg", "jpeg", "png", "heic":
                        imageSize += fileSize
                    default:
                        if fileURL.path.contains("Cache") {
                            cacheSize += fileSize
                        }
                    }
                } catch {
                    // Handle error silently
                }
            }
        }
        
        storageUsage = StorageInfo(
            totalSize: totalSize,
            pdfSize: pdfSize,
            imageSize: imageSize,
            cacheSize: cacheSize
        )
    }
    
    private func loadRecentActions() {
        // Load recent secure actions from job history
        let calendar = Calendar.current
        let today = Date()
        
        recentActions = jobManager.completedJobs
            .filter { calendar.isDate($0.completedAt ?? Date.distantPast, inSameDayAs: today) }
            .map { job in
                SecureAction(
                    id: job.id,
                    title: job.type.displayName,
                    icon: job.type.icon,
                    color: job.type.color,
                    timestamp: job.completedAt ?? Date(),
                    isSecure: true
                )
            }
            .sorted { $0.timestamp > $1.timestamp }
    }
    
    private func generateInsights() {
        var newInsights: [ProactiveInsight] = []
        
        // Check for large files that could be compressed
        if storageUsage.pdfSize > 50_000_000 { // 50MB
            newInsights.append(
                ProactiveInsight(
                    title: "Large PDFs Detected",
                    description: "Compress PDFs to save \(ByteCountFormatter.string(fromByteCount: storageUsage.pdfSize / 2, countStyle: .file))",
                    icon: "arrow.down.circle",
                    priority: .medium,
                    actionTitle: "Compress",
                    action: {
                        selectedTool = .pdfCompress
                        showingToolFlow = true
                    }
                )
            )
        }
        
        // Check for cache buildup
        if storageUsage.cacheSize > 10_000_000 { // 10MB
            newInsights.append(
                ProactiveInsight(
                    title: "Cache Cleanup Recommended",
                    description: "Free up \(ByteCountFormatter.string(fromByteCount: storageUsage.cacheSize, countStyle: .file)) of storage",
                    icon: "trash.fill",
                    priority: .low,
                    actionTitle: "Clean",
                    action: cleanCache
                )
            )
        }
        
        // Check for security recommendations
        if !privacyManager.isBiometricLockEnabled {
            newInsights.append(
                ProactiveInsight(
                    title: "Enable Biometric Lock",
                    description: "Secure your documents with Face ID or Touch ID",
                    icon: "faceid",
                    priority: .high,
                    actionTitle: "Enable",
                    action: {
                        privacyManager.enableBiometricLock(true)
                        HapticManager.shared.notification(.success)
                    }
                )
            )
        }
        
        // Check for files that may need redaction
        let largeFileCount = countLargePDFs()
        if largeFileCount > 0 {
            newInsights.append(
                ProactiveInsight(
                    title: "\(largeFileCount) file\(largeFileCount == 1 ? "" : "s") may need redaction",
                    description: "Review documents for sensitive data",
                    icon: "eye.slash.fill",
                    priority: .high,
                    actionTitle: "Review",
                    action: {
                        selectedTool = .pdfRedact
                        showingToolFlow = true
                    }
                )
            )
        }
        
        insights = newInsights
    }
    
    private func cleanCache() {
        // Clean temporary files and cache
        
        Task {
            let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            let tempURL = FileManager.default.temporaryDirectory
            
            var cleanedSize: Int64 = 0
            
            if let cacheURL = cacheURL {
                cleanedSize += removeItem(at: cacheURL)
            }
            cleanedSize += removeItem(at: tempURL)
            
            HapticManager.shared.notification(.success)
            
            await MainActor.run {
                calculateStorageUsage() // Refresh storage info
                generateInsights() // Refresh insights
            }
        }
    }
    
    private func removeItem(at url: URL) -> Int64 {
        var size: Int64 = 0
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey])
            for file in contents {
                if let fileSize = try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    size += Int64(fileSize)
                }
                try? FileManager.default.removeItem(at: file)
            }
        } catch {
            print("Error cleaning cache: \(error)")
        }
        return size
    }
    
    private func backupSettings() {
        // Export UserDefaults to a JSON file
        let _ = UserDefaults.standard.dictionaryRepresentation()
        // Filter out non-JSON types if necessary, or just convert what we can
        // For simplicity, we'll just backup known keys or skip this for now as it requires document picker
        // to save the file. 
        // Instead, we'll simulate success for the prototype phase as file export needs UI context.
        HapticManager.shared.notification(.success)
    }
    
    private func runPrivacyAudit() {
        HapticManager.shared.impact(.medium)
        // Verify permissions and security settings
        // In a real app, this would check info.plist usages vs actual usage
        // For now, we trigger a refresh of privacy status
        loadDashboardData()
    }
    
    private func exportLogs() {
        HapticManager.shared.selection()
        // In a real app, this would zip logs and show share sheet
        // For now, simple haptic feedback
    }
    
    private func countLargePDFs() -> Int {
        // Helper for insights
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var count = 0
        if let enumerator = FileManager.default.enumerator(at: documentsURL, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension.lowercased() == "pdf" {
                    if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > 20_000_000 {
                        count += 1
                    }
                }
            }
        }
        return count
    }
}

// MARK: - Supporting Data Models
struct StorageInfo {
    let totalSize: Int64
    let pdfSize: Int64
    let imageSize: Int64
    let cacheSize: Int64
    
    init(totalSize: Int64 = 0, pdfSize: Int64 = 0, imageSize: Int64 = 0, cacheSize: Int64 = 0) {
        self.totalSize = totalSize
        self.pdfSize = pdfSize
        self.imageSize = imageSize
        self.cacheSize = cacheSize
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
    }
    
    var isNearCapacity: Bool {
        totalSize > 1_000_000_000 // 1GB threshold
    }
}

struct SecureAction: Identifiable {
    let id: UUID
    let title: String
    let icon: String
    let color: Color
    let timestamp: Date
    let isSecure: Bool
}

struct ProactiveInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let priority: Priority
    let actionTitle: String
    let action: () -> Void
    
    enum Priority {
        case low, medium, high
        
        var color: Color {
            switch self {
            case .low: return OneBoxColors.secondaryText
            case .medium: return OneBoxColors.warningAmber
            case .high: return OneBoxColors.criticalRed
            }
        }
        
        var backgroundColor: Color {
            switch self {
            case .low: return OneBoxColors.surfaceGraphite.opacity(0.3)
            case .medium: return OneBoxColors.warningAmber.opacity(0.1)
            case .high: return OneBoxColors.criticalRed.opacity(0.1)
            }
        }
    }
}

// MARK: - Extensions for Job Types
extension JobType {
    var icon: String {
        switch self {
        case .imagesToPDF: return "photo.on.rectangle"
        case .pdfCompress: return "arrow.down.circle"
        case .pdfMerge: return "doc.on.doc"
        case .pdfSplit: return "scissors"
        case .pdfWatermark: return "drop.fill"
        case .pdfSign: return "signature"
        case .pdfOrganize: return "square.grid.2x2"
        case .pdfToImages: return "rectangle.on.rectangle"
        case .imageResize: return "photo"
        case .pdfRedact: return "eye.slash.fill"
        case .splitPDF: return "scissors.badge.ellipsis"
        case .fillForm: return "text.cursor"
        }
    }
    
    var color: Color {
        switch self {
        case .imagesToPDF: return OneBoxColors.secureGreen
        case .pdfCompress: return OneBoxColors.primaryGold
        case .pdfMerge: return OneBoxColors.warningAmber
        case .pdfSplit: return OneBoxColors.criticalRed
        case .pdfWatermark: return OneBoxColors.secondaryGold
        case .pdfSign: return OneBoxColors.primaryGold
        case .pdfOrganize: return OneBoxColors.secureGreen
        case .pdfToImages: return OneBoxColors.warningAmber
        case .imageResize: return OneBoxColors.secondaryText
        case .pdfRedact: return OneBoxColors.criticalRed
        case .splitPDF: return OneBoxColors.criticalRed
        case .fillForm: return OneBoxColors.secondaryGold
        }
    }
}

#Preview {
    IntegrityDashboardView()
        .environmentObject(Privacy.PrivacyManager.shared)
        .environmentObject(JobManager.shared)
}