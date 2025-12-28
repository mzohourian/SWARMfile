//
//  PaywallView.swift
//  OneBox
//

import SwiftUI
import StoreKit
import Payments
import LocalAuthentication

struct PaywallView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var paymentsManager: PaymentsManager

    @State private var selectedProduct: Product?
    @State private var isPurchasing = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var isAuthenticating = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    headerView

                    // Features
                    featuresView

                    // Products
                    productsView

                    // Purchase Button
                    purchaseButton

                    // Restore
                    restoreButton

                    // Fine Print
                    finePrint
                }
                .padding()
            }
            .navigationTitle("Vault PDF Pro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var headerView: some View {
        VStack(spacing: 16) {
            // Brand logo with PRO badge
            ZStack(alignment: .bottomTrailing) {
                Image("VaultLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .shadow(color: Color.orange.opacity(0.3), radius: 12, x: 0, y: 0)

                // PRO badge
                Text("PRO")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        LinearGradient(
                            colors: [.orange, .yellow],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(8)
                    .offset(x: 4, y: 4)
            }

            Text("Unlock All Features")
                .font(.title)
                .fontWeight(.bold)

            Text("Get unlimited exports, remove ads, and support development")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top)
    }

    private var featuresView: some View {
        VStack(spacing: 16) {
            FeatureRow(icon: "infinity", title: "Unlimited Exports", description: "Process as many files as you need")
            FeatureRow(icon: "bolt.fill", title: "Priority Processing", description: "Faster background processing")
            FeatureRow(icon: "paintbrush.fill", title: "Custom Presets", description: "Save your favorite settings")
            FeatureRow(icon: "app.badge.checkmark.fill", title: "Shortcuts Power User", description: "Advanced automation features")
            FeatureRow(icon: "eye.slash.fill", title: "No Ads", description: "Clean, distraction-free experience")
            FeatureRow(icon: "heart.fill", title: "Support Development", description: "Help us build more features")
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private var productsView: some View {
        VStack(spacing: 12) {
            ForEach(paymentsManager.products, id: \.id) { product in
                ProductCard(
                    product: product,
                    isSelected: selectedProduct?.id == product.id,
                    savings: savingsText(for: product)
                ) {
                    selectedProduct = product
                }
            }
        }
    }

    private var purchaseButton: some View {
        Button {
            purchase()
        } label: {
            HStack {
                if isPurchasing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(purchaseButtonText)
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: [.orange, .yellow],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(selectedProduct == nil || isPurchasing)
        .opacity(selectedProduct == nil ? 0.5 : 1.0)
    }

    private var restoreButton: some View {
        Button {
            restore()
        } label: {
            Text("Restore Purchases")
                .font(.subheadline)
                .foregroundColor(.accentColor)
        }
        .disabled(isPurchasing)
    }

    private var finePrint: some View {
        VStack(spacing: 8) {
            Text("• Payment charged to Apple ID at confirmation")
            Text("• Subscriptions auto-renew unless cancelled 24h before period ends")
            Text("• Manage subscriptions in App Store settings")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
    }

    private var purchaseButtonText: String {
        guard let product = selectedProduct else {
            return "Select a Plan"
        }
        if isAuthenticating {
            return "Authenticating..."
        }
        return "Get Pro for \(product.displayPrice)"
    }

    private func savingsText(for product: Product) -> String? {
        if product.id.contains("yearly"),
           let monthly = paymentsManager.product(for: .monthly) {
            let savings = paymentsManager.savingsPercentage(yearly: product, monthly: monthly)
            // Fallback: if calculation returns 0 but we know yearly is ~50% off
            if savings > 0 {
                return "Save \(savings)%"
            } else {
                // Calculate manually: yearly $29.99 vs monthly $4.99*12 = $59.88 ≈ 50% off
                let yearlyPrice = NSDecimalNumber(decimal: product.price).doubleValue
                let monthlyYearly = NSDecimalNumber(decimal: monthly.price).doubleValue * 12
                if monthlyYearly > 0 {
                    let manualSavings = Int(((monthlyYearly - yearlyPrice) / monthlyYearly) * 100)
                    return "Save \(manualSavings)%"
                }
                return "Save 50%"
            }
        } else if product.id.contains("lifetime") {
            return "Best Value"
        }
        return nil
    }

    private func purchase() {
        guard let product = selectedProduct else { return }

        isPurchasing = true
        isAuthenticating = true
        
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            let reason = "Authenticate to complete your OneBox Pro purchase"
            
            context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason) { success, authenticationError in
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    
                    if success {
                        self.executePurchase(product)
                    } else {
                        self.isPurchasing = false
                        self.errorMessage = authenticationError?.localizedDescription ?? "Authentication failed"
                        self.showError = true
                    }
                }
            }
        } else {
            // No biometrics available, proceed with standard flow
            isAuthenticating = false
            executePurchase(product)
        }
    }
    
    private func executePurchase(_ product: Product) {
        Task {
            do {
                try await paymentsManager.purchase(product)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
            isPurchasing = false
        }
    }

    private func restore() {
        isPurchasing = true

        Task {
            await paymentsManager.restorePurchases()
            isPurchasing = false

            if paymentsManager.hasPro {
                dismiss()
            } else {
                errorMessage = "No purchases found to restore"
                showError = true
            }
        }
    }
}

// MARK: - Feature Row
struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.orange)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }
}

// MARK: - Product Card
struct ProductCard: View {
    let product: Product
    let isSelected: Bool
    let savings: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(productTitle)
                        .font(.headline)

                    Text(productDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(product.displayPrice)
                        .font(.title3)
                        .fontWeight(.bold)

                    if let period = subscriptionPeriod {
                        Text(period)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .orange : .secondary)
                    .font(.title3)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(isSelected ? Color.orange : Color.clear, lineWidth: 2)
                    )
            )
            .overlay(alignment: .topTrailing) {
                if let savings = savings {
                    Text(savings)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .offset(x: -8, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var productTitle: String {
        if product.id.contains("monthly") {
            return "Pro Monthly"
        } else if product.id.contains("yearly") {
            return "Pro Yearly"
        } else {
            return "Pro Lifetime"
        }
    }

    private var productDescription: String {
        if product.id.contains("monthly") {
            return "All features, billed monthly"
        } else if product.id.contains("yearly") {
            return "All features, best value"
        } else {
            return "Pay once, own forever"
        }
    }

    private var subscriptionPeriod: String? {
        if product.id.contains("monthly") {
            return "per month"
        } else if product.id.contains("yearly") {
            return "per year"
        }
        return nil
    }
}

#Preview {
    PaywallView()
        .environmentObject(PaymentsManager.shared)
}
