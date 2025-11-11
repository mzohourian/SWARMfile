//
//  Ads.swift
//  OneBox - Ads Module
//
//  Non-tracking banner ads for free tier users
//

import SwiftUI

// MARK: - Ad Banner View
public struct AdBannerView: View {
    @State private var isVisible = true

    public init() {}

    public var body: some View {
        if isVisible {
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    // Placeholder ad content
                    Image(systemName: "sparkles")
                        .foregroundColor(.orange)
                        .font(.title3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Upgrade to Pro")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Remove ads and unlock unlimited exports")
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                }
                .padding()
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
        }
    }
}

// MARK: - Ad Manager
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
