//
//  BillingService.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
import StoreKit

/// Default `BillingServicing` implementation. Wraps StoreKit 2 with
/// the kit's invariants:
///
///   * Every transaction (purchase, restore, out-of-band update)
///     flows through the injected `ReceiptVerifier` BEFORE
///     `transaction.finish()` is called. There is exactly one code
///     path — `verifyAndFinish(_:)` — that finishes transactions, so
///     no future change can accidentally bypass verification.
///   * Product fetches are cached for 5 minutes. StoreKit can be
///     slow on cold cache, and paywall renders frequently re-fetch
///     the same product list — the cache absorbs that.
///   * `transactionStream` is created once in `init` and lives for
///     the service's lifetime. A long-running background task feeds
///     it from `Transaction.updates`. Cancelling the actor cancels
///     the task via `deinit`.
public actor BillingService: BillingServicing {

    // MARK: - Properties

    public nonisolated let transactionStream: AsyncStream<BillingTransaction>

    private let productIDs: Set<String>
    private let gate: VerificationGate
    private let streamContinuation: AsyncStream<BillingTransaction>.Continuation
    private let cacheTTL: TimeInterval = 300

    private var cachedProducts: [BillingProduct]?
    private var cacheTimestamp: Date?
    private var transactionUpdatesTask: Task<Void, Never>?

    // MARK: - Lifecycle

    /// Build a billing service.
    ///
    /// - Parameters:
    ///   - productIDs: The set of StoreKit product IDs this service
    ///     resolves and purchases. Typically loaded from app config
    ///     (xcconfig, Info.plist, or a hard-coded constant for
    ///     single-tier apps).
    ///   - verifier: The server-side receipt verifier. See
    ///     `ReceiptVerifier` for the contract. The kit deliberately
    ///     ships no default — every verifier is host-provided so
    ///     production builds cannot accidentally ship without one.
    public init(productIDs: Set<String>, verifier: ReceiptVerifier) {
        self.productIDs = productIDs
        self.gate = VerificationGate(verifier: verifier)

        var continuation: AsyncStream<BillingTransaction>.Continuation!
        self.transactionStream = AsyncStream { continuation = $0 }
        self.streamContinuation = continuation
    }

    deinit {
        transactionUpdatesTask?.cancel()
        streamContinuation.finish()
    }

    // MARK: - Observation lifecycle

    /// Spawn the long-running task that drains
    /// `StoreKit.Transaction.updates` and routes each event through
    /// the verifier chokepoint. Idempotent.
    ///
    /// **Lifecycle (no retain cycle):** the task captures `self`
    /// weakly. The actor holds the task handle in
    /// `transactionUpdatesTask`, but a task handle does not retain
    /// `self`. When the host drops its last reference to the service,
    /// the actor deallocates normally, `deinit` cancels the task
    /// handle, and the for-await loop exits on cancellation (Apple's
    /// AsyncSequence implementations honor `Task.isCancelled`). A
    /// verifier call in flight at the moment of teardown will hold
    /// `self` briefly via the implicit `await` retain; the actor
    /// finishes the call and then deallocates.
    public func startObservingTransactionUpdates() {
        guard transactionUpdatesTask == nil else { return }
        transactionUpdatesTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                guard let self else { return }
                do {
                    _ = try await self.verifyAndFinish(update)
                } catch {
                    // Verifier rejected — leave transaction unfinished
                    // so StoreKit retries on next launch. Nothing to
                    // surface here; host observes the stream.
                    continue
                }
            }
        }
    }

    public func stopObservingTransactionUpdates() {
        transactionUpdatesTask?.cancel()
        transactionUpdatesTask = nil
    }

    // MARK: - BillingServicing

    public func fetchProducts() async throws -> [BillingProduct] {
        if let cached = cachedProducts,
           let stamp = cacheTimestamp,
           Date().timeIntervalSince(stamp) < cacheTTL {
            return cached
        }

        let storeKitProducts: [StoreKit.Product]
        do {
            storeKitProducts = try await StoreKit.Product.products(for: Array(productIDs))
        } catch {
            throw BillingError.unknown(String(describing: error))
        }

        guard !storeKitProducts.isEmpty else {
            throw BillingError.productsUnavailable
        }

        var mapped: [BillingProduct] = []
        mapped.reserveCapacity(storeKitProducts.count)
        for product in storeKitProducts {
            mapped.append(await BillingProduct(storeKitProduct: product))
        }

        cachedProducts = mapped
        cacheTimestamp = Date()
        return mapped
    }

    public func purchase(_ product: BillingProduct) async -> BillingPurchaseResult {
        let storeKitProduct = product.storeKitProduct.product

        let result: StoreKit.Product.PurchaseResult
        do {
            result = try await storeKitProduct.purchase()
        } catch {
            return .failed(.purchaseFailed(String(describing: error)))
        }

        switch result {
        case .success(let verificationResult):
            do {
                let transaction = try await verifyAndFinish(verificationResult)
                return .success(transaction)
            } catch let error as BillingError {
                return .failed(error)
            } catch {
                return .failed(.unknown(String(describing: error)))
            }
        case .userCancelled:
            return .cancelled
        case .pending:
            return .pending
        @unknown default:
            return .failed(.unknown("Unknown StoreKit purchase result"))
        }
    }

    public func restorePurchases() async throws -> [BillingTransaction] {
        do {
            try await AppStore.sync()
        } catch {
            throw BillingError.unknown(String(describing: error))
        }

        var restored: [BillingTransaction] = []
        for await verification in StoreKit.Transaction.currentEntitlements {
            do {
                let transaction = try await verifyWithoutFinishing(verification)
                if transaction.revocationDate == nil {
                    restored.append(transaction)
                }
            } catch {
                // Skip entitlements that fail verification — host
                // shouldn't see entitlements the server rejected.
                continue
            }
        }
        return restored
    }

    public func currentEntitlements() async -> [BillingTransaction] {
        var entitlements: [BillingTransaction] = []
        let now = Date()
        for await verification in StoreKit.Transaction.currentEntitlements {
            guard case .verified(let transaction) = verification else { continue }
            if let revoked = transaction.revocationDate, revoked <= now { continue }
            if let expires = transaction.expirationDate, expires <= now { continue }
            entitlements.append(BillingTransaction(transaction: transaction))
        }
        return entitlements
    }

    // MARK: - Private

    /// The single chokepoint that calls `transaction.finish()`. Runs
    /// the verifier first; on success, finishes the transaction and
    /// yields to `transactionStream`; on failure, throws and leaves
    /// the transaction unfinished so StoreKit re-delivers later.
    private func verifyAndFinish(
        _ result: StoreKit.VerificationResult<StoreKit.Transaction>
    ) async throws -> BillingTransaction {
        switch result {
        case .unverified(_, let error):
            throw BillingError.verificationFailed(String(describing: error))
        case .verified(let transaction):
            try await gate.verify(jws: result.jwsRepresentation)
            let billing = BillingTransaction(transaction: transaction)
            await transaction.finish()
            streamContinuation.yield(billing)
            return billing
        }
    }

    /// `restorePurchases` and `currentEntitlements` flow through here
    /// because the transactions have already been finished — we
    /// re-verify (so a revoked / fraudulent entitlement gets stripped)
    /// but DO NOT call `finish()` again.
    private func verifyWithoutFinishing(
        _ result: StoreKit.VerificationResult<StoreKit.Transaction>
    ) async throws -> BillingTransaction {
        switch result {
        case .unverified(_, let error):
            throw BillingError.verificationFailed(String(describing: error))
        case .verified(let transaction):
            try await gate.verify(jws: result.jwsRepresentation)
            return BillingTransaction(transaction: transaction)
        }
    }

}
