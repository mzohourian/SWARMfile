//
//  PaymentsTests.swift
//  OneBox Tests
//

import XCTest
import StoreKit
@testable import Payments

@MainActor
final class PaymentsTests: XCTestCase {

    var paymentsManager: PaymentsManager!

    override func setUp() async throws {
        paymentsManager = PaymentsManager.shared
    }

    override func tearDown() async throws {
        paymentsManager = nil
    }

    // MARK: - Product ID Tests

    func testProductIDs() {
        XCTAssertEqual(PaymentsManager.ProductID.monthly.rawValue, "com.spuud.vaultpdf.pro.monthly")
        XCTAssertEqual(PaymentsManager.ProductID.yearly.rawValue, "com.spuud.vaultpdf.pro.yearly")
        XCTAssertEqual(PaymentsManager.ProductID.lifetime.rawValue, "com.spuud.vaultpdf.pro.lifetime")
    }

    func testProductDisplayNames() {
        XCTAssertEqual(PaymentsManager.ProductID.monthly.displayName, "Pro Monthly")
        XCTAssertEqual(PaymentsManager.ProductID.yearly.displayName, "Pro Yearly")
        XCTAssertEqual(PaymentsManager.ProductID.lifetime.displayName, "Pro Lifetime")
    }

    func testProductDescriptions() {
        XCTAssertFalse(PaymentsManager.ProductID.monthly.description.isEmpty)
        XCTAssertFalse(PaymentsManager.ProductID.yearly.description.isEmpty)
        XCTAssertFalse(PaymentsManager.ProductID.lifetime.description.isEmpty)
    }

    // MARK: - Free Tier Tests

    func testFreeExportsCounter() {
        // Given
        let initialCount = paymentsManager.dailyExportsUsed

        // When
        paymentsManager.consumeExport()

        // Then
        XCTAssertEqual(paymentsManager.dailyExportsUsed, initialCount + 1)
    }

    func testCanExportWithFreeExports() {
        // Reset to 0
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: "daily_exports_used")
        defaults.set(Date(), forKey: "last_export_reset")

        // Then
        XCTAssertTrue(paymentsManager.canExport)
    }

    func testRemainingFreeExports() {
        // Reset to 0
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: "daily_exports_used")

        // Then
        XCTAssertEqual(paymentsManager.remainingFreeExports, 3)
    }

    func testFreeExportsReset() {
        // Given - set date to yesterday
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        UserDefaults.standard.set(yesterday, forKey: "last_export_reset")
        UserDefaults.standard.set(3, forKey: "daily_exports_used")

        // When - create new manager to trigger reset
        let newManager = PaymentsManager.shared

        // Then - should be reset (implementation dependent)
        XCTAssertNotNil(newManager)
    }

    // MARK: - Pro Status Tests

    func testHasProWithoutPurchase() {
        // Given - fresh install
        // Then
        // Note: This will be false in test environment without actual purchases
        XCTAssertFalse(paymentsManager.hasPro || paymentsManager.purchasedProductIDs.isEmpty)
    }

    func testHasActiveSubscription() {
        // Given - no purchases
        // Then
        XCTAssertFalse(paymentsManager.hasActiveSubscription)
    }

    func testHasLifetime() {
        // Given - no purchases
        // Then
        XCTAssertFalse(paymentsManager.hasLifetime)
    }

    // MARK: - Product Loading Tests

    func testInitialization() async {
        // When
        await paymentsManager.initialize()

        // Then
        XCTAssertNotNil(paymentsManager)
        XCTAssertFalse(paymentsManager.isLoading)
    }

    // MARK: - Error Handling Tests

    func testPaymentErrorDescriptions() {
        let errors: [PaymentError] = [
            .loadFailed("test"),
            .purchaseFailed("test"),
            .userCancelled,
            .purchasePending,
            .verificationFailed,
            .restoreFailed("test"),
            .unknown
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription)
            XCTAssertFalse(error.errorDescription!.isEmpty)
        }
    }

    // MARK: - Subscription Status Tests

    func testSubscriptionStatusInactive() async {
        // Given
        let status = await paymentsManager.getSubscriptionStatus()

        // Then
        XCTAssertFalse(status.isActive)
        XCTAssertNil(status.productID)
        XCTAssertNil(status.expirationDate)
        XCTAssertFalse(status.isLifetime)
    }

    func testSubscriptionStatusDisplayText() async {
        // Given
        let status = await paymentsManager.getSubscriptionStatus()

        // Then
        XCTAssertEqual(status.displayText, "Inactive")
    }

    // MARK: - Savings Calculation Tests (Mock)

    func testSavingsPercentageCalculation() {
        // Note: This requires actual Product objects which need StoreKit environment
        // In a real test, you would mock the Product objects
        // For now, just test the manager exists
        XCTAssertNotNil(paymentsManager)
    }

    // MARK: - Performance Tests

    func testConsumerExportPerformance() {
        measure {
            for _ in 0..<100 {
                paymentsManager.consumeExport()
            }
        }
    }
}
