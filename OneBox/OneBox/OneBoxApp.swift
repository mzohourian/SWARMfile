//
//  OneBoxApp.swift
//  OneBox — File Tools
//
//  Privacy-first, on-device file converter and compressor for iOS/iPadOS
//

import SwiftUI
import JobEngine
import Payments
import Privacy

@main
struct OneBoxApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var jobManager = JobManager.shared
    @StateObject private var paymentsManager = PaymentsManager.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var privacyManager = Privacy.PrivacyManager.shared

    init() {
        // Initialize app-level configuration
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appCoordinator)
                .environmentObject(jobManager)
                .environmentObject(paymentsManager)
                .environmentObject(themeManager)
                .environmentObject(privacyManager)
                .onAppear {
                    Task {
                        await paymentsManager.initialize()
                        
                        // Set up privacy delegate  
                        await MainActor.run {
                            jobManager.setPrivacyDelegate(privacyManager)
                        }
                    }
                }
                .onOpenURL { url in
                    handleQuickAction(url: url)
                }
                .preferredColorScheme(themeManager.colorScheme)
        }
    }

    private func configureAppearance() {
        // Configure global app appearance for dark backgrounds

        // Standard (inline) navigation bar appearance
        let standardAppearance = UINavigationBarAppearance()
        standardAppearance.configureWithTransparentBackground()
        standardAppearance.titleTextAttributes = [
            .foregroundColor: UIColor.white
        ]
        standardAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor.white
        ]

        // Apply to all navigation bar styles
        UINavigationBar.appearance().standardAppearance = standardAppearance
        UINavigationBar.appearance().compactAppearance = standardAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = standardAppearance
    }
    
    private func handleQuickAction(url: URL) {
        guard url.scheme == "onebox" else { return }
        
        switch url.host {
        case "privacymode":
            // Enable maximum privacy settings
            privacyManager.enableSecureVault(true)
            privacyManager.enableZeroTrace(true)
            privacyManager.enableBiometricLock(true)
            privacyManager.enableStealthMode(true)
            
            // Navigate to privacy dashboard
            appCoordinator.selectedTab = .settings
            
        case "imagestopdf":
            appCoordinator.openTool(.imagesToPDF)
            
        case "compresspdf":
            appCoordinator.openTool(.pdfCompress)
            
        default:
            break
        }
    }
}

// MARK: - App Coordinator
@MainActor
class AppCoordinator: ObservableObject {
    @Published var selectedTab: AppTab = .home
    @Published var showPaywall = false

    enum AppTab {
        case home
        case recents
        case settings
    }

    func openTool(_ tool: ToolType) {
        selectedTab = .home
        // Navigation handled by HomeView
    }
}

// MARK: - Theme Manager
class ThemeManager: ObservableObject {
    // OneBox uses a dark-only aesthetic for premium/secure feel
    // No user preference needed - always dark

    var colorScheme: ColorScheme? {
        return .dark
    }

    init() {
        // Dark mode only - no preferences to load
    }
}
