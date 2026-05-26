//
//  BillingError.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation

/// Failure modes surfaced by `BillingService`. The cases distinguish
/// "App Store reachable but disagreed" (`productNotFound`,
/// `purchaseFailed`) from "verifier rejected the receipt"
/// (`verificationFailed`) from "user said no" (`userCancelled`) — the
/// host typically surfaces each differently in UI (silent, alert,
/// no-op respectively).
public enum BillingError: Error, Sendable, Equatable {

    /// `StoreKit.Product.products(for:)` returned an empty array.
    /// Usually means the product IDs aren't configured in App Store
    /// Connect for the current bundle ID / environment, or the
    /// device has no network. Host should retry, not show a permanent
    /// error.
    case productsUnavailable

    /// A specific product ID couldn't be resolved. Distinct from
    /// `productsUnavailable` — here some products came back but not
    /// the one the caller asked to purchase. Strongly suggests a
    /// typo in the configured product ID list.
    case productNotFound(String)

    /// The injected `ReceiptVerifier` threw, or the server rejected
    /// the signed transaction. The associated message is the
    /// verifier's error description — `BillingKit` does not interpret
    /// the body; host decides whether to retry, log, or escalate.
    case verificationFailed(String)

    /// `StoreKit.Product.purchase()` returned `.success(.unverified)`
    /// or threw, and the failure does not fit the more specific
    /// cases above. The associated string carries Apple's error
    /// description for diagnostics.
    case purchaseFailed(String)

    /// User dismissed the system purchase sheet without confirming.
    /// Hosts should treat this as a no-op, NOT an error to surface.
    case userCancelled

    /// Catch-all for anything else that can throw out of StoreKit
    /// (unexpected `StoreKitError` variants, etc.). Used sparingly —
    /// the goal is to land specific cases above as StoreKit's
    /// surface area stabilizes.
    case unknown(String)
}
