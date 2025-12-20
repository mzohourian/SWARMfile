//
//  Ads.swift
//  OneBox - Ads Module
//
//  Non-tracking banner ads for free tier users
//

import SwiftUI
import UIComponents

// MARK: - Ad Banner View
@available(iOS 14.0, macOS 11.0, *)
public struct AdBannerView: View {
    @State private var isVisible = true

    public init() {}

    public var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Placeholder ad content
                    Image(systemName: "sparkles")
                        .foregroundColor(OneBoxColors.primaryGold)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to Pro")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(OneBoxColors.primaryText)
                        Text("Remove ads and unlock unlimited exports")
                            .font(.caption)
                            .foregroundColor(OneBoxColors.secondaryText)
                    }

                    Spacer()

                    Button {
                        // Will be handled by navigation
                    } label: {
                        Text("Upgrade")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(OneBoxColors.primaryGold)
                            .foregroundColor(OneBoxColors.primaryGraphite)
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(OneBoxColors.secondaryGraphite)
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(OneBoxColors.primaryGold.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Ad Manager
@available(iOS 14.0, macOS 11.0, *)
public class AdManager: ObservableObject {
    public static let shared = AdManager()

    @Published public var adsEnabled: Bool = true

    private init() {
        loadSettings()
    }

    private func loadSettings() {
        // Check feature flag
        adsEnabled = UserDefaults.standard.bool(forKey: "ads_enabled")
    }

    public func setAdsEnabled(_ enabled: Bool) {
        adsEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "ads_enabled")
    }

    // Non-tracking ad impression logging (local only)
    public func logImpression() {
        let impressions = UserDefaults.standard.integer(forKey: "ad_impressions")
        UserDefaults.standard.set(impressions + 1, forKey: "ad_impressions")
    }
}

#if DEBUG
@available(iOS 14.0, macOS 11.0, *)
struct AdBannerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            AdBannerView()
                .padding()
            Spacer()
        }
    }
}
#endif
