//
//  SubscriptionGroup.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation

/// Snapshot of the subscription-group context for a product.
///
/// StoreKit 2 groups auto-renewing subscriptions into a "subscription
/// group" so the system can offer upgrade / downgrade / crossgrade
/// transitions between tiers. Two facts hosts most often need at
/// paywall-render time:
///
///   * **Intro-offer eligibility** — Apple only lets a customer use
///     the intro offer once per group. If the user has previously
///     subscribed to ANY product in this group, the offer is gone.
///     Pre-checking this avoids rendering "7 days free" copy that
///     the system sheet will then quietly drop.
///
///   * **Family-shareable** — set in App Store Connect; affects what
///     copy the paywall should show ("Available for Family Sharing"
///     badge vs. nothing).
///
/// Both fields reflect the snapshot at the moment `fetchProducts()`
/// resolved — they don't live-update. Re-fetch when the customer
/// completes a purchase if you need fresh values.
///
/// There is intentionally no `displayName` — StoreKit 2 doesn't
/// expose a localized group name (`groupLevel` is an Int tier rank).
/// Hosts supply tier copy from their own localization file.
public struct SubscriptionGroup: Sendable, Equatable {

    /// The opaque group identifier from App Store Connect. Useful as
    /// a key when the host caches per-group state.
    public let groupID: String

    /// True if the customer is currently eligible for the
    /// introductory offer attached to this group. False once they've
    /// used it on any product in the group.
    public let isEligibleForIntroOffer: Bool

    /// True if the product is enabled for Family Sharing in App
    /// Store Connect.
    public let isFamilyShareable: Bool

    public init(
        groupID: String,
        isEligibleForIntroOffer: Bool,
        isFamilyShareable: Bool
    ) {
        self.groupID = groupID
        self.isEligibleForIntroOffer = isEligibleForIntroOffer
        self.isFamilyShareable = isFamilyShareable
    }
}
