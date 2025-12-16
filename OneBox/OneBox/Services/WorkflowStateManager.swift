//
//  WorkflowStateManager.swift
//  OneBox
//
//  Manages workflow state persistence to survive app backgrounding/minimizing
//

import Foundation
import SwiftUI

/// Manages saving and restoring workflow state when app is backgrounded
class WorkflowStateManager: ObservableObject {
    static let shared = WorkflowStateManager()

    private let userDefaults = UserDefaults.standard
    private let stateKey = "oneBox.activeWorkflowState"
    private let timestampKey = "oneBox.activeWorkflowTimestamp"

    // State expiration - don't restore states older than 1 hour
    private let stateExpirationSeconds: TimeInterval = 3600

    @Published var hasRestoredState: Bool = false

    private init() {}

    // MARK: - Tool Flow State

    struct ToolFlowState: Codable {
        let toolType: String
        let selectedURLPaths: [String]
        let currentStep: String
        let timestamp: Date
    }

    func saveToolFlowState(tool: String, selectedURLs: [URL], step: String) {
        let state = ToolFlowState(
            toolType: tool,
            selectedURLPaths: selectedURLs.map { $0.path },
            currentStep: step,
            timestamp: Date()
        )

        if let encoded = try? JSONEncoder().encode(state) {
            userDefaults.set(encoded, forKey: stateKey)
            userDefaults.set(Date().timeIntervalSince1970, forKey: timestampKey)
            print("💾 WorkflowStateManager: Saved tool flow state for \(tool)")
        }
    }

    func restoreToolFlowState() -> ToolFlowState? {
        // Check if state exists and is not expired
        guard let timestamp = userDefaults.object(forKey: timestampKey) as? TimeInterval else {
            return nil
        }

        let stateAge = Date().timeIntervalSince1970 - timestamp
        guard stateAge < stateExpirationSeconds else {
            print("⏰ WorkflowStateManager: State expired (\(Int(stateAge))s old)")
            clearState()
            return nil
        }

        guard let data = userDefaults.data(forKey: stateKey),
              let state = try? JSONDecoder().decode(ToolFlowState.self, from: data) else {
            return nil
        }

        // Verify files still exist
        let existingPaths = state.selectedURLPaths.filter { FileManager.default.fileExists(atPath: $0) }
        guard !existingPaths.isEmpty else {
            print("⚠️ WorkflowStateManager: Selected files no longer exist")
            clearState()
            return nil
        }

        print("♻️ WorkflowStateManager: Restored tool flow state for \(state.toolType)")
        hasRestoredState = true
        return state
    }

    func clearState() {
        userDefaults.removeObject(forKey: stateKey)
        userDefaults.removeObject(forKey: timestampKey)
        hasRestoredState = false
        print("🗑️ WorkflowStateManager: Cleared saved state")
    }

    // MARK: - Active Session Tracking

    private let activeSessionKey = "oneBox.hasActiveSession"

    func markSessionActive() {
        userDefaults.set(true, forKey: activeSessionKey)
    }

    func markSessionComplete() {
        userDefaults.set(false, forKey: activeSessionKey)
        clearState()
    }

    func hasActiveSession() -> Bool {
        return userDefaults.bool(forKey: activeSessionKey)
    }
}

// MARK: - Scene Phase Handler View Modifier

struct ScenePhaseStateHandler: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    let onBackground: () -> Void
    let onActive: () -> Void

    func body(content: Content) -> some View {
        content
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .background:
                    print("📱 App going to background")
                    onBackground()
                case .active:
                    print("📱 App becoming active")
                    onActive()
                case .inactive:
                    // Transitional state, could also save here for extra safety
                    break
                @unknown default:
                    break
                }
            }
    }
}

extension View {
    func handleScenePhase(onBackground: @escaping () -> Void, onActive: @escaping () -> Void) -> some View {
        self.modifier(ScenePhaseStateHandler(onBackground: onBackground, onActive: onActive))
    }
}
