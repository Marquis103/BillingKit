//
//  BillingPurchaseResult.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation

/// Outcome of `BillingService.purchase(_:)`.
///
/// Three "not an error" outcomes plus one error case — pattern-match,
/// don't try/catch, when consuming the result:
///
/// ```swift
/// switch try await billing.purchase(product) {
/// case .success(let transaction):
///     await coordinator.openConfirmation(transaction)
/// case .pending:
///     await coordinator.showAskToBuyPending()
/// case .cancelled:
///     // No-op; user changed their mind.
///     break
/// case .failed(let error):
///     await coordinator.showError(error)
/// }
/// ```
public enum BillingPurchaseResult: Sendable, Equatable {

    /// Purchase completed and the verifier approved. The transaction
    /// has already been finished by `BillingService` — host just
    /// updates its UI / entitlement cache.
    case success(BillingTransaction)

    /// Apple deferred the purchase, typically because parental
    /// approval ("Ask to Buy") is required. The user has NOT been
    /// charged. The eventual outcome arrives later through
    /// `transactionStream` once the parent approves or denies.
    case pending

    /// User dismissed the system purchase sheet without confirming.
    /// Not an error from the host's perspective — surface no UI.
    case cancelled

    /// Verifier rejected the receipt, StoreKit threw, or the purchase
    /// otherwise failed. The transaction was NOT finished; StoreKit
    /// may re-deliver on next launch.
    case failed(BillingError)
}
