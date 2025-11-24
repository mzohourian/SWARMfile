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
    @State private var selectedIntent: ProcessingIntent = .convert
    @StateObject private var searchService = OnDeviceSearchService.shared
    
    // Privacy hero animation
    @State private var privacyAnimationPhase: Double = 0
    
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
                        
                        // Intent-Based Navigation
                        intentNavigationSection
                        
                        // Quick Actions & Workflow Suggestions
                        quickActionsSection
                        
                        // Integrity Dashboard Summary
                        integrityDashboardSummary
                    }
                    .padding(OneBoxSpacing.medium)
                }
            }
            .navigationBarHidden(true)
            .overlay(
                // Security Badge - positioned to avoid text overlap
                VStack {
                    HStack {
                        Spacer()
                        SecurityBadge(style: .floating)
                    }
                    .padding(.top, OneBoxSpacing.large) // Extra top padding to clear "Fort Knox" text
                    Spacer()
                }
                .padding(OneBoxSpacing.medium),
                alignment: .topTrailing
            )
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
        .onAppear {
            // Privacy animations removed for clean, static presentation
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
    
    // MARK: - Intent-Based Navigation
    private var intentNavigationSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("What would you like to do?")
                .font(OneBoxTypography.sectionTitle)
                .foregroundColor(OneBoxColors.primaryText)
            
            // Intent selector
            HStack(spacing: OneBoxSpacing.small) {
                ForEach(ProcessingIntent.allCases, id: \.self) { intent in
                    intentButton(intent)
                }
            }
            
            // Tools for selected intent
            intentToolsGrid
        }
    }
    
    private func intentButton(_ intent: ProcessingIntent) -> some View {
        let isSelected = selectedIntent == intent
        
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedIntent = intent
                HapticManager.shared.selection()
            }
        }) {
            VStack(spacing: OneBoxSpacing.tiny) {
                Image(systemName: intent.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? OneBoxColors.primaryGraphite : OneBoxColors.primaryGold)
                
                Text(intent.title)
                    .font(OneBoxTypography.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? OneBoxColors.primaryGraphite : OneBoxColors.primaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, OneBoxSpacing.small)
            .background(isSelected ? OneBoxColors.primaryGold : OneBoxColors.surfaceGraphite)
            .cornerRadius(OneBoxRadius.medium)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var intentToolsGrid: some View {
        let tools = selectedIntent.tools
        
        return LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: OneBoxSpacing.medium) {
            ForEach(tools, id: \.self) { tool in
                intentToolCard(tool)
            }
        }
    }
    
    private func intentToolCard(_ tool: ToolType) -> some View {
        OneBoxCard(style: .interactive) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                HStack {
                    Image(systemName: tool.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(tool.color)
                    
                    Spacer()
                    
                    // Privacy info button
                    Button(action: {
                        showPrivacyInfo(for: tool)
                    }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                }
                
                Text(tool.displayName)
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(tool.description)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .lineLimit(2)
                
                // Proactive insights for this tool
                if let insight = getInsightForTool(tool) {
                    HStack(spacing: OneBoxSpacing.tiny) {
                        Image(systemName: "lightbulb.fill")
                            .font(.system(size: 12))
                            .foregroundColor(OneBoxColors.warningAmber)
                        
                        Text(insight)
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.secondaryText)
                            .lineLimit(1)
                    }
                    .padding(.top, OneBoxSpacing.tiny)
                }
                
                OneBoxButton("Open", style: .primary) {
                    selectedTool = tool
                    showingToolFlow = true
                    HapticManager.shared.impact(.light)
                }
            }
        }
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
                        // Show recent files
                    }
                    
                    quickActionButton("Workflows", "gear.badge.checkmark") {
                        showingWorkflowConcierge = true
                    }
                    
                    quickActionButton("Search", "magnifyingglass") {
                        // Focus search
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
    private func startPrivacyAnimation() {
        privacyAnimationPhase = Double.pi * 2 // Full cycle for sine wave
    }
    
    private func performGlobalSearch(_ query: String) {
        // Implement global search across documents, tags, workflows
        // This logic is now handled by OnDeviceSearchService via onChange
        if !query.isEmpty {
            HapticManager.shared.selection()
        }
    }
    
    private func showPrivacyInfo(for tool: ToolType) {
        // Show privacy information modal
        HapticManager.shared.impact(.light)
    }
    
    private func getInsightForTool(_ tool: ToolType) -> String? {
        // Return proactive insights for specific tools
        switch tool {
        case .pdfCompress:
            return "Reduce file sizes by up to 80%"
        case .pdfSign:
            return "Face ID verification required"
        case .pdfMerge:
            return "Auto-bookmark creation available"
        default:
            return nil
        }
    }
    
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

// MARK: - Processing Intent
enum ProcessingIntent: CaseIterable {
    case convert, organize, secure
    
    var title: String {
        switch self {
        case .convert: return "Convert"
        case .organize: return "Organize"
        case .secure: return "Secure"
        }
    }
    
    var icon: String {
        switch self {
        case .convert: return "arrow.triangle.2.circlepath"
        case .organize: return "square.grid.2x2"
        case .secure: return "shield.checkered"
        }
    }
    
    var tools: [ToolType] {
        switch self {
        case .convert:
            return [.imagesToPDF, .pdfToImages, .imageResize]
        case .organize:
            return [.pdfMerge, .pdfSplit, .pdfOrganize, .pdfCompress]
        case .secure:
            return [.pdfSign, .pdfWatermark, .pdfRedact]
        }
    }
}



#Preview {
    HomeView()
        .environmentObject(PaymentsManager.shared)
        .environmentObject(Privacy.PrivacyManager.shared)
        .environmentObject(JobManager.shared)
}