//
//  Payments.swift
//  OneBox - Payments Module
//
//  StoreKit 2 IAP management with subscriptions and lifetime unlock
//

import Foundation
import StoreKit

// MARK: - Payments Manager
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class PaymentsManager: ObservableObject {

    public static let shared = PaymentsManager()

    // Product IDs
    public enum ProductID: String, CaseIterable {
        case monthly = "com.spuud.vaultpdf.pro.monthly"
        case yearly = "com.spuud.vaultpdf.pro.yearly"
        case lifetime = "com.spuud.vaultpdf.pro.lifetime"

        var displayName: String {
            switch self {
            case .monthly: return "Pro Monthly"
            case .yearly: return "Pro Yearly"
            case .lifetime: return "Pro Lifetime"
            }
        }

        var description: String {
            switch self {
            case .monthly: return "Unlimited exports, no ads"
            case .yearly: return "Unlimited exports, no ads, best value"
            case .lifetime: return "One-time purchase, unlimited forever"
            }
        }
    }

    // Published properties
    @Published public private(set) var products: [Product] = []
    @Published public private(set) var purchasedProductIDs: Set<String> = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: PaymentError?

    // MARK: - Beta Testing Mode
    // TODO: Set to false before App Store release
    private let isBetaTesting = true  // Unlocks all Pro features for TestFlight beta

    // Free tier tracking
    @Published public private(set) var dailyExportsUsed: Int = 0
    private let maxFreeExports = 3  // Production limit for free tier
    
    // Computed properties for OneBox Standard views
    public var exportsUsed: Int { dailyExportsUsed }
    public var freeExportLimit: Int { maxFreeExports }

    private var updateListenerTask: Task<Void, Never>?

    private init() {}

    // MARK: - Initialization
    public func initialize() async {
        updateListenerTask = listenForTransactions()
        await loadProducts()
        await updatePurchasedProducts()
        loadDailyExports()
    }

    deinit {
        updateListenerTask?.cancel()
    }

    // MARK: - Product Loading
    private func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let productIDs = ProductID.allCases.map { $0.rawValue }
            products = try await Product.products(for: productIDs)
                .sorted { product1, product2 in
                    // Sort: monthly, yearly, lifetime
                    let order = [ProductID.monthly.rawValue, ProductID.yearly.rawValue, ProductID.lifetime.rawValue]
                    let index1 = order.firstIndex(of: product1.id) ?? 999
                    let index2 = order.firstIndex(of: product2.id) ?? 999
                    return index1 < index2
                }
        } catch {
            self.error = .loadFailed(error.localizedDescription)
        }
    }

    // MARK: - Purchase
    public func purchase(_ product: Product) async throws {
        isLoading = true
        defer { isLoading = false }

        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await transaction.finish()
            await updatePurchasedProducts()

        case .userCancelled:
            throw PaymentError.userCancelled

        case .pending:
            throw PaymentError.purchasePending

        @unknown default:
            throw PaymentError.unknown
        }
    }

    // MARK: - Restore Purchases
    public func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }

        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
        } catch {
            self.error = .restoreFailed(error.localizedDescription)
        }
    }

    // MARK: - Transaction Verification
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw PaymentError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Transaction Listener
    private func listenForTransactions() -> Task<Void, Never> {
        return Task {
            for await result in Transaction.updates {
                guard let transaction = try? checkVerified(result) else {
                    continue
                }

                await transaction.finish()
                await updatePurchasedProducts()
            }
        }
    }

    // MARK: - Update Purchased Products
    private func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else {
                continue
            }

            if transaction.revocationDate == nil {
                purchasedIDs.insert(transaction.productID)
            }
        }

        purchasedProductIDs = purchasedIDs
    }

    // MARK: - Pro Status
    public var hasPro: Bool {
        isBetaTesting || !purchasedProductIDs.isEmpty
    }

    public var hasActiveSubscription: Bool {
        purchasedProductIDs.contains(ProductID.monthly.rawValue) ||
        purchasedProductIDs.contains(ProductID.yearly.rawValue)
    }

    public var hasLifetime: Bool {
        purchasedProductIDs.contains(ProductID.lifetime.rawValue)
    }

    // MARK: - Free Tier Management
    public var canExport: Bool {
        hasPro || dailyExportsUsed < maxFreeExports
    }
    
    public var canViewOnly: Bool {
        // View-only mode: can view/manage existing files but not create new exports
        !hasPro && dailyExportsUsed >= maxFreeExports
    }
    
    public var isLastFreeExport: Bool {
        !hasPro && dailyExportsUsed == maxFreeExports - 1
    }

    public var remainingFreeExports: Int {
        hasPro ? 999 : max(0, maxFreeExports - dailyExportsUsed)
    }

    public func consumeExport() {
        guard !hasPro else { return }

        dailyExportsUsed += 1
        saveDailyExports()
    }

    private func loadDailyExports() {
        let defaults = UserDefaults.standard
        let lastResetDate = defaults.object(forKey: "last_export_reset") as? Date ?? .distantPast
        let today = Calendar.current.startOfDay(for: Date())

        if lastResetDate < today {
            // Reset counter for new day
            dailyExportsUsed = 0
            defaults.set(today, forKey: "last_export_reset")
            defaults.set(0, forKey: "daily_exports_used")
        } else {
            dailyExportsUsed = defaults.integer(forKey: "daily_exports_used")
        }
    }

    private func saveDailyExports() {
        let defaults = UserDefaults.standard
        defaults.set(dailyExportsUsed, forKey: "daily_exports_used")
    }

    /// Resets the daily export counter (for testing or manual reset)
    public func resetDailyExports() {
        dailyExportsUsed = 0
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: "last_export_reset")
        defaults.set(0, forKey: "daily_exports_used")
    }

    // MARK: - Product Helpers
    public func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    public func localizedPrice(for product: Product) -> String {
        product.displayPrice
    }

    public func savingsPercentage(yearly: Product, monthly: Product) -> Int {
        let yearlyPrice = yearly.price
        let monthlyYearlyEquivalent = monthly.price * Decimal(12)

        let savings = (monthlyYearlyEquivalent - yearlyPrice) / monthlyYearlyEquivalent
        return Int(truncating: (savings * Decimal(100)) as NSDecimalNumber)
    }
}

// MARK: - Payment Error
public enum PaymentError: LocalizedError {
    case loadFailed(String)
    case purchaseFailed(String)
    case userCancelled
    case purchasePending
    case verificationFailed
    case restoreFailed(String)
    case unknown

    public var errorDescription: String? {
        switch self {
        case .loadFailed(let message):
            return "Failed to load products: \(message)"
        case .purchaseFailed(let message):
            return "Purchase failed: \(message)"
        case .userCancelled:
            return "Purchase cancelled"
        case .purchasePending:
            return "Purchase is pending approval"
        case .verificationFailed:
            return "Could not verify purchase"
        case .restoreFailed(let message):
            return "Failed to restore purchases: \(message)"
        case .unknown:
            return "An unknown error occurred"
        }
    }
}

// MARK: - Subscription Status
@available(iOS 15.0, macOS 12.0, *)
public struct SubscriptionStatus {
    public let isActive: Bool
    public let productID: String?
    public let expirationDate: Date?
    public let isLifetime: Bool

    public var displayText: String {
        if isLifetime {
            return "Pro Lifetime"
        } else if isActive, let expiration = expirationDate {
            return "Active until \(expiration.formatted(date: .abbreviated, time: .omitted))"
        } else {
            return "Inactive"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension PaymentsManager {
    public func getSubscriptionStatus() async -> SubscriptionStatus {
        if hasLifetime {
            return SubscriptionStatus(
                isActive: true,
                productID: ProductID.lifetime.rawValue,
                expirationDate: nil,
                isLifetime: true
            )
        }

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result),
                  transaction.revocationDate == nil,
                  let expirationDate = transaction.expirationDate else {
                continue
            }

            return SubscriptionStatus(
                isActive: true,
                productID: transaction.productID,
                expirationDate: expirationDate,
                isLifetime: false
            )
        }

        return SubscriptionStatus(
            isActive: false,
            productID: nil,
            expirationDate: nil,
            isLifetime: false
        )
    }
}
