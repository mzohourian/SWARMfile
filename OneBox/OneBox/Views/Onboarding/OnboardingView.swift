//
//  OnboardingView.swift
//  OneBox
//
//  Comprehensive onboarding experience with OneBox Standard luxury design
//

import SwiftUI
import UIComponents
import LocalAuthentication
import UserNotifications

struct OnboardingView: View {
    @Binding var isPresented: Bool
    @State private var currentPage = 0
    @State private var isAuthenticating = false
    @State private var authenticationCompleted = false
    @State private var privacyAccepted = false
    @State private var notificationsEnabled = false
    @State private var biometricType: BiometricType = .none
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            id: "welcome",
            title: "Welcome to OneBox",
            subtitle: "Fort Knox for your PDF documents",
            description: "Privacy-first document processing. Transform, organize, and secure your documents entirely on your device.",
            primaryAction: "Get Started",
            icon: "shield.lefthalf.filled",
            gradient: [OneBoxColors.primaryGold, OneBoxColors.secondaryGold]
        ),
        OnboardingPage(
            id: "security",
            title: "Ceremony of Security",
            subtitle: "Privacy by design, power by choice",
            description: "Everything happens on your device. No cloud processing, no data mining, no compromises. Your documents never leave your control.",
            primaryAction: "Enable Security",
            icon: "lock.shield.fill",
            gradient: [OneBoxColors.secureGreen, OneBoxColors.primaryGold]
        ),
        OnboardingPage(
            id: "features",
            title: "Professional Workflows",
            subtitle: "AI-powered document intelligence",
            description: "Smart compression, intelligent organization, secure collaboration. Experience the difference professional tools make.",
            primaryAction: "Explore Features",
            icon: "brain.head.profile",
            gradient: [OneBoxColors.primaryGold, OneBoxColors.warningAmber]
        ),
        OnboardingPage(
            id: "permissions",
            title: "Complete Setup",
            subtitle: "Optimize your experience",
            description: "Enable biometric authentication and notifications to unlock the full OneBox experience with seamless security.",
            primaryAction: "Finish Setup",
            icon: "checkmark.shield.fill",
            gradient: [OneBoxColors.secureGreen, OneBoxColors.primaryGold]
        )
    ]
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: pages[currentPage].gradient,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .overlay(
                // Subtle pattern overlay
                Rectangle()
                    .fill(OneBoxColors.primaryGraphite.opacity(0.1))
                    .ignoresSafeArea()
            )
            
            VStack(spacing: 0) {
                // Skip button
                HStack {
                    Spacer()
                    
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText.opacity(0.7))
                    .padding(.trailing, OneBoxSpacing.large)
                    .padding(.top, OneBoxSpacing.medium)
                }
                
                Spacer()
                
                // Main content
                onboardingPageContent
                
                Spacer()
                
                // Bottom controls
                bottomControls
            }
        }
        .onAppear {
            checkBiometricCapability()
        }
    }
    
    // MARK: - Page Content
    private var onboardingPageContent: some View {
        let page = pages[currentPage]
        
        return VStack(spacing: OneBoxSpacing.xxl) {
            // Icon with ceremony
            ZStack {
                Circle()
                    .fill(OneBoxColors.primaryText.opacity(0.1))
                    .frame(width: 140, height: 140)
                
                Circle()
                    .fill(OneBoxColors.primaryText.opacity(0.05))
                    .frame(width: 120, height: 120)
                
                Image(systemName: page.icon)
                    .font(.system(size: 48, weight: .medium))
                    .foregroundColor(OneBoxColors.primaryText)
            }
            .scaleEffect(1.0)
            .animation(.easeInOut(duration: 0.6).delay(0.2), value: currentPage)
            
            // Text content
            VStack(spacing: OneBoxSpacing.large) {
                VStack(spacing: OneBoxSpacing.small) {
                    Text(page.title)
                        .font(OneBoxTypography.heroTitle)
                        .fontWeight(.heavy)
                        .foregroundColor(OneBoxColors.primaryText)
                        .multilineTextAlignment(.center)
                    
                    Text(page.subtitle)
                        .font(OneBoxTypography.sectionTitle)
                        .fontWeight(.medium)
                        .foregroundColor(OneBoxColors.primaryText.opacity(0.8))
                        .multilineTextAlignment(.center)
                }
                
                Text(page.description)
                    .font(OneBoxTypography.body)
                    .foregroundColor(OneBoxColors.primaryText.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, OneBoxSpacing.large)
            }
            .opacity(1.0)
            .animation(.easeInOut(duration: 0.6).delay(0.4), value: currentPage)
            
            // Page-specific content
            if currentPage == 1 {
                securityFeaturesGrid
            } else if currentPage == 2 {
                professionalFeaturesGrid
            } else if currentPage == 3 {
                permissionsSection
            }
        }
        .padding(.horizontal, OneBoxSpacing.large)
    }
    
    // MARK: - Security Features
    private var securityFeaturesGrid: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            HStack(spacing: OneBoxSpacing.medium) {
                securityFeature("On-Device Processing", "cpu.fill")
                securityFeature("No Cloud Upload", "icloud.slash.fill")
            }

            HStack(spacing: OneBoxSpacing.medium) {
                securityFeature("Local Storage", "lock.shield.fill")
                securityFeature("Biometric Security", "faceid")
            }
        }
        .padding(.top, OneBoxSpacing.large)
    }
    
    private func securityFeature(_ title: String, _ icon: String) -> some View {
        VStack(spacing: OneBoxSpacing.small) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .medium))
                .foregroundColor(OneBoxColors.secureGreen)
            
            Text(title)
                .font(OneBoxTypography.caption)
                .fontWeight(.medium)
                .foregroundColor(OneBoxColors.primaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(OneBoxSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                .fill(OneBoxColors.primaryText.opacity(0.1))
        )
    }
    
    // MARK: - Professional Features
    private var professionalFeaturesGrid: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            professionalFeature("Smart Compression", "AI-powered optimization", "dial.high.fill")
            professionalFeature("Secure Collaboration", "Encrypted sharing & tracking", "person.2.fill")
            professionalFeature("Advanced Signing", "Professional digital signatures", "signature")
        }
        .padding(.top, OneBoxSpacing.large)
    }
    
    private func professionalFeature(_ title: String, _ description: String, _ icon: String) -> some View {
        HStack(spacing: OneBoxSpacing.medium) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(OneBoxColors.primaryGold)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                Text(title)
                    .font(OneBoxTypography.body)
                    .fontWeight(.semibold)
                    .foregroundColor(OneBoxColors.primaryText)
                
                Text(description)
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.primaryText.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(OneBoxSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                .fill(OneBoxColors.primaryText.opacity(0.1))
        )
    }
    
    // MARK: - Permissions
    private var permissionsSection: some View {
        VStack(spacing: OneBoxSpacing.large) {
            // Biometric authentication
            if biometricType != .none {
                permissionCard(
                    title: biometricType.displayName,
                    description: "Secure access to your documents",
                    icon: biometricType.icon,
                    isEnabled: authenticationCompleted,
                    action: {
                        if !authenticationCompleted {
                            authenticateUser()
                        }
                    }
                )
            }
            
            // Notifications
            permissionCard(
                title: "Notifications",
                description: "Stay informed about document processing",
                icon: "bell.fill",
                isEnabled: notificationsEnabled,
                action: {
                    requestNotificationPermission()
                }
            )
            
            // Privacy acceptance
            privacyAgreementCard
        }
        .padding(.top, OneBoxSpacing.large)
    }
    
    private func permissionCard(title: String, description: String, icon: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: OneBoxSpacing.medium) {
                ZStack {
                    Circle()
                        .fill(isEnabled ? OneBoxColors.secureGreen.opacity(0.2) : OneBoxColors.primaryText.opacity(0.1))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(isEnabled ? OneBoxColors.secureGreen : OneBoxColors.primaryText.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text(title)
                        .font(OneBoxTypography.body)
                        .fontWeight(.semibold)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    Text(description)
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryText.opacity(0.7))
                }
                
                Spacer()
                
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isEnabled ? OneBoxColors.secureGreen : OneBoxColors.primaryText.opacity(0.3))
            }
        }
        .buttonStyle(PlainButtonStyle())
        .padding(OneBoxSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                .fill(OneBoxColors.primaryText.opacity(0.05))
        )
    }
    
    private var privacyAgreementCard: some View {
        VStack(spacing: OneBoxSpacing.medium) {
            HStack(spacing: OneBoxSpacing.small) {
                Button(action: {
                    privacyAccepted.toggle()
                    HapticManager.shared.selection()
                }) {
                    Image(systemName: privacyAccepted ? "checkmark.square.fill" : "square")
                        .font(.system(size: 20))
                        .foregroundColor(privacyAccepted ? OneBoxColors.primaryGold : OneBoxColors.primaryText.opacity(0.5))
                }
                
                VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
                    Text("I agree to the OneBox Terms of Service and Privacy Policy")
                        .font(OneBoxTypography.caption)
                        .foregroundColor(OneBoxColors.primaryText)
                    
                    HStack(spacing: OneBoxSpacing.small) {
                        Button("Terms of Service") {
                            // Open Terms of Service
                        }
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.primaryGold)
                        
                        Text("•")
                            .font(OneBoxTypography.micro)
                            .foregroundColor(OneBoxColors.primaryText.opacity(0.5))
                        
                        Button("Privacy Policy") {
                            // Open Privacy Policy
                        }
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.primaryGold)
                    }
                }
                
                Spacer()
            }
        }
        .padding(OneBoxSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                .fill(OneBoxColors.primaryText.opacity(0.05))
        )
    }
    
    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: OneBoxSpacing.large) {
            // Page indicators
            HStack(spacing: OneBoxSpacing.small) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? OneBoxColors.primaryText : OneBoxColors.primaryText.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: currentPage)
                }
            }
            
            // Action buttons
            HStack(spacing: OneBoxSpacing.medium) {
                if currentPage > 0 {
                    Button("Back") {
                        previousPage()
                    }
                    .font(OneBoxTypography.body)
                    .fontWeight(.medium)
                    .foregroundColor(OneBoxColors.primaryText.opacity(0.7))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, OneBoxSpacing.medium)
                    .background(
                        RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                            .fill(OneBoxColors.primaryText.opacity(0.1))
                    )
                }
                
                Button(pages[currentPage].primaryAction) {
                    nextPage()
                }
                .font(OneBoxTypography.body)
                .fontWeight(.semibold)
                .foregroundColor(OneBoxColors.primaryGraphite)
                .frame(maxWidth: .infinity)
                .padding(.vertical, OneBoxSpacing.medium)
                .background(
                    RoundedRectangle(cornerRadius: OneBoxRadius.medium)
                        .fill(OneBoxColors.primaryText)
                )
                .disabled(currentPage == 3 && !canCompleteOnboarding)
                .opacity(currentPage == 3 && !canCompleteOnboarding ? 0.5 : 1.0)
            }
        }
        .padding(.horizontal, OneBoxSpacing.large)
        .padding(.bottom, OneBoxSpacing.large)
    }
    
    private var canCompleteOnboarding: Bool {
        privacyAccepted && (biometricType == .none || authenticationCompleted)
    }
    
    // MARK: - Helper Methods
    private func checkBiometricCapability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            switch context.biometryType {
            case .faceID:
                biometricType = .faceID
            case .touchID:
                biometricType = .touchID
            case .opticID:
                biometricType = .opticID
            default:
                biometricType = .none
            }
        } else {
            biometricType = .none
        }
    }
    
    private func authenticateUser() {
        guard !isAuthenticating else { return }
        
        isAuthenticating = true
        
        let context = LAContext()
        let reason = "Enable biometric authentication for secure document access"
        
        Task { @MainActor in
            do {
                let success = try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
                
                self.isAuthenticating = false
                
                if success {
                    self.authenticationCompleted = true
                    HapticManager.shared.notification(.success)
                } else {
                    HapticManager.shared.notification(.error)
                }
            } catch {
                self.isAuthenticating = false
                HapticManager.shared.notification(.error)
            }
        }
    }
    
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.notificationsEnabled = granted
                if granted {
                    HapticManager.shared.notification(.success)
                }
            }
        }
    }
    
    private func nextPage() {
        HapticManager.shared.impact(.light)
        
        if currentPage < pages.count - 1 {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPage += 1
            }
        } else {
            completeOnboarding()
        }
    }
    
    private func previousPage() {
        HapticManager.shared.impact(.light)
        
        if currentPage > 0 {
            withAnimation(.easeInOut(duration: 0.5)) {
                currentPage -= 1
            }
        }
    }
    
    private func completeOnboarding() {
        // Save onboarding completion
        UserDefaults.standard.set(true, forKey: "OnboardingCompleted")
        
        HapticManager.shared.notification(.success)
        
        withAnimation(.easeInOut(duration: 0.5)) {
            isPresented = false
        }
    }
}

// MARK: - Supporting Types

struct OnboardingPage: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let description: String
    let primaryAction: String
    let icon: String
    let gradient: [Color]
}

enum BiometricType {
    case none, faceID, touchID, opticID
    
    var displayName: String {
        switch self {
        case .none: return "Passcode"
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        case .opticID: return "Optic ID"
        }
    }
    
    var icon: String {
        switch self {
        case .none: return "key.fill"
        case .faceID: return "faceid"
        case .touchID: return "touchid"
        case .opticID: return "opticid"
        }
    }
}

#Preview {
    OnboardingView(isPresented: .constant(true))
}