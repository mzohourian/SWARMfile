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
    @Environment(\.scenePhase) private var scenePhase

    init() {
        // Initialize app-level configuration
        configureAppearance()
    }

    var body: some Scene {
        WindowGroup {
            AppLockContainer()
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

                        // Attempt to unlock app on launch
                        await privacyManager.authenticateToUnlockApp()
                    }
                }
                .onOpenURL { url in
                    handleQuickAction(url: url)
                }
                .preferredColorScheme(themeManager.colorScheme)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .background {
                        // Lock app when going to background
                        privacyManager.lockApp()
                    } else if newPhase == .active && privacyManager.isBiometricLockEnabled && !privacyManager.isAppUnlocked {
                        // Re-authenticate when becoming active
                        Task {
                            await privacyManager.authenticateToUnlockApp()
                        }
                    }
                }
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

// MARK: - App Lock Container
struct AppLockContainer: View {
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager

    var body: some View {
        ZStack {
            // Main content - always rendered but hidden when locked
            ContentView()
                .opacity(shouldShowLockScreen ? 0 : 1)

            // Lock screen overlay
            if shouldShowLockScreen {
                LockScreenView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: shouldShowLockScreen)
    }

    private var shouldShowLockScreen: Bool {
        privacyManager.isBiometricLockEnabled && !privacyManager.isAppUnlocked
    }
}

// MARK: - Lock Screen View
struct LockScreenView: View {
    @EnvironmentObject var privacyManager: Privacy.PrivacyManager
    @State private var isAuthenticating = false

    var body: some View {
        ZStack {
            // Dark gradient background
            LinearGradient(
                colors: [Color(hex: "1a1a2e"), Color(hex: "16213e")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Lock icon
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 12) {
                    Text("OneBox is Locked")
                        .font(.title.bold())
                        .foregroundColor(.white)

                    Text("Authenticate to access your documents")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }

                Spacer()

                // Unlock button
                Button {
                    authenticate()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "faceid")
                            .font(.title2)
                        Text("Unlock")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                }
                .disabled(isAuthenticating)
                .opacity(isAuthenticating ? 0.6 : 1.0)
                .padding(.horizontal, 40)

                Text("Your documents are protected")
                    .font(.caption)
                    .foregroundColor(.gray)

                Spacer()
                    .frame(height: 60)
            }
        }
    }

    private func authenticate() {
        isAuthenticating = true
        Task {
            await privacyManager.authenticateToUnlockApp()
            await MainActor.run {
                isAuthenticating = false
            }
        }
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
