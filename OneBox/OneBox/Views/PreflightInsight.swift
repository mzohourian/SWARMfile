//
//  PreflightInsight.swift
//  OneBox
//
//  Pre-flight insights for file selection (100% on-device)
//

import Foundation
import SwiftUI
import UIComponents

struct PreflightInsight: Identifiable {
    let id: String
    let title: String
    let message: String
    let icon: String
    let severity: InsightSeverity
    let actionTitle: String?
    let action: (() -> Void)?
    
    enum InsightSeverity {
        case low
        case medium
        case high
        
        var color: Color {
            switch self {
            case .low: return OneBoxColors.warningAmber
            case .medium: return OneBoxColors.warningAmber
            case .high: return OneBoxColors.criticalRed
            }
        }
    }
}

