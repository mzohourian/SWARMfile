//
//  HapticManager.swift
//  OneBox
//
//  Haptic feedback management for enhanced user experience
//

import UIKit

/// Manages haptic feedback throughout the app
@MainActor
public class HapticManager {
    public static let shared = HapticManager()
    
    private let impactLight = UIImpactFeedbackGenerator(style: .light)
    private let impactMedium = UIImpactFeedbackGenerator(style: .medium)
    private let impactHeavy = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionGenerator = UISelectionFeedbackGenerator()
    private let notificationGenerator = UINotificationFeedbackGenerator()
    
    private init() {
        // Prepare generators for optimal performance
        prepareGenerators()
    }
    
    private func prepareGenerators() {
        impactLight.prepare()
        impactMedium.prepare()
        impactHeavy.prepare()
        selectionGenerator.prepare()
        notificationGenerator.prepare()
    }
    
    // MARK: - Public API
    
    /// Triggers impact feedback
    /// - Parameter style: The intensity of the impact
    public func impact(_ style: ImpactStyle) {
        guard isHapticsEnabled else { return }
        
        switch style {
        case .light:
            impactLight.impactOccurred()
        case .medium:
            impactMedium.impactOccurred()
        case .heavy:
            impactHeavy.impactOccurred()
        }
    }
    
    /// Triggers selection feedback (for picker changes, toggle switches)
    public func selection() {
        guard isHapticsEnabled else { return }
        selectionGenerator.selectionChanged()
    }
    
    /// Triggers notification feedback
    /// - Parameter type: The type of notification
    public func notification(_ type: NotificationType) {
        guard isHapticsEnabled else { return }
        
        switch type {
        case .success:
            notificationGenerator.notificationOccurred(.success)
        case .warning:
            notificationGenerator.notificationOccurred(.warning)
        case .error:
            notificationGenerator.notificationOccurred(.error)
        }
    }
    
    // MARK: - Settings
    
    private var isHapticsEnabled: Bool {
        // Check if device supports haptics and user hasn't disabled them
        return UIDevice.current.userInterfaceIdiom == .phone
    }
}

// MARK: - Supporting Types

public enum ImpactStyle {
    case light
    case medium
    case heavy
}

public enum NotificationType {
    case success
    case warning
    case error
}

// MARK: - Convenience Extensions

public extension HapticManager {
    /// Quick success feedback for completed actions
    func success() {
        notification(.success)
    }
    
    /// Quick error feedback for failed actions
    func error() {
        notification(.error)
    }
    
    /// Quick warning feedback for cautionary actions
    func warning() {
        notification(.warning)
    }
    
    /// Button tap feedback
    func buttonTap() {
        impact(.light)
    }
    
    /// Toggle switch feedback
    func toggle() {
        selection()
    }
    
    /// Slider adjustment feedback
    func sliderAdjust() {
        impact(.light)
    }
}