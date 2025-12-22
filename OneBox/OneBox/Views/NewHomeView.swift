//
//  NewHomeView.swift
//  OneBox
//
//  OneBox Standard Home Experience - Privacy-first luxury workspace
//

import SwiftUI
import UIComponents
import Privacy
import JobEngine
import CommonTypes
import QuickLook

struct HomeView: View {
    @EnvironmentObject var paymentsManager: PaymentsManager
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @EnvironmentObject var jobManager: JobManager

    @State private var searchText = ""
    @State private var selectedTool: ToolType?
    @State private var showingToolFlow = false
    @State private var showingIntegrityDashboard = false
    @State private var showingWorkflowConcierge = false
    @State private var showingRecentFiles = false
    @State private var showingPrivacyInfo = false
    @State private var privacyInfoTool: ToolType?
    @State private var documentPreviewURL: URL?
    @StateObject private var searchService = OnDeviceSearchService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                OneBoxColors.primaryGraphite.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: OneBoxSpacing.xxl) {
                        // Privacy Hero Section
                        privacyHeroSection

                        // Usage Status & Upgrade CTA (Contextual)
                        if !paymentsManager.hasPro {
                            usageStatusSection
                        }

                        // All Tools Grid (no tabs - all visible)
                        allToolsSection

                        // Quick Actions & Workflow Suggestions
                        quickActionsSection

                        // Integrity Dashboard Summary
                        integrityDashboardSummary
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationBarHidden(true)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), suggestions: {
                if !searchText.isEmpty && !searchService.searchResults.isEmpty {
                    searchResultsView
                }
            })
            .onChange(of: searchText) { newValue in
                searchService.performGlobalSearch(newValue)
            }
            .onAppear {
                // Index documents on first load (on-device only)
                searchService.indexAllDocuments()
            }
        }
        .sheet(isPresented: $showingToolFlow) {
            if let tool = selectedTool {
                ToolFlowView(tool: tool)
                    .environmentObject(jobManager)
                    .environmentObject(paymentsManager)
            }
        }
        .sheet(isPresented: $showingIntegrityDashboard) {
            IntegrityDashboardView()
                .environmentObject(privacyManager)
                .environmentObject(jobManager)
        }
        .sheet(isPresented: $showingWorkflowConcierge) {
            WorkflowConciergeView()
                .environmentObject(jobManager)
                .environmentObject(paymentsManager)
        }
        .sheet(isPresented: $showingRecentFiles) {
            RecentsView()
                .environmentObject(jobManager)
        }
        .sheet(isPresented: $showingPrivacyInfo) {
            if let tool = privacyInfoTool {
                ToolPrivacyInfoView(tool: tool)
            }
        }
        .quickLookPreview($documentPreviewURL)
    }

    // MARK: - Privacy Hero Section
    private var privacyHeroSection: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                // Brand Logo with Text - prominent and centered
                Image("VaultLogoWithText")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                    .shadow(color: OneBoxColors.primaryGold.opacity(0.3), radius: 16, x: 0, y: 4)

                // Privacy Guarantees - moved up, closer to logo
                privacyGuarantees

                // Safe Dial Animation
                safeDial
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var safeDial: some View {
        ZStack {
            // Outer ring
            Circle()
                .stroke(OneBoxColors.primaryGold.opacity(0.3), lineWidth: 3)
                .frame(width: 120, height: 120)

            // Progress ring
            Circle()
                .trim(from: 0, to: 0.85) // 85% for "secure" feeling
                .stroke(
                    LinearGradient(
                        colors: [OneBoxColors.primaryGold, OneBoxColors.secondaryGold],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: 6, lineCap: .round)
                )
                .frame(width: 120, height: 120)
                .rotationEffect(.degrees(-90))

            // Center content with security badge
            VStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(OneBoxColors.secureGreen)

                Text("100%")
                    .font(OneBoxTypography.caption)
                    .fontWeight(.bold)
                    .foregroundColor(OneBoxColors.primaryText)

                Text("SECURE")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
        }
    }

    private var privacyGuarantees: some View {
        HStack(spacing: 0) {
            privacyGuaranteeItem("shield.fill", "On-Device", "Processing")
                .frame(maxWidth: .infinity)
            privacyGuaranteeItem("lock.fill", "Zero", "Cloud Calls")
                .frame(maxWidth: .infinity)
            privacyGuaranteeItem("eye.slash.fill", "No", "Tracking")
                .frame(maxWidth: .infinity)
        }
    }

    private func privacyGuaranteeItem(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(OneBoxColors.secureGreen)

            Text(title)
                .font(OneBoxTypography.caption)
                .fontWeight(.semibold)
                .foregroundColor(OneBoxColors.primaryText)

            Text(subtitle)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }

    // MARK: - Usage Status Section
    private var usageStatusSection: some View {
        OneBoxCard(style: .standard) {
            VStack(spacing: OneBoxSpacing.medium) {
                // Usage meter with contextual messaging
                UsageMeter(
                    current: paymentsManager.exportsUsed,
                    limit: paymentsManager.freeExportLimit,
                    type: "exports"
                )

                // Contextual upgrade messaging (only when near limit)
                if shouldShowUpgradePrompt {
                    contextualUpgradePrompt
                }
            }
        }
    }

    private var contextualUpgradePrompt: some View {
        HStack(spacing: OneBoxSpacing.small) {
            Image(systemName: "crown.fill")
                .foregroundColor(OneBoxColors.primaryGold)
                .font(.system(size: 16))

            VStack(alignment: .leading, spacing: 2) {
                Text("Almost at your limit")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText)

                Text("Unlock unlimited secure processing")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
            }

            Spacer()

            OneBoxButton("Upgrade", style: .security) {
                // Show upgrade flow
            }
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.mutedGold)
        .cornerRadius(OneBoxRadius.small)
    }

    // MARK: - All Tools Section (No Tabs - All Visible)
    private var allToolsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Tools")
                .font(OneBoxTypography.sectionTitle)
                .foregroundColor(OneBoxColors.primaryText)

            // All tools in 2-column grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: OneBoxSpacing.medium) {
                ForEach(allTools, id: \.self) { tool in
                    toolCard(tool)
                }
            }
        }
    }

    /// All available tools in display order
    private var allTools: [ToolType] {
        [
            .imagesToPDF, .pdfToImages,
            .pdfSplit, .pdfMerge,
            .pdfOrganize, .pdfCompress,
            .pdfSign, .pdfWatermark,
            .pdfRedact, .imageResize
        ]
    }

    private func toolCard(_ tool: ToolType) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top accent line - gold gradient
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [OneBoxColors.primaryGold, OneBoxColors.secondaryGold],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 3)

            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                // Icon row with security badge
                HStack(alignment: .top) {
                    // Tool icon in elegant circle
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [tool.color.opacity(0.15), tool.color.opacity(0.05)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 44, height: 44)

                        Image(systemName: tool.icon)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(tool.color)
                    }

                    Spacer()

                    // Security indicator
                    HStack(spacing: 4) {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 10, weight: .medium))
                        Text("SECURE")
                            .font(.system(size: 8, weight: .bold))
                            .tracking(0.5)
                    }
                    .foregroundColor(OneBoxColors.secureGreen)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(OneBoxColors.secureGreen.opacity(0.1))
                    .cornerRadius(4)
                }

                // Tool name - prominent
                Text(tool.displayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)

                // Description
                Text(tool.description)
                    .font(.system(size: 12))
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                // Bottom row - chevron indicator
                HStack {
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(OneBoxColors.primaryGold.opacity(0.6))
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .frame(height: 160) // Fixed height for uniform cards
        .background(OneBoxColors.surfaceGraphite)
        .cornerRadius(OneBoxRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                .stroke(
                    LinearGradient(
                        colors: [OneBoxColors.primaryGold.opacity(0.2), OneBoxColors.primaryGold.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
        .onTapGesture {
            selectedTool = tool
            showingToolFlow = true
            HapticManager.shared.impact(.light)
        }
    }

    // MARK: - Quick Actions Section
    private var quickActionsSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                HStack {
                    Text("Quick Actions")
                        .font(OneBoxTypography.cardTitle)
                        .foregroundColor(OneBoxColors.primaryText)

                    Spacer()

                    Button(action: {
                        showingWorkflowConcierge = true
                    }) {
                        HStack(spacing: OneBoxSpacing.tiny) {
                            Text("Workflow Concierge")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.goldText)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(OneBoxColors.goldText)
                        }
                    }
                }

                HStack(spacing: OneBoxSpacing.small) {
                    quickActionButton("Recent Files", "clock.fill") {
                        showingRecentFiles = true
                    }

                    quickActionButton("Workflows", "gear.badge.checkmark") {
                        showingWorkflowConcierge = true
                    }

                    quickActionButton("Privacy", "lock.shield.fill") {
                        showingIntegrityDashboard = true
                    }
                }
            }
        }
    }

    private func quickActionButton(_ title: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(OneBoxColors.primaryGold)

                Text(title)
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OneBoxSpacing.small)
            .background(OneBoxColors.surfaceGraphite.opacity(0.5))
            .cornerRadius(OneBoxRadius.small)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Integrity Dashboard Summary
    private var integrityDashboardSummary: some View {
        OneBoxCard(style: .standard) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text("Vault Health")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)

                        Text("All systems secure")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secureGreen)
                    }

                    Spacer()

                    Button(action: {
                        showingIntegrityDashboard = true
                    }) {
                        HStack(spacing: OneBoxSpacing.tiny) {
                            Text("View Dashboard")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.goldText)

                            Image(systemName: "arrow.right")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(OneBoxColors.goldText)
                        }
                    }
                }

                // Quick stats
                HStack(spacing: OneBoxSpacing.large) {
                    dashboardStat("Files Secure", "\(getSecureFilesCount())")
                    dashboardStat("Actions Today", "\(getTodayActionsCount())")
                    dashboardStat("Storage", getStorageStatus())
                }
            }
        }
    }

    private func dashboardStat(_ title: String, _ value: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Text(value)
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryGold)

            Text(title)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }

    // MARK: - Search Results View
    private var searchResultsView: some View {
        ForEach(searchService.searchResults) { result in
            Button(action: {
                handleSearchResult(result)
            }) {
                HStack {
                    Image(systemName: result.type.icon)
                        .foregroundColor(OneBoxColors.primaryGold)

                    VStack(alignment: .leading) {
                        Text(result.title)
                            .foregroundColor(OneBoxColors.primaryText)

                        if let url = result.url {
                            Text(url.path)
                                .font(.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                }
            }
        }
    }

    private func handleSearchResult(_ result: SearchResult) {
        switch result.type {
        case .tool:
            // Parse tool ID (tool-imagesToPDF -> imagesToPDF)
            let toolId = result.id.replacingOccurrences(of: "tool-", with: "")
            if let tool = ToolType(rawValue: toolId) {
                selectedTool = tool
                showingToolFlow = true
            }
        case .workflow:
            showingWorkflowConcierge = true
        case .document:
            // Preview the document if URL is available
            if let url = result.url, FileManager.default.fileExists(atPath: url.path) {
                documentPreviewURL = url
            }
        }
        searchText = ""
    }

    // MARK: - Computed Properties
    private var shouldShowUpgradePrompt: Bool {
        let usageRatio = Double(paymentsManager.exportsUsed) / Double(paymentsManager.freeExportLimit)
        return usageRatio >= 0.7 // Show when 70% or more used
    }

    // MARK: - Helper Functions
    private func showPrivacyInfo(for tool: ToolType) {
        privacyInfoTool = tool
        showingPrivacyInfo = true
        HapticManager.shared.impact(.light)
    }

    private func getInsightForTool(_ tool: ToolType) -> String? {
        // Return proactive insights for specific tools
        switch tool {
        case .pdfCompress:
            return "Reduce file sizes by up to 80%"
        case .pdfSign:
            return "Face ID verification available"
        case .pdfMerge:
            return "Auto-bookmark creation available"
        case .pdfRedact:
            return "Permanently remove sensitive data"
        case .pdfWatermark:
            return "Add text or image watermarks"
        default:
            return nil
        }
    }

    private func getSecureFilesCount() -> Int {
        // Calculate number of secure files based on completed jobs
        let secureJobTypes: [JobType] = [.pdfWatermark, .pdfSign, .pdfRedact]
        return jobManager.completedJobs.filter { job in
            secureJobTypes.contains(job.type) || job.settings.enableEncryption || job.settings.enableSecureVault
        }.count
    }

    private func getTodayActionsCount() -> Int {
        let today = Date()
        return jobManager.completedJobs.filter { job in
            Calendar.current.isDate(job.completedAt ?? Date.distantPast, inSameDayAs: today)
        }.count
    }

    private func getStorageStatus() -> String {
        // Calculate real storage usage
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        guard let documentsURL = documentsPath else {
            return "Unknown"
        }

        do {
            let resources = try documentsURL.resourceValues(forKeys: [.fileSizeKey])
            if let fileSize = resources.fileSize {
                return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
            }
        } catch {
            // Fallback: calculate by enumerating files
            let totalSize = calculateDirectorySize(url: documentsURL)
            return ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file)
        }

        return "Unknown"
    }

    private func calculateDirectorySize(url: URL) -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.fileSizeKey])
                    if let fileSize = resourceValues.fileSize {
                        totalSize += Int64(fileSize)
                    }
                } catch {
                    continue // Skip files we can't read
                }
            }
        }

        return totalSize
    }
}

// MARK: - Tool Privacy Info View

struct ToolPrivacyInfoView: View {
    let tool: ToolType
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: OneBoxSpacing.large) {
                    // Privacy Badge
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 40))
                            .foregroundColor(OneBoxColors.secureGreen)

                        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                            Text("100% On-Device")
                                .font(OneBoxTypography.cardTitle)
                                .foregroundColor(OneBoxColors.primaryText)

                            Text("No data leaves your device")
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                    }
                    .padding(OneBoxSpacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(OneBoxColors.secureGreen.opacity(0.1))
                    .cornerRadius(OneBoxRadius.medium)

                    // Tool-specific privacy info
                    VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                        Text("How \(tool.displayName) Protects Your Privacy")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)

                        ForEach(privacyPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: OneBoxSpacing.small) {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(OneBoxColors.primaryGold)
                                    .frame(width: 20)

                                Text(point)
                                    .font(OneBoxTypography.body)
                                    .foregroundColor(OneBoxColors.secondaryText)
                            }
                        }
                    }

                    // Data handling section
                    VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                        Text("Data Handling")
                            .font(OneBoxTypography.sectionTitle)
                            .foregroundColor(OneBoxColors.primaryText)

                        dataHandlingRow("Processing", "On your device only", "cpu")
                        dataHandlingRow("Storage", "Local app sandbox", "internaldrive")
                        dataHandlingRow("Network", "Never transmitted", "wifi.slash")
                        dataHandlingRow("Third Parties", "No access", "person.2.slash")
                    }
                }
                .padding(OneBoxSpacing.large)
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("\(tool.displayName) Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                }
            }
        }
    }

    private func dataHandlingRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 30)

            Text(title)
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.secondaryText)

            Spacer()

            Text(value)
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.secureGreen)
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.5))
        .cornerRadius(OneBoxRadius.small)
    }

    private var privacyPoints: [String] {
        switch tool {
        case .imagesToPDF:
            return [
                "Images are converted to PDF entirely on your device",
                "Original images remain untouched",
                "No image data is uploaded or shared"
            ]
        case .pdfMerge:
            return [
                "PDFs are merged locally using Apple's PDFKit",
                "Document contents never leave your device",
                "No external servers involved in processing"
            ]
        case .pdfSplit:
            return [
                "PDF splitting uses on-device processing",
                "Split files are saved to your local storage",
                "No cloud services used"
            ]
        case .pdfCompress:
            return [
                "Compression algorithms run locally",
                "Your documents stay on your device",
                "File size reduction without data exposure"
            ]
        case .pdfWatermark:
            return [
                "Watermarks are applied on-device",
                "Your branding stays private",
                "No external API calls"
            ]
        case .pdfSign:
            return [
                "Signatures are stored locally only",
                "Biometric data never leaves your device",
                "Digital signing is entirely offline"
            ]
        case .pdfRedact:
            return [
                "Redaction permanently removes sensitive data",
                "Processing happens entirely on-device",
                "Redacted content cannot be recovered"
            ]
        case .pdfOrganize:
            return [
                "Page organization is performed locally",
                "No document data is transmitted",
                "Changes are saved to your device only"
            ]
        case .pdfToImages:
            return [
                "PDF pages are extracted on-device",
                "Images are saved to local storage",
                "No cloud processing involved"
            ]
        case .imageResize:
            return [
                "Image resizing uses local processing",
                "No images are uploaded anywhere",
                "EXIF data can be stripped for privacy"
            ]
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(PaymentsManager.shared)
        .environmentObject(Privacy.PrivacyManager.shared)
        .environmentObject(JobManager.shared)
}
