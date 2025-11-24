//
//  ComplimentaryExportModal.swift
//  OneBox
//
//  Complimentary export modal shown before final free export
//

import SwiftUI
import UIComponents
import Payments

struct ComplimentaryExportModal: View {
    let onContinue: () -> Void
    let onUpgrade: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentsManager: PaymentsManager
    
    var body: some View {
        NavigationStack {
            ZStack {
                OneBoxColors.primaryGraphite.ignoresSafeArea()
                
                VStack(spacing: OneBoxSpacing.xxl) {
                    Spacer()
                    
                    // Hero Section
                    VStack(spacing: OneBoxSpacing.large) {
                        ZStack {
                            Circle()
                                .fill(OneBoxColors.primaryGold.opacity(0.2))
                                .frame(width: 120, height: 120)
                            
                            Image(systemName: "gift.fill")
                                .font(.system(size: 48, weight: .medium))
                                .foregroundColor(OneBoxColors.primaryGold)
                        }
                        
                        VStack(spacing: OneBoxSpacing.medium) {
                            Text("Last Free Export")
                                .font(OneBoxTypography.heroTitle)
                                .foregroundColor(OneBoxColors.primaryText)
                            
                            Text("This is your final free export today. After this, you'll need to upgrade to Pro for unlimited secure processing.")
                                .font(OneBoxTypography.body)
                                .foregroundColor(OneBoxColors.secondaryText)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, OneBoxSpacing.large)
                        }
                    }
                    
                    // Preview Summary
                    VStack(spacing: OneBoxSpacing.medium) {
                        Text("Your export is ready")
                            .font(OneBoxTypography.cardTitle)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        HStack(spacing: OneBoxSpacing.large) {
                            featureBadge("Preview", "eye.fill")
                            featureBadge("Secure", "shield.checkered")
                            featureBadge("On-Device", "lock.fill")
                        }
                    }
                    
                    Spacer()
                    
                    // Actions
                    VStack(spacing: OneBoxSpacing.medium) {
                        OneBoxButton("Continue with Free Export", icon: "arrow.right.circle.fill", style: .security) {
                            onContinue()
                            dismiss()
                        }
                        
                        OneBoxButton("Upgrade to Pro - Unlimited", icon: "crown.fill", style: .primary) {
                            onUpgrade()
                            dismiss()
                        }
                        
                        Button("Maybe Later") {
                            dismiss()
                        }
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.tertiaryText)
                    }
                    .padding(.horizontal, OneBoxSpacing.medium)
                }
                .padding(OneBoxSpacing.large)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
            }
        }
    }
    
    private func featureBadge(_ title: String, _ icon: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(OneBoxColors.secureGreen)
            
            Text(title)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
    }
}

#Preview {
    ComplimentaryExportModal(
        onContinue: {},
        onUpgrade: {}
    )
    .environmentObject(PaymentsManager.shared)
}

