//
//  Payments.swift
//  OneBox - Payments Module
//
//  StoreKit 2 IAP management with subscriptions and lifetime unlock
//

import Foundation
import StoreKit

// MARK: - Payments Manager
@MainActor
public class PaymentsManager: ObservableObject {

    public static let shared = PaymentsManager()

    // Product IDs
    public enum ProductID: String, CaseIterable {
        case monthly = "com.onebox.pro.monthly"
        case yearly = "com.onebox.pro.yearly"
        case lifetime = "com.onebox.pro.lifetime"

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

    // Free tier tracking
    @Published public private(set) var dailyExportsUsed: Int = 0
    private let maxFreeExports = 3

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
        return Task.detached {
            for await result in Transaction.updates {
                guard let transaction = try? self.checkVerified(result) else {
                    continue
                }

                await transaction.finish()
                await self.updatePurchasedProducts()
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
        !purchasedProductIDs.isEmpty
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

    // MARK: - Product Helpers
    public func product(for id: ProductID) -> Product? {
        products.first { $0.id == id.rawValue }
    }

    public func localizedPrice(for product: Product) -> String {
        product.displayPrice
    }

    public func savingsPercentage(yearly: Product, monthly: Product) -> Int {
        let yearlyPrice = yearly.price
        let monthlyYearlyEquivalent = monthly.price * 12

        let savings = (monthlyYearlyEquivalent - yearlyPrice) / monthlyYearlyEquivalent
        return Int(savings * 100)
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
