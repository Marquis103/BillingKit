//
//  BillingTransaction.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
#if !os(Android)
import StoreKit
#endif

/// `Sendable`, decoded snapshot of `StoreKit.Transaction`. Crosses
/// the actor boundary out of `BillingService` so view models in the
/// host don't have to import `StoreKit` directly — the kit owns the
/// platform type and exposes a flat value to consumers.
///
/// Only the fields the kit guarantees (post-verification) are
/// surfaced; the underlying `StoreKit.Transaction` is intentionally
/// not exposed because it lacks `Sendable` conformance and would
/// force `@unchecked` workarounds in every consumer.
public struct BillingTransaction: Sendable, Equatable, Identifiable {

    /// The per-transaction unique identifier. Changes on every
    /// renewal of a subscription — use `originalTransactionID` for
    /// durable per-subscriber keying.
    public let transactionID: String

    /// Constant across the lifetime of a subscription (including
    /// renewals, upgrades, downgrades). Use as the durable identity
    /// for entitlement records, server-side subscriber rows, etc.
    public let originalTransactionID: String

    /// The product ID this transaction grants entitlement to.
    public let productID: String

    /// When the user purchased (or, for renewals, when the renewal
    /// occurred).
    public let purchaseDate: Date

    /// For subscriptions, the end of the current paid period. Nil
    /// for non-renewing purchases.
    public let expiresDate: Date?

    /// Set when the App Store has revoked the transaction (refund,
    /// family-share removal). Hosts MUST drop the entitlement when
    /// non-nil.
    public let revocationDate: Date?

    /// True when the transaction was implicitly finished because the
    /// user upgraded to a higher tier within the same subscription
    /// group. Treat the new transaction (delivered via
    /// `transactionStream`) as the authoritative entitlement.
    public let isUpgraded: Bool

    public var id: String { transactionID }

    public init(
        transactionID: String,
        originalTransactionID: String,
        productID: String,
        purchaseDate: Date,
        expiresDate: Date? = nil,
        revocationDate: Date? = nil,
        isUpgraded: Bool = false
    ) {
        self.transactionID = transactionID
        self.originalTransactionID = originalTransactionID
        self.productID = productID
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.revocationDate = revocationDate
        self.isUpgraded = isUpgraded
    }
}

// Android: excluded — StoreKit.Transaction decode. Successor: SkipMarketplaceBillingAdapter
// (W5.4b) maps Play purchases through the public memberwise initializer above.
#if !os(Android)

extension BillingTransaction {

    /// Internal-only initializer that decodes a StoreKit transaction
    /// into the flat value type. Kept `internal` so the host doesn't
    /// accidentally bypass `BillingService`'s verifier flow.
    init(transaction: StoreKit.Transaction) {
        self.transactionID = String(transaction.id)
        self.originalTransactionID = String(transaction.originalID)
        self.productID = transaction.productID
        self.purchaseDate = transaction.purchaseDate
        self.expiresDate = transaction.expirationDate
        self.revocationDate = transaction.revocationDate
        self.isUpgraded = transaction.isUpgraded
    }
}

#endif // !os(Android)
