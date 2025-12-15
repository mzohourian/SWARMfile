//
//  OneBoxStandard.swift
//  OneBox - Design System
//
//  The OneBox Standard: Privacy-first luxury experience with ceremony of security
//

import SwiftUI
import UIKit

// MARK: - OneBox Standard Colors
public struct OneBoxColors {
    // Dark Graphite Palette
    public static let primaryGraphite = Color(red: 0.12, green: 0.12, blue: 0.13) // #1E1E21
    public static let secondaryGraphite = Color(red: 0.16, green: 0.16, blue: 0.17) // #28282B
    public static let tertiaryGraphite = Color(red: 0.20, green: 0.20, blue: 0.22) // #333337
    public static let surfaceGraphite = Color(red: 0.24, green: 0.24, blue: 0.26) // #3D3D42
    
    // Refined Gold Accents
    public static let primaryGold = Color(red: 0.85, green: 0.65, blue: 0.13) // #D9A521
    public static let secondaryGold = Color(red: 0.78, green: 0.60, blue: 0.15) // #C79926
    public static let mutedGold = Color(red: 0.85, green: 0.65, blue: 0.13, opacity: 0.3)
    
    // Security Status Colors
    public static let secureGreen = Color(red: 0.20, green: 0.78, blue: 0.35) // #33C759
    public static let warningAmber = Color(red: 1.0, green: 0.80, blue: 0.0) // #FFCC00
    public static let criticalRed = Color(red: 1.0, green: 0.23, blue: 0.19) // #FF3B30
    
    // Text Colors
    public static let primaryText = Color.white
    public static let secondaryText = Color.white.opacity(0.7)
    public static let tertiaryText = Color.white.opacity(0.5)
    public static let goldText = primaryGold
    
    // Overlay Colors
    public static let overlay = Color.black.opacity(0.6)
    public static let glassOverlay = Color.white.opacity(0.05)
}

// MARK: - OneBox Standard Typography
public struct OneBoxTypography {
    public static let heroTitle = Font.system(size: 28, weight: .bold, design: .default)
    public static let sectionTitle = Font.system(size: 22, weight: .semibold, design: .default)
    public static let cardTitle = Font.system(size: 18, weight: .medium, design: .default)
    public static let body = Font.system(size: 16, weight: .regular, design: .default)
    public static let caption = Font.system(size: 14, weight: .medium, design: .default)
    public static let badge = Font.system(size: 12, weight: .semibold, design: .default)
    public static let micro = Font.system(size: 10, weight: .medium, design: .default)
}

// MARK: - OneBox Standard Spacing
public struct OneBoxSpacing {
    public static let micro: CGFloat = 4
    public static let tiny: CGFloat = 8
    public static let small: CGFloat = 12
    public static let medium: CGFloat = 16
    public static let large: CGFloat = 24
    public static let xl: CGFloat = 32
    public static let xxl: CGFloat = 48
    public static let heroSpacing: CGFloat = 64
}

// MARK: - OneBox Standard Corner Radius
public struct OneBoxRadius {
    public static let small: CGFloat = 8
    public static let medium: CGFloat = 12
    public static let large: CGFloat = 16
    public static let xl: CGFloat = 20
    public static let card: CGFloat = 16
    public static let button: CGFloat = 12
}

// MARK: - Ceremony of Security Badge
public struct SecurityBadge: View {
    let style: Style
    
    public enum Style {
        case minimal, prominent, floating
    }
    
    public init(style: Style = .minimal) {
        self.style = style
    }
    
    public var body: some View {
        HStack(spacing: OneBoxSpacing.micro) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: badgeIconSize, weight: .semibold))
                .foregroundColor(OneBoxColors.secureGreen)
            
            Text("On-Device Secure")
                .font(OneBoxTypography.badge)
                .foregroundColor(OneBoxColors.primaryText)
        }
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(backgroundView)
        .cornerRadius(OneBoxRadius.small)
        .shadow(color: shadowColor, radius: shadowRadius)
    }
    
    private var badgeIconSize: CGFloat {
        switch style {
        case .minimal: return 10
        case .prominent: return 12
        case .floating: return 14
        }
    }
    
    private var horizontalPadding: CGFloat {
        switch style {
        case .minimal: return OneBoxSpacing.tiny
        case .prominent: return OneBoxSpacing.small
        case .floating: return OneBoxSpacing.medium
        }
    }
    
    private var verticalPadding: CGFloat {
        switch style {
        case .minimal: return OneBoxSpacing.micro
        case .prominent: return OneBoxSpacing.tiny
        case .floating: return OneBoxSpacing.small
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .minimal:
            OneBoxColors.surfaceGraphite.opacity(0.8)
        case .prominent:
            OneBoxColors.tertiaryGraphite
        case .floating:
            OneBoxColors.glassOverlay
                .background(.ultraThinMaterial)
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .minimal: return .clear
        case .prominent: return OneBoxColors.primaryGraphite.opacity(0.3)
        case .floating: return OneBoxColors.primaryGraphite.opacity(0.5)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .minimal: return 0
        case .prominent: return 2
        case .floating: return 8
        }
    }
}

// MARK: - OneBox Standard Card
public struct OneBoxCard<Content: View>: View {
    let content: Content
    let style: CardStyle
    
    public enum CardStyle {
        case standard, elevated, interactive, security
    }
    
    public init(style: CardStyle = .standard, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }
    
    public var body: some View {
        content
            .padding(OneBoxSpacing.medium)
            .background(backgroundView)
            .cornerRadius(OneBoxRadius.card)
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowOffset)
            .overlay(
                RoundedRectangle(cornerRadius: OneBoxRadius.card)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .standard:
            OneBoxColors.secondaryGraphite
        case .elevated:
            OneBoxColors.tertiaryGraphite
        case .interactive:
            OneBoxColors.surfaceGraphite
        case .security:
            LinearGradient(
                colors: [OneBoxColors.tertiaryGraphite, OneBoxColors.secondaryGraphite],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var shadowColor: Color {
        switch style {
        case .standard: return OneBoxColors.primaryGraphite.opacity(0.3)
        case .elevated: return OneBoxColors.primaryGraphite.opacity(0.5)
        case .interactive: return OneBoxColors.primaryGraphite.opacity(0.4)
        case .security: return OneBoxColors.primaryGold.opacity(0.2)
        }
    }
    
    private var shadowRadius: CGFloat {
        switch style {
        case .standard: return 4
        case .elevated: return 8
        case .interactive: return 6
        case .security: return 12
        }
    }
    
    private var shadowOffset: CGFloat {
        switch style {
        case .standard: return 2
        case .elevated: return 4
        case .interactive: return 3
        case .security: return 6
        }
    }
    
    private var borderColor: Color {
        switch style {
        case .standard, .elevated, .interactive: return .clear
        case .security: return OneBoxColors.mutedGold
        }
    }
    
    private var borderWidth: CGFloat {
        switch style {
        case .standard, .elevated, .interactive: return 0
        case .security: return 1
        }
    }
}

// MARK: - OneBox Standard Button
public struct OneBoxButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    let isDisabled: Bool
    
    public enum ButtonStyle {
        case primary, secondary, security, subtle, critical
    }
    
    public init(_ title: String, icon: String? = nil, style: ButtonStyle = .primary, isDisabled: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }
    
    public var body: some View {
        Button(action: action) {
            HStack(spacing: OneBoxSpacing.tiny) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }

                Text(title)
                    .font(OneBoxTypography.body)
                    .fontWeight(.medium)
            }
            .foregroundColor(isDisabled ? disabledTextColor : textColor)
            .padding(.horizontal, OneBoxSpacing.medium)
            .padding(.vertical, OneBoxSpacing.small)
            .background(isDisabled ? disabledBackgroundView : backgroundView)
            .cornerRadius(OneBoxRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: OneBoxRadius.button)
                    .stroke(isDisabled ? OneBoxColors.tertiaryText.opacity(0.3) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(OneBoxButtonStyle(style: style))
        .disabled(isDisabled)
        .saturation(isDisabled ? 0.3 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isDisabled)
    }

    private var disabledTextColor: Color {
        OneBoxColors.tertiaryText
    }

    @ViewBuilder
    private var disabledBackgroundView: some View {
        OneBoxColors.surfaceGraphite.opacity(0.5)
    }
    
    private var textColor: Color {
        switch style {
        case .primary, .critical: return OneBoxColors.primaryGraphite
        case .secondary, .subtle: return OneBoxColors.primaryText
        case .security: return OneBoxColors.primaryGraphite
        }
    }
    
    @ViewBuilder
    private var backgroundView: some View {
        switch style {
        case .primary:
            OneBoxColors.primaryGold
        case .secondary:
            OneBoxColors.surfaceGraphite
        case .security:
            LinearGradient(
                colors: [OneBoxColors.primaryGold, OneBoxColors.secondaryGold],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .subtle:
            OneBoxColors.glassOverlay
        case .critical:
            OneBoxColors.criticalRed
        }
    }
}

// MARK: - Button Style for Haptic Feedback
struct OneBoxButtonStyle: ButtonStyle {
    let style: OneBoxButton.ButtonStyle
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { isPressed in
                if isPressed {
                    // Haptic feedback based on button style
                    switch style {
                    case .primary, .security:
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred()
                    case .secondary, .subtle:
                        let generator = UIImpactFeedbackGenerator(style: .light)
                        generator.impactOccurred()
                    case .critical:
                        let generator = UIImpactFeedbackGenerator(style: .heavy)
                        generator.impactOccurred()
                    }
                }
            }
    }
}


// MARK: - Usage Meter
public struct UsageMeter: View {
    let current: Int
    let limit: Int
    let type: String // "exports", "processes", etc.
    
    public init(current: Int, limit: Int, type: String) {
        self.current = current
        self.limit = limit
        self.type = type
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: OneBoxSpacing.tiny) {
            HStack {
                Text("\(current) of \(limit) secure \(type) used")
                    .font(OneBoxTypography.caption)
                    .foregroundColor(OneBoxColors.secondaryText)
                
                Spacer()
                
                if isNearLimit {
                    Text("Upgrade Soon")
                        .font(OneBoxTypography.micro)
                        .foregroundColor(OneBoxColors.goldText)
                        .padding(.horizontal, OneBoxSpacing.tiny)
                        .padding(.vertical, OneBoxSpacing.micro)
                        .background(OneBoxColors.mutedGold)
                        .cornerRadius(OneBoxRadius.small)
                }
            }
            
            ProgressView(value: progress)
                .progressViewStyle(OneBoxProgressStyle(color: progressColor))
        }
        .padding(OneBoxSpacing.small)
        .background(OneBoxColors.surfaceGraphite.opacity(0.5))
        .cornerRadius(OneBoxRadius.small)
    }
    
    private var progress: Double {
        guard limit > 0 else { return 0 }
        return min(1.0, Double(current) / Double(limit))
    }
    
    private var isNearLimit: Bool {
        progress >= 0.8
    }
    
    private var progressColor: Color {
        if progress >= 0.9 {
            return OneBoxColors.criticalRed
        } else if progress >= 0.7 {
            return OneBoxColors.warningAmber
        } else {
            return OneBoxColors.primaryGold
        }
    }
}

// MARK: - OneBox Progress Style
struct OneBoxProgressStyle: ProgressViewStyle {
    let color: Color
    
    func makeBody(configuration: Configuration) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(OneBoxColors.primaryGraphite.opacity(0.3))
                    .frame(height: 4)
                    .cornerRadius(2)
                
                Rectangle()
                    .fill(color)
                    .frame(
                        width: geometry.size.width * CGFloat(configuration.fractionCompleted ?? 0),
                        height: 4
                    )
                    .cornerRadius(2)
                    .animation(.easeInOut(duration: 0.3), value: configuration.fractionCompleted)
            }
        }
        .frame(height: 4)
    }
}

// MARK: - Concierge Tone Utilities
public struct ConciergeCopy {
    public static let privacyHero = "Your documents, your device, your peace of mind."
    public static let processingComplete = "Beautifully processed and securely stored."
    public static let upgradeInvitation = "Unlock unlimited secure processing."
    public static let workflowSuggestion = "We've noticed you often compress after merging. Would you like to automate this?"
    public static let securityAssurance = "All processing happens locally on your device."
    public static let qualityInsight = "This PDF could benefit from compression to reduce file size."
    public static let duplicateDetected = "Duplicate pages detected. Consider organizing for clarity."
    public static let lowQualityWarning = "Some images may appear blurry after conversion."
    public static let exportPreview = "Review your export before saving."
}