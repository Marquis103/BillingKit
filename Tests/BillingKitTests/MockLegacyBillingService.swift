//
//  MockLegacyBillingService.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
@testable import BillingKit

/// A `BillingServicing` conformer written before
/// `purchase(_:appAccountToken:)` existed: it implements `purchase(_:)`
/// only, so the token-taking member resolves to the protocol
/// extension's compatibility default. Records `purchase(_:)` calls.
final class MockLegacyBillingService: BillingServicing, @unchecked Sendable {

    private let lock = NSLock()
    private var _purchasedProductIDs: [String] = []
    private let stubbedPurchaseResult: BillingPurchaseResult

    let transactionStream: AsyncStream<BillingTransaction> = AsyncStream { _ in }

    init(stubbedPurchaseResult: BillingPurchaseResult = .cancelled) {
        self.stubbedPurchaseResult = stubbedPurchaseResult
    }

    var purchasedProductIDs: [String] {
        lock.lock()
        defer { lock.unlock() }
        return _purchasedProductIDs
    }

    func fetchProducts() async throws -> [BillingProduct] { [] }

    func purchase(_ product: BillingProduct) async -> BillingPurchaseResult {
        record(product.id)
        return stubbedPurchaseResult
    }

    func restorePurchases() async throws -> [BillingTransaction] { [] }
    func currentEntitlements() async -> [BillingTransaction] { [] }
    func startObservingTransactionUpdates() async {}
    func stopObservingTransactionUpdates() async {}

    // MARK: - Private

    /// Synchronous, so the lock is never taken from an async context.
    private func record(_ productID: String) {
        lock.lock()
        defer { lock.unlock() }
        _purchasedProductIDs.append(productID)
    }
}
