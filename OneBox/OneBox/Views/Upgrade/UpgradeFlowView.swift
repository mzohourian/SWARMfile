//
//  UpgradeFlowView.swift
//  OneBox
//
//  Enhanced upgrade flow with Face ID checkout and contextual monetization
//

import SwiftUI
import UIComponents
import StoreKit
import LocalAuthentication

struct UpgradeFlowView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentsManager: PaymentsManager
    @State private var selectedPlan: PremiumPlan = .pro
    @State private var isAnnualBilling = true
    @State private var showingPayment = false
    @State private var isProcessingPayment = false
    @State private var paymentCompleted = false
    @State private var contextualOffer: ContextualOffer?
    @State private var usageMetrics: UsageMetrics?
    @State private var showingFeatureComparison = false
    @State private var animateFeatures = false
    @State private var paymentError: String?
    @State private var isAuthenticating = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Premium background
                LinearGradient(
                    colors: [
                        OneBoxColors.primaryGraphite,
                        OneBoxColors.primaryGraphite.opacity(0.8),
                        OneBoxColors.primaryGold.opacity(0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                if paymentCompleted {
                    successView
                } else {
                    upgradeContentView
                }
            }
            .navigationTitle("Upgrade to Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Maybe Later") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText.opacity(0.7))
                }
            }
        }
        .onAppear {
            loadContextualOffer()
            loadUsageMetrics()
            animateFeatures = true
        }
        .sheet(isPresented: $showingPayment) {
            PaymentView(
                selectedPlan: $selectedPlan,
                isAnnualBilling: $isAnnualBilling,
                isProcessing: $isProcessingPayment,
                paymentCompleted: $paymentCompleted,
                paymentError: $paymentError
            )
        }
        .sheet(isPresented: $showingFeatureComparison) {
            FeatureComparisonView()
        }
    }
    
    // MARK: - Upgrade Content
    private var upgradeContentView: some View {
        ScrollView {
            VStack(spacing: OneBoxSpacing.xxl) {
                // Hero Section
                heroSection
                
                // Contextual Offer
                if let offer = contextualOffer {
                    contextualOfferSection(offer)
                }
                
                // Usage Metrics
                if let metrics = usageMetrics {
                    usageMetricsSection(metrics)
                }
                
                // Plan Selection
                planSelectionSection
                
                // Premium Features
                premiumFeaturesSection
                
                // Social Proof
                socialProofSection
                
                // CTA
                ctaSection
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Hero Section
    private var heroSection: some View {
        VStack(spacing: OneBoxSpacing.large) {
            // Premium badge
            HStack {
                Spacer()
                
                VStack(spacing: OneBoxSpacing.tiny) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(OneBoxColors.primaryGold)
                    
                    Text("PREMIUM")
                        .font(OneBoxTypography.caption)
                        .fontWeight(.heavy)
                        .foregroundColor(OneBoxColors.primaryGold)
                        .tracking(2)
                }
                .padding(OneBoxSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                        .fill(OneBoxColors.primaryGold.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                                .stroke(OneBoxColors.primaryGold.opacity(0.3), lineWidth: 1)
                        )
                )
                
                Spacer()
            }
            
            // Main messaging
            VStack(spacing: OneBoxSpacing.medium) {
                Text("Unlock Professional Power")
                    .font(OneBoxTypography.heroTitle)
                    .fontWeight(.heavy)
                    .foregroundColor(OneBoxColors.primaryText)
                    .multilineTextAlignment(.center)
                
                Text("Transform your document workflow with professional features designed for those who demand privacy and excellence.")
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }
        }
    }
    
    // MARK: - Contextual Offer
    private func contextualOfferSection(_ offer: ContextualOffer) -> some View {
        OneBoxCard(style: .security) {
            VStack(spacing: OneBoxSpacing.medium) {
                HStack {
                    VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                        Text(offer.title)
                            .font(OneBoxTypography.cardTitle)
                            .fontWeight(.bold)
                            .foregroundColor(OneBoxColors.primaryText)
                        
                        Text(offer.description)
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }
                    
                    Spacer()
                    
                    VStack {
                        Text("\(offer.discountPercentage)%")
                            .font(OneBoxTypography.cardTitle)
                            .fontWeight(.heavy)
                            .foregroundColor(OneBoxColors.criticalRed)
                        
                        Text("OFF")
                            .font(OneBoxTypography.micro)
                            .fontWeight(.bold)
                            .foregroundColor(OneBoxColors.criticalRed)
                    }
                    .padding(OneBoxSpacing.small)
                    .background(
                        RoundedRectangle(cornerRadius: OneBoxRadius.small)
                            .fill(OneBoxColors.criticalRed.opacity(0.1))
                    )
                }
                
                // Urgency indicator
                HStack {
                    Image(systemName: "clock.fill")
                        .font(.system(size: 14))
                        .foregroundColor(OneBoxColors.warningAmber)
                    
                    Text("Limited time offer expires in \(offer.timeRemaining)")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.warningAmber)
                    
                    Spacer()
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Usage Metrics
    private func usageMetricsSection(_ metrics: UsageMetrics) -> some View {
        OneBoxCard(style: .elevated) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Your OneBox Usage")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                VStack(spacing: OneBoxSpacing.medium) {
                    usageMetricRow("Documents Processed", "\(metrics.documentsProcessed)", "doc.fill")
                    usageMetricRow("Time Saved", "\(metrics.timeSavedHours) hours", "clock.fill")
                    usageMetricRow("Storage Space Saved", "\(metrics.spaceSavedMB) MB", "externaldrive.fill")
                    usageMetricRow("Security Events", "\(metrics.securityEvents)", "shield.checkered")
                }
                
                Text("Unlock unlimited processing and advanced features with Pro")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryGold)
                    .padding(.top, OneBoxSpacing.small)
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func usageMetricRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 24)
            
            Text(title)
                .font(OneBoxTypography.body)
                .foregroundColor(OneBoxColors.primaryText)
            
            Spacer()
            
            Text(value)
                .font(OneBoxTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(OneBoxColors.primaryGold)
        }
    }
    
    // MARK: - Plan Selection
    private var planSelectionSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Choose Your Plan")
                .font(OneBoxTypography.cardTitle)
                .foregroundColor(OneBoxColors.primaryText)
            
            // Billing toggle
            HStack {
                Spacer()
                
                VStack(spacing: OneBoxSpacing.tiny) {
                    HStack {
                        Text("Monthly")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(isAnnualBilling ? OneBoxColors.tertiaryText : OneBoxColors.primaryText)
                        
                        Toggle("", isOn: $isAnnualBilling)
                            .toggleStyle(SwitchToggleStyle(tint: OneBoxColors.primaryGold))
                            .scaleEffect(0.8)
                        
                        Text("Annual")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(isAnnualBilling ? OneBoxColors.primaryText : OneBoxColors.tertiaryText)
                    }
                    
                    if isAnnualBilling {
                        Text("Save 40%")
                            .font(OneBoxTypography.micro)
                            .fontWeight(.bold)
                            .foregroundColor(OneBoxColors.secureGreen)
                            .padding(.horizontal, OneBoxSpacing.small)
                            .padding(.vertical, OneBoxSpacing.tiny)
                            .background(OneBoxColors.secureGreen.opacity(0.1))
                            .cornerRadius(OneBoxRadius.small)
                    }
                }
                
                Spacer()
            }
            
            // Plan options
            VStack(spacing: OneBoxSpacing.medium) {
                ForEach(PremiumPlan.allCases) { plan in
                    planCard(plan)
                }
            }
        }
    }
    
    private func planCard(_ plan: PremiumPlan) -> some View {
        let isSelected = selectedPlan == plan
        let price = isAnnualBilling ? plan.annualPrice : plan.monthlyPrice
        let period = isAnnualBilling ? "year" : "month"
        
        return Button(action: {
            selectedPlan = plan
            HapticManager.shared.selection()
        }) {
            OneBoxCard(style: isSelected ? .security : .interactive) {
                VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                    HStack {
                        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                            HStack {
                                Text(plan.displayName)
                                    .font(OneBoxTypography.body)
                                    .fontWeight(.bold)
                                    .foregroundColor(OneBoxColors.primaryText)
                                
                                if plan == .enterprise {
                                    Text("MOST POPULAR")
                                        .font(OneBoxTypography.micro)
                                        .fontWeight(.bold)
                                        .foregroundColor(OneBoxColors.primaryGraphite)
                                        .padding(.horizontal, OneBoxSpacing.small)
                                        .padding(.vertical, OneBoxSpacing.tiny)
                                        .background(OneBoxColors.primaryGold)
                                        .cornerRadius(OneBoxRadius.small)
                                }
                            }
                            
                            Text(plan.description)
                                .font(OneBoxTypography.caption)
                                .foregroundColor(OneBoxColors.secondaryText)
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing) {
                            Text("$\(price)")
                                .font(OneBoxTypography.cardTitle)
                                .fontWeight(.bold)
                                .foregroundColor(OneBoxColors.primaryGold)
                            
                            Text("per \(period)")
                                .font(OneBoxTypography.micro)
                                .foregroundColor(OneBoxColors.tertiaryText)
                        }
                    }
                    
                    // Key features
                    VStack(alignment: .leading, spacing: OneBoxSpacing.small) {
                        ForEach(plan.keyFeatures, id: \.self) { feature in
                            HStack {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(OneBoxColors.secureGreen)
                                
                                Text(feature)
                                    .font(OneBoxTypography.caption)
                                    .foregroundColor(OneBoxColors.primaryText)
                                
                                Spacer()
                            }
                        }
                    }
                    .padding(.top, OneBoxSpacing.small)
                }
                .padding(OneBoxSpacing.medium)
                .overlay(
                    RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                        .stroke(
                            isSelected ? OneBoxColors.primaryGold : Color.clear,
                            lineWidth: 2
                        )
                )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Premium Features
    private var premiumFeaturesSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            HStack {
                Text("Premium Features")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Spacer()
                
                Button("Compare All") {
                    showingFeatureComparison = true
                }
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.primaryGold)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: OneBoxSpacing.medium) {
                ForEach(premiumFeatures.enumerated().map { $0 }, id: \.offset) { index, feature in
                    premiumFeatureCard(feature, delay: Double(index) * 0.1)
                }
            }
        }
    }
    
    private func premiumFeatureCard(_ feature: PremiumFeature, delay: Double) -> some View {
        OneBoxCard(style: .standard) {
            VStack(spacing: OneBoxSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(feature.color.opacity(0.2))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: feature.icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(feature.color)
                }
                
                VStack(spacing: OneBoxSpacing.tiny) {
                    Text(feature.name)
                        .font(OneBoxTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(feature.description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
        .scaleEffect(animateFeatures ? 1.0 : 0.8)
        .opacity(animateFeatures ? 1.0 : 0)
        .animation(.easeOut(duration: 0.6).delay(delay), value: animateFeatures)
    }
    
    // MARK: - Social Proof
    private var socialProofSection: some View {
        OneBoxCard(style: .elevated) {
            VStack(spacing: OneBoxSpacing.medium) {
                Text("Trusted by Professionals")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                HStack(spacing: OneBoxSpacing.large) {
                    socialProofStat("99.8%", "Uptime")
                    socialProofStat("50K+", "Documents Secured")
                    socialProofStat("4.9★", "App Store Rating")
                }
                
                Text("\"OneBox has transformed how our team handles sensitive documents. The security features give us complete peace of mind.\"")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                    .italic()
                    .multilineTextAlignment(.center)
                
                Text("— Sarah Chen, Legal Director")
                    .font(OneBoxTypography.micro)
                    .foregroundColor(OneBoxColors.tertiaryText)
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private func socialProofStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: OneBoxSpacing.tiny) {
            Text(value)
                .font(OneBoxTypography.cardTitle)
                .fontWeight(.bold)
                .foregroundColor(OneBoxColors.primaryGold)
            
            Text(label)
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - CTA Section
    private var ctaSection: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            Button("Upgrade with Face ID") {
                initiateSecureCheckout()
            }
            .font(OneBoxTypography.body)
            .fontWeight(.bold)
            .foregroundColor(OneBoxColors.primaryGraphite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, OneBoxSpacing.medium)
            .background(
                LinearGradient(
                    colors: [OneBoxColors.primaryGold, OneBoxColors.secondaryGold],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(OneBoxRadius.medium)
            .overlay(
                HStack {
                    Spacer()
                    
                    Image(systemName: "faceid")
                        .font(.system(size: 20))
                        .foregroundColor(OneBoxColors.primaryGraphite.opacity(0.7))
                        .padding(.trailing, OneBoxSpacing.medium)
                }
            )
            
            VStack(spacing: OneBoxSpacing.small) {
                Text("✓ 30-day money-back guarantee")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secureGreen)
                
                Text("✓ Cancel anytime")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secureGreen)
                
                Text("✓ Instant activation")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secureGreen)
            }
            
            Button("Restore Previous Purchase") {
                restorePurchases()
            }
            .font(OneBoxTypography.caption)
            .foregroundColor(OneBoxColors.tertiaryText)
            .padding(.top, OneBoxSpacing.small)
        }
    }
    
    // MARK: - Success View
    private var successView: some View {
        VStack(spacing: OneBoxSpacing.xxl) {
            Spacer()
            
            VStack(spacing: OneBoxSpacing.large) {
                // Success animation
                ZStack {
                    Circle()
                        .fill(OneBoxColors.secureGreen.opacity(0.2))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .fill(OneBoxColors.secureGreen.opacity(0.1))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(OneBoxColors.secureGreen)
                }
                
                VStack(spacing: OneBoxSpacing.medium) {
                    Text("Welcome to OneBox Pro!")
                        .font(OneBoxTypography.heroTitle)
                        .fontWeight(.bold)
                        .foregroundColor(OneBoxColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text("Your premium features are now active. Experience the full power of professional document processing.")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
            }
            
            Spacer()
            
            Button("Start Using Pro Features") {
                dismiss()
            }
            .font(OneBoxTypography.body)
            .fontWeight(.bold)
            .foregroundColor(OneBoxColors.primaryGraphite)
            .frame(maxWidth: .infinity)
            .padding(.vertical, OneBoxSpacing.medium)
            .background(OneBoxColors.primaryGold)
            .cornerRadius(OneBoxRadius.medium)
            .padding(.horizontal, OneBoxSpacing.medium)
        }
    }
    
    // MARK: - Helper Methods
    private func loadContextualOffer() {
        // Load contextual offer based on user behavior
        contextualOffer = ContextualOffer(
            title: "Limited Time: First Month Free",
            description: "Based on your usage patterns, get started with Pro at no cost",
            discountPercentage: 100,
            timeRemaining: "23:45:12"
        )
    }
    
    private func loadUsageMetrics() {
        // Load user's actual usage metrics
        usageMetrics = UsageMetrics(
            documentsProcessed: 47,
            timeSavedHours: 12,
            spaceSavedMB: 156,
            securityEvents: 3
        )
    }
    
    private func initiateSecureCheckout() {
        showingPayment = true
        HapticManager.shared.impact(.light)
    }
    
    private func restorePurchases() {
        // Restore previous purchases
        HapticManager.shared.impact(.light)
    }
    
    private var premiumFeatures: [PremiumFeature] {
        [
            PremiumFeature(
                name: "Unlimited Processing",
                description: "Process unlimited documents without restrictions",
                icon: "infinity",
                color: OneBoxColors.primaryGold
            ),
            PremiumFeature(
                name: "Advanced AI Features",
                description: "Smart compression and intelligent organization",
                icon: "brain.head.profile",
                color: OneBoxColors.secureGreen
            ),
            PremiumFeature(
                name: "Secure Collaboration",
                description: "Encrypted sharing with access controls",
                icon: "person.2.fill",
                color: OneBoxColors.warningAmber
            ),
            PremiumFeature(
                name: "Professional Signing",
                description: "Digital signatures with Face ID authentication",
                icon: "signature",
                color: OneBoxColors.criticalRed
            ),
            PremiumFeature(
                name: "Priority Support",
                description: "24/7 premium customer support",
                icon: "headphones",
                color: OneBoxColors.primaryGold
            ),
            PremiumFeature(
                name: "Advanced Export",
                description: "Multiple formats and quality options",
                icon: "square.and.arrow.up.fill",
                color: OneBoxColors.secureGreen
            )
        ]
    }
}

// MARK: - Supporting Types

struct ContextualOffer {
    let title: String
    let description: String
    let discountPercentage: Int
    let timeRemaining: String
}

struct UsageMetrics {
    let documentsProcessed: Int
    let timeSavedHours: Int
    let spaceSavedMB: Int
    let securityEvents: Int
}

struct PremiumFeature {
    let name: String
    let description: String
    let icon: String
    let color: Color
}

enum PremiumPlan: String, CaseIterable, Identifiable {
    case pro = "pro"
    case enterprise = "enterprise"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .pro: return "OneBox Pro"
        case .enterprise: return "OneBox Enterprise"
        }
    }
    
    var description: String {
        switch self {
        case .pro: return "Perfect for professionals and small teams"
        case .enterprise: return "Advanced features for organizations"
        }
    }
    
    var monthlyPrice: Int {
        switch self {
        case .pro: return 9
        case .enterprise: return 19
        }
    }
    
    var annualPrice: Int {
        switch self {
        case .pro: return 65  // ~40% savings
        case .enterprise: return 137  // ~40% savings
        }
    }
    
    var keyFeatures: [String] {
        switch self {
        case .pro:
            return [
                "Unlimited document processing",
                "Advanced AI features",
                "Secure collaboration",
                "Professional signing"
            ]
        case .enterprise:
            return [
                "Everything in Pro",
                "Advanced team management",
                "Custom branding",
                "Priority support"
            ]
        }
    }
}

// MARK: - Payment View

struct PaymentView: View {
    @Binding var selectedPlan: PremiumPlan
    @Binding var isAnnualBilling: Bool
    @Binding var isProcessing: Bool
    @Binding var paymentCompleted: Bool
    @Binding var paymentError: String?
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentsManager: PaymentsManager
    
    @State private var isAuthenticating = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: OneBoxSpacing.large) {
                // Payment summary
                paymentSummary
                
                Spacer()
                
                // Secure payment with Face ID
                securePaymentSection
                
                // Payment methods
                paymentMethodsSection
                
                // Terms and privacy
                legalSection
            }
            .padding(OneBoxSpacing.medium)
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Secure Checkout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(OneBoxColors.primaryText)
                }
            }
        }
    }
    
    private var paymentSummary: some View {
        OneBoxCard(style: .security) {
            VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
                Text("Payment Summary")
                    .font(OneBoxTypography.cardTitle)
                    .foregroundColor(OneBoxColors.primaryText)
                
                HStack {
                    Text(selectedPlan.displayName)
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    let price = isAnnualBilling ? selectedPlan.annualPrice : selectedPlan.monthlyPrice
                    let period = isAnnualBilling ? "year" : "month"
                    
                    Text("$\(price)/\(period)")
                        .font(OneBoxTypography.body)
                        .fontWeight(.bold)
                        .foregroundColor(OneBoxColors.primaryGold)
                }
                
                if isAnnualBilling {
                    HStack {
                        Text("Annual discount")
                            .font(OneBoxTypography.caption)
                            .foregroundColor(OneBoxColors.secureGreen)
                        
                        Spacer()
                        
                        Text("Save 40%")
                            .font(OneBoxTypography.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(OneBoxColors.secureGreen)
                    }
                }
                
                Divider()
                    .background(OneBoxColors.surfaceGraphite)
                
                HStack {
                    Text("Total")
                        .font(OneBoxTypography.body)
                        .fontWeight(.bold)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Spacer()
                    
                    let total = isAnnualBilling ? selectedPlan.annualPrice : selectedPlan.monthlyPrice
                    Text("$\(total)")
                        .font(OneBoxTypography.cardTitle)
                        .fontWeight(.bold)
                        .foregroundColor(OneBoxColors.primaryGold)
                }
            }
            .padding(OneBoxSpacing.medium)
        }
    }
    
    private var securePaymentSection: some View {
        VStack(spacing: OneBoxSpacing.large) {
            // Face ID authentication
            VStack(spacing: OneBoxSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(OneBoxColors.primaryGold.opacity(0.2))
                        .frame(width: 80, height: 80)
                    
                    if isAuthenticating {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(OneBoxColors.primaryGold)
                    } else {
                        Image(systemName: "faceid")
                            .font(.system(size: 40, weight: .medium))
                            .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                VStack(spacing: OneBoxSpacing.small) {
                    Text("Secure Biometric Checkout")
                        .font(OneBoxTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text("Your payment is securely processed by Apple with biometric authentication")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Purchase button
            Button(action: {
                authenticateAndPurchase()
            }) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(OneBoxColors.primaryGraphite)
                    } else {
                        Image(systemName: "faceid")
                            .font(.system(size: 20))
                    }
                    
                    Text(isProcessing ? "Processing..." : "Authorize with Face ID")
                        .font(OneBoxTypography.body)
                        .fontWeight(.bold)
                }
                .foregroundColor(OneBoxColors.primaryGraphite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, OneBoxSpacing.medium)
                .background(OneBoxColors.primaryGold)
                .cornerRadius(OneBoxRadius.medium)
            }
            .disabled(isProcessing)
            
            if let error = paymentError {
                Text(error)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.criticalRed)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    private var paymentMethodsSection: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.medium) {
            Text("Payment Methods")
                .font(OneBoxTypography.caption)
                .foregroundColor(OneBoxColors.secondaryText)
            
            HStack(spacing: OneBoxSpacing.medium) {
                Image(systemName: "applelogo")
                    .font(.system(size: 24))
                    .foregroundColor(OneBoxColors.primaryText)
                
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 24))
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text("Secured by Apple")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Spacer()
            }
        }
    }
    
    private var legalSection: some View {
        VStack(spacing: OneBoxSpacing.small) {
            Text("By completing this purchase, you agree to our Terms of Service and Privacy Policy. Your subscription will automatically renew unless cancelled.")
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.tertiaryText)
                .multilineTextAlignment(.center)
            
            HStack(spacing: OneBoxSpacing.medium) {
                Button("Terms of Service") {
                    // Open terms
                }
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.primaryGold)
                
                Button("Privacy Policy") {
                    // Open privacy
                }
                .font(OneBoxTypography.micro)
                .foregroundColor(OneBoxColors.primaryGold)
            }
        }
    }
    
    private func authenticateAndPurchase() {
        isAuthenticating = true
        isProcessing = true
        
        let context = LAContext()
        let reason = "Authenticate to complete your OneBox Pro purchase"
        
        context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, error in
            DispatchQueue.main.async {
                self.isAuthenticating = false
                
                if success {
                    self.processPurchase()
                } else {
                    self.isProcessing = false
                    self.paymentError = "Authentication failed. Please try again."
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func processPurchase() {
        // Get the selected product from PaymentsManager
        guard let product = getSelectedProduct() else {
            paymentError = "Please select a plan"
            isProcessing = false
            return
        }
        
        Task {
            do {
                // Actually purchase through PaymentsManager
                try await PaymentsManager.shared.purchase(product)
                
                await MainActor.run {
                    self.isProcessing = false
                    self.paymentCompleted = true
                    HapticManager.shared.notification(.success)
                    
                    // Dismiss after short delay to show success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.dismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.paymentError = error.localizedDescription
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func getSelectedProduct() -> Product? {
        // Get product based on selected plan and billing preference
        if isAnnualBilling {
            return paymentsManager.product(for: .yearly) ?? paymentsManager.products.first { $0.id.contains("yearly") }
        } else {
            return paymentsManager.product(for: .monthly) ?? paymentsManager.products.first { $0.id.contains("monthly") }
        }
    }
}

// MARK: - Feature Comparison View

struct FeatureComparisonView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: OneBoxSpacing.large) {
                    Text("Feature Comparison")
                        .font(OneBoxTypography.sectionTitle)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    // Comparison table would go here
                    Text("Detailed feature comparison coming soon...")
                        .font(OneBoxTypography.body)
                        .foregroundColor(OneBoxColors.secondaryText)
                }
                .padding(OneBoxSpacing.medium)
            }
            .background(OneBoxColors.primaryGraphite)
            .navigationTitle("Features")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    UpgradeFlowView()
        .environmentObject(PaymentsManager.shared)
}