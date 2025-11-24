//
//  PageOrganizerAnomalyView.swift
//  OneBox
//
//  Anomaly detail view for Page Organizer
//

import SwiftUI
import UIComponents

struct PageAnomaly: Identifiable {
    let id: UUID
    let pageId: UUID
    let type: AnomalyType
    let message: String
    let severity: AnomalySeverity
}

enum AnomalyType {
    case duplicate
    case rotation
    case contrast
    
    var icon: String {
        switch self {
        case .duplicate: return "doc.on.doc.fill"
        case .rotation: return "rotate.right.fill"
        case .contrast: return "circle.lefthalf.filled"
        }
    }
    
    var displayName: String {
        switch self {
        case .duplicate: return "Duplicate Page"
        case .rotation: return "Rotation Issue"
        case .contrast: return "Contrast Issue"
        }
    }
}

enum AnomalySeverity: Int, Comparable {
    case low = 0
    case medium = 1
    case high = 2
    
    static func < (lhs: AnomalySeverity, rhs: AnomalySeverity) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    var color: Color {
        switch self {
        case .low: return OneBoxColors.warningAmber
        case .medium: return OneBoxColors.warningAmber
        case .high: return OneBoxColors.criticalRed
        }
    }
}

struct AnomalyDetailView: View {
    let anomalies: [PageAnomaly]
    let pages: [PageInfo]
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                if anomalies.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: OneBoxSpacing.medium) {
                            ForEach(groupedAnomalies.keys.sorted(by: { $0.rawValue > $1.rawValue }), id: \.self) { severity in
                                anomalySection(severity: severity, anomalies: groupedAnomalies[severity] ?? [])
                            }
                        }
                        .padding(OneBoxSpacing.medium)
                    }
                }
            }
            .navigationTitle("Detected Issues")
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
    
    private var emptyState: some View {
        VStack(spacing: OneBoxSpacing.large) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 64))
                .foregroundColor(OneBoxColors.secureGreen)
            
            Text("No Issues Detected")
                .font(OneBoxTypography.heroTitle)
                .foregroundColor(OneBoxColors.primaryText)
            
            Text("All pages look good!")
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
    
    private var groupedAnomalies: [AnomalySeverity: [PageAnomaly]] {
        Dictionary(grouping: anomalies) { $0.severity }
    }
    
    private func anomalySection(severity: AnomalySeverity, anomalies: [PageAnomaly]) -> some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
            HStack {
                Text(severity == .high ? "High Priority" : severity == .medium ? "Medium Priority" : "Low Priority")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(severity.color)
                
                Spacer()
                
                Text("\(anomalies.count)")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
            }
            
            ForEach(anomalies) { anomaly in
                anomalyRow(anomaly)
            }
        }
        .padding(OneBoxSpacing.medium)
        .background(OneBoxColors.surfaceGraphite.opacity(0.3))
        .cornerRadius(OneBoxRadius.medium)
    }
    
    private func anomalyRow(_ anomaly: PageAnomaly) -> some View {
        HStack(spacing: OneBoxSpacing.medium) {
            Image(systemName: anomaly.type.icon)
                .font(.system(size: 20))
                .foregroundColor(anomaly.severity.color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(anomaly.type.displayName)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(anomaly.message)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                if let pageInfo = pages.first(where: { $0.id == anomaly.pageId }) {
                    Text("Page \(pageInfo.displayIndex + 1)")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.tertiaryText)
                }
            }
            
            Spacer()
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.tertiaryGraphite)
        .cornerRadius(OneBoxRadius.small)
    }
}

#Preview {
    AnomalyDetailView(
        anomalies: [
            PageAnomaly(
                id: UUID(),
                pageId: UUID(),
                type: .duplicate,
                message: "Similar page detected",
                severity: .medium
            )
        ],
        pages: []
    )
}

