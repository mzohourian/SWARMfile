//
//  HomeView.swift
//  OneBox
//

import SwiftUI
import UIComponents

struct HomeView: View {
    @EnvironmentObject var paymentsManager: PaymentsManager
    @State private var searchText = ""
    @State private var selectedTool: ToolType?
    @State private var showingToolFlow = false

    private var filteredTools: [ToolType] {
        // Hide video compressor and ZIP tools - focusing on core PDF/image features
        // ZIP features are redundant with iOS native capabilities (Files app can create/extract ZIPs)
        let availableTools = ToolType.allCases.filter {
            $0 != .videoCompress && $0 != .zip && $0 != .unzip
        }

        if searchText.isEmpty {
            return availableTools
        }
        return availableTools.filter { tool in
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

// MARK: - Tool Type
enum ToolType: String, CaseIterable, Identifiable {
    case imagesToPDF
    case pdfToImages
    case pdfMerge
    case pdfSplit
    case pdfCompress
    case pdfWatermark
    case pdfSign
    case pdfOrganize
    case imageResize
    case videoCompress
    case zip
    case unzip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .imagesToPDF: return "Images → PDF"
        case .pdfToImages: return "PDF → Images"
        case .pdfMerge: return "Merge PDFs"
        case .pdfSplit: return "Split PDF"
        case .pdfCompress: return "Compress PDF"
        case .pdfWatermark: return "Watermark PDF"
        case .pdfSign: return "Sign PDF"
        case .pdfOrganize: return "Organize Pages"
        case .imageResize: return "Resize Images"
        case .videoCompress: return "Compress Video"
        case .zip: return "Create ZIP"
        case .unzip: return "Extract ZIP"
        }
    }

    var description: String {
        switch self {
        case .imagesToPDF: return "Convert photos to PDF"
        case .pdfToImages: return "Extract pages as images"
        case .pdfMerge: return "Combine multiple PDFs"
        case .pdfSplit: return "Extract pages"
        case .pdfCompress: return "Reduce file size"
        case .pdfWatermark: return "Add text or image"
        case .pdfSign: return "Add signature"
        case .pdfOrganize: return "Reorder & delete pages"
        case .imageResize: return "Batch resize & compress"
        case .videoCompress: return "Reduce video size"
        case .zip: return "Archive files"
        case .unzip: return "Extract archive"
        }
    }

    var icon: String {
        switch self {
        case .imagesToPDF: return "photo.on.rectangle.angled"
        case .pdfToImages: return "photo.on.rectangle"
        case .pdfMerge: return "doc.on.doc"
        case .pdfSplit: return "scissors"
        case .pdfCompress: return "arrow.down.circle"
        case .pdfWatermark: return "waterbottle"
        case .pdfSign: return "signature"
        case .pdfOrganize: return "square.grid.2x2"
        case .imageResize: return "photo.stack"
        case .videoCompress: return "play.rectangle"
        case .zip: return "archivebox"
        case .unzip: return "archivebox.fill"
        }
    }

    var color: Color {
        switch self {
        case .imagesToPDF: return .blue
        case .pdfToImages: return .mint
        case .pdfMerge: return .purple
        case .pdfSplit: return .orange
        case .pdfCompress: return .green
        case .pdfWatermark: return .cyan
        case .pdfSign: return .indigo
        case .pdfOrganize: return .teal
        case .imageResize: return .pink
        case .videoCompress: return .red
        case .zip: return .yellow
        case .unzip: return .brown
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(PaymentsManager.shared)
}
