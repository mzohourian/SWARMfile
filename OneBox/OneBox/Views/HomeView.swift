//
//  HomeView.swift
//  OneBox
//

import SwiftUI
import UIComponents
import Privacy
import JobEngine

struct LegacyHomeView: View {
    @EnvironmentObject var paymentsManager: PaymentsManager
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @EnvironmentObject var jobManager: JobManager
    @State private var searchText = ""
    @State private var selectedTool: ToolType?
    @State private var showingToolFlow = false

    private var filteredTools: [ToolType] {
        if searchText.isEmpty {
            return ToolType.allCases
        }
        return ToolType.allCases.filter { tool in
            tool.displayName.localizedCaseInsensitiveContains(searchText) ||
            tool.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerView
                    
                    // Privacy Status Banner
                    privacyStatusBanner

                    // Ad Banner (free tier)
                    if !paymentsManager.hasPro {
                        AdBannerView()
                            .frame(height: 60)
                            .padding(.horizontal)
                    }

                    // Tools Grid
                    toolsGrid
                }
                .padding(.vertical)
            }
            .navigationTitle("OneBox")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search tools...")
            .sheet(item: $selectedTool) { tool in
                ToolFlowView(tool: tool)
                    .environmentObject(jobManager)
                    .environmentObject(paymentsManager)
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 8) {
            Text("Privacy-First File Tools")
                .font(.subheadline)
                .foregroundColor(.secondary)

            if !paymentsManager.hasPro {
                HStack(spacing: 4) {
                    Image(systemName: "gift.fill")
                        .foregroundColor(.orange)
                    Text("\(paymentsManager.remainingFreeExports) free exports today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(.horizontal)
    }
    
    private var privacyStatusBanner: some View {
        HStack {
            // Privacy Status
            HStack(spacing: 6) {
                Image(systemName: "shield.fill")
                    .foregroundColor(.green)
                    .font(.caption)
                
                Text("Files Stay Local")
                    .font(.caption.bold())
                    .foregroundColor(.green)
            }
            
            Spacer()
            
            // Airplane Mode Status
            if privacyManager.airplaneModeStatus == .enabled {
                HStack(spacing: 4) {
                    Image(systemName: "airplane")
                        .foregroundColor(.green)
                        .font(.caption)
                    
                    Text("Max Privacy")
                        .font(.caption.bold())
                        .foregroundColor(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .cornerRadius(6)
            }
        }
        .padding(.horizontal)
    }

    private var toolsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            ForEach(filteredTools) { tool in
                ToolCard(tool: tool) {
                    selectedTool = tool
                }
                .accessibilityLabel("\(tool.displayName). \(tool.description)")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal)
    }
}

// MARK: - Tool Card
struct ToolCard: View {
    let tool: ToolType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: tool.icon)
                    .font(.system(size: 36))
                    .foregroundColor(tool.color)
                    .frame(height: 50)

                VStack(spacing: 4) {
                    Text(tool.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(tool.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(16)
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}


#Preview {
    LegacyHomeView()
        .environmentObject(PaymentsManager.shared)
}
