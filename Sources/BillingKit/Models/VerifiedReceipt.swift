//
//  VerifiedReceipt.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation

/// Outcome of a successful `ReceiptVerifier.verify(_:)` call. Carries
/// the canonical, server-authoritative view of a transaction.
///
/// `BillingKit` does not currently consume the fields beyond
/// confirming the call returned (vs. threw) — the host typically uses
/// the receipt to update its own entitlement record. Surfaced as a
/// type rather than `Void` so future kit features (entitlement
/// expiry caching, revocation hooks) can read it without breaking
/// the protocol shape.
public struct VerifiedReceipt: Sendable, Equatable {

    /// The product ID the server confirmed this receipt is for.
    /// Hosts should trust this over any client-side product ID — the
    /// server saw the JWS payload directly.
    public let productID: String

    /// The original transaction ID (constant across renewals of the
    /// same subscription). Use this as the durable key for
    /// per-subscriber records, not `transactionID` (which changes on
    /// each renewal).
    public let originalTransactionID: String

    /// Server-confirmed purchase timestamp.
    public let purchaseDate: Date

    /// For subscriptions, when the current period ends. Nil for
    /// non-renewing one-shot purchases.
    public let expiresDate: Date?

    /// Set when the App Store has revoked this receipt (refund,
    /// family-sharing removal, etc.). Hosts MUST check this and
    /// strip the entitlement when non-nil — Apple considers a
    /// revoked transaction still in entitlements to be a policy
    /// violation.
    public let revocationDate: Date?

    public init(
        productID: String,
        originalTransactionID: String,
        purchaseDate: Date,
        expiresDate: Date? = nil,
        revocationDate: Date? = nil
    ) {
        self.productID = productID
        self.originalTransactionID = originalTransactionID
        self.purchaseDate = purchaseDate
        self.expiresDate = expiresDate
        self.revocationDate = revocationDate
    }
}
