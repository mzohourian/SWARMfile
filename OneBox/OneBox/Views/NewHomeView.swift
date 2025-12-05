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

struct HomeView: View {
    @EnvironmentObject var paymentsManager: PaymentsManager
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @EnvironmentObject var jobManager: JobManager
    
    @State private var searchText = ""
    @State private var selectedTool: ToolType?
    @State private var showingToolFlow = false
    @State private var showingIntegrityDashboard = false
    @State private var showingWorkflowConcierge = false
    @StateObject private var searchService = OnDeviceSearchService.shared

    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: OneBoxSpacing.large) {
                        // Privacy Hero Section (compact)
                        privacyHeroSection

                        // All Tools Grid - 2x5
                        allToolsSection

                        // Usage Status (only for free users)
                        if !paymentsManager.hasPro {
                            usageStatusSection
                        }

                        // Vault Health Summary
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
            }
        }
        .sheet(isPresented: $showingIntegrityDashboard) {
            IntegrityDashboardView()
        }
        .sheet(isPresented: $showingWorkflowConcierge) {
            WorkflowConciergeView()
        }
    }
    
    // MARK: - Privacy Hero Section
    private var privacyHeroSection: some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.large) {
                // Hero Statement
                VStack(spacing: OneBoxSpacing.small) {
                    // Main title with dramatic emphasis
                    VStack(spacing: 4) {
                        Text("FORT KNOX")
                            .font(OneBoxTypography.heroTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(OneBoxColors.primaryGold)
                            .tracking(2.0) // Wide letter spacing for impact
                        
                        Rectangle()
                            .fill(OneBoxColors.primaryGold)
                            .frame(height: 2)
                            .frame(maxWidth: 120) // Underline accent
                    }
                    
                    Text("of PDF Apps")
                        .font(OneBoxTypography.sectionTitle)
                        .fontWeight(.medium)
                        .foregroundColor(OneBoxColors.primaryText)
                        .tracking(1.0)
                        .opacity(0.9)
                    
                    Text(ConciergeCopy.privacyHero)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, OneBoxSpacing.medium)
                }
                
                // Safe Dial Animation
                safeDial
                
                // Privacy Guarantees
                privacyGuarantees
            }
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
            
            // Center icon
            VStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(OneBoxColors.primaryGold)
                
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
        HStack(spacing: OneBoxSpacing.large) {
            privacyGuaranteeItem("shield.fill", "On-Device", "Processing")
            privacyGuaranteeItem("lock.fill", "Zero", "Cloud Calls")
            privacyGuaranteeItem("eye.slash.fill", "No", "Tracking")
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
    
    // MARK: - All Tools Section
    private var allToolsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            HStack {
                Text("Tools")
                    .font(OneBoxTypography.sectionTitle)
                    .foregroundColor(OneBoxColors.primaryText)

                Spacer()

                Button(action: {
                    showingWorkflowConcierge = true
                    HapticManager.shared.impact(.light)
                }) {
                    HStack(spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "gear.badge.checkmark")
                            .font(.system(size: 14, weight: .medium))
                        Text("Workflows")
                            .font(OneBoxTypography.caption)
                    }
                    .foregroundColor(OneBoxColors.primaryGold)
                }
            }

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: OneBoxSpacing.small),
                GridItem(.flexible(), spacing: OneBoxSpacing.small)
            ], spacing: OneBoxSpacing.small) {
                ForEach(allTools, id: \.self) { tool in
                    toolCard(tool)
                }
            }
        }
    }

    /// All available tools in display order
    private var allTools: [ToolType] {
        [
            .pdfMerge, .pdfSplit,
            .pdfOrganize, .pdfCompress,
            .pdfSign, .pdfWatermark,
            .pdfRedact, .imagesToPDF,
            .pdfToImages, .imageResize
        ]
    }

    private func toolCard(_ tool: ToolType) -> some View {
        Button(action: {
            selectedTool = tool
            showingToolFlow = true
            HapticManager.shared.impact(.light)
        }) {
            HStack(spacing: OneBoxSpacing.small) {
                // Icon with gradient background
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [tool.color.opacity(0.8), tool.color.opacity(0.4)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)

                    Image(systemName: tool.icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }

                Text(tool.displayName)
                    .font(OneBoxTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(OneBoxColors.primaryText)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(OneBoxColors.primaryGold.opacity(0.6))
            }
            .padding(OneBoxSpacing.medium)
            .background(OneBoxColors.surfaceGraphite)
            .cornerRadius(OneBoxRadius.medium)
            .overlay(
                RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                    .stroke(OneBoxColors.primaryGold.opacity(0.1), lineWidth: 1)
            )
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
            // In a real app, we'd preview the document
            // For now, show in Recents or similar
            break
        }
        searchText = ""
    }

    // MARK: - Computed Properties
    private var shouldShowUpgradePrompt: Bool {
        let usageRatio = Double(paymentsManager.exportsUsed) / Double(paymentsManager.freeExportLimit)
        return usageRatio >= 0.7 // Show when 70% or more used
    }
    
    // MARK: - Helper Functions
    private func getSecureFilesCount() -> Int {
        // Calculate number of secure files based on completed jobs
        // Using correct JobType enum cases from JobEngine
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

#Preview {
    HomeView()
        .environmentObject(PaymentsManager.shared)
        .environmentObject(Privacy.PrivacyManager.shared)
        .environmentObject(JobManager.shared)
}