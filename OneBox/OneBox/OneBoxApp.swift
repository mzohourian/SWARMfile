//
//  OneBoxApp.swift
//  OneBox — File Tools
//
//  Privacy-first, on-device file converter and compressor for iOS/iPadOS
//

import SwiftUI
import JobEngine
import Payments

@main
struct OneBoxApp: App {
    @StateObject private var appCoordinator = AppCoordinator()
    @StateObject private var jobManager = JobManager.shared
    @StateObject private var paymentsManager = PaymentsManager.shared
    @StateObject private var themeManager = ThemeManager()

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
                .onAppear {
                    Task {
                        await paymentsManager.initialize()
                    }
                }
                .preferredColorScheme(themeManager.colorScheme)
        }
    }

    private func configureAppearance() {
        // Configure global app appearance
        UINavigationBar.appearance().largeTitleTextAttributes = [
            .foregroundColor: UIColor.label
        ]
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
    @Published var themePreference: ThemePreference {
        didSet {
            UserDefaults.standard.set(themePreference.rawValue, forKey: "theme_preference")
        }
    }

    enum ThemePreference: String, CaseIterable {
        case system
        case light
        case dark

        var displayName: String {
            switch self {
            case .system: return "System"
            case .light: return "Light"
            case .dark: return "Dark"
            }
        }
    }

    var colorScheme: ColorScheme? {
        switch themePreference {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }

    init() {
        let savedRaw = UserDefaults.standard.string(forKey: "theme_preference") ?? "system"
        self.themePreference = ThemePreference(rawValue: savedRaw) ?? .system
    }
}
