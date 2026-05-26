//
//  BillingServicing.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation

/// Public surface of `BillingService`. Exists so host apps can mock
/// the billing layer in unit tests without spinning up an
/// `SKTestSession` — the same pattern used by `NotificationsServicing`
/// and `PersistenceServicing` in the sibling kits.
///
/// `Sendable` is required: the concrete service is an actor, and
/// callers will routinely pass the instance across actor boundaries
/// (DI containers, view models, app coordinator).
public protocol BillingServicing: Sendable {

    /// Resolve the configured product IDs against the App Store.
    /// Cached for 5 minutes — back-to-back calls within the window
    /// return the cached array without a network round-trip.
    ///
    /// - Throws: `BillingError.productsUnavailable` if the App Store
    ///   returns an empty result (network failure, no products
    ///   configured for this bundle ID, etc.).
    func fetchProducts() async throws -> [BillingProduct]

    /// Trigger the system purchase sheet for `product`.
    ///
    /// - Returns: A `BillingPurchaseResult` distinguishing success
    ///   (verifier approved + transaction finished), pending (parental
    ///   approval required), cancellation (user dismissed sheet), and
    ///   failure. All failure modes route through `.failed(BillingError)` —
    ///   pattern-match on the result, the method does not throw.
    func purchase(_ product: BillingProduct) async -> BillingPurchaseResult

    /// Force a sync with the App Store and return the user's current
    /// unrevoked entitlements. Each transaction passes through the
    /// verifier; entitlements that fail verification are omitted from
    /// the result.
    ///
    /// Tied to the "Restore Purchases" affordance the App Store
    /// guidelines require.
    func restorePurchases() async throws -> [BillingTransaction]

    /// Synchronous-style snapshot of currently-valid entitlements.
    /// Reads from `Transaction.currentEntitlements`, filters out
    /// expired and revoked, and returns the survivors. Does NOT
    /// re-run the verifier — the assumption is the entitlements were
    /// already verified when first finished. Use this on app launch
    /// to gate UI; use `restorePurchases()` when the user explicitly
    /// asks to restore.
    func currentEntitlements() async -> [BillingTransaction]

    /// Live stream of verified transactions arriving via
    /// `StoreKit.Transaction.updates`. Includes renewals, refunds,
    /// family-sharing revocations, and any other out-of-band changes
    /// the App Store pushes after install.
    ///
    /// The stream is created once at service init and reused for the
    /// service's lifetime. The kit does NOT start consuming
    /// `Transaction.updates` automatically — call
    /// `startObservingTransactionUpdates()` once at app launch (after
    /// wiring your consumers) so test code that constructs a service
    /// for a fetch-only check doesn't leak a background task.
    var transactionStream: AsyncStream<BillingTransaction> { get }

    /// Start the background task that consumes
    /// `StoreKit.Transaction.updates` and yields verified results to
    /// `transactionStream`. Idempotent — calling more than once is a
    /// no-op. Hosts typically call this once at app launch.
    func startObservingTransactionUpdates() async

    /// Cancel the background updates task started by
    /// `startObservingTransactionUpdates()`. Idempotent. Tests use
    /// this to tear down between cases; production hosts rarely need
    /// to call it (the service typically lives for the app's
    /// lifetime).
    func stopObservingTransactionUpdates() async
}
