//
//  BillingProduct.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
import StoreKit

/// `Sendable` projection of `StoreKit.Product`. Carries the fields a
/// paywall typically renders (display name, description, price) plus
/// a private hold on the underlying `Product` so
/// `BillingService.purchase(_:)` can call `.purchase()` on it
/// without re-fetching.
///
/// The underlying `StoreKit.Product` is intentionally not exposed:
/// it lacks `Sendable` conformance and pinning it to the public
/// surface would force every consumer into `@unchecked Sendable`
/// workarounds. The kit hands back a flat value; the kit alone
/// reaches through to `Product` when it needs to.
public struct BillingProduct: Sendable, Identifiable, Equatable {

    /// The StoreKit product ID (e.g.
    /// `"com.thatSwiftGuy.ayes.pro.monthly"`).
    public let id: String

    /// Localized display name from App Store Connect.
    public let displayName: String

    /// Localized description from App Store Connect.
    public let description: String

    /// Pre-formatted price string (e.g. `"$4.99"`). Use this in UI;
    /// it already reflects the user's locale and the product's
    /// currency. Avoid re-formatting `price` + `currencyCode`
    /// yourself unless you have a reason — locale rules are
    /// surprisingly nuanced.
    public let displayPrice: String

    /// Raw numeric price. Useful for analytics, comparisons, or
    /// custom formatting when the locale-aware string isn't enough.
    public let price: Decimal

    /// ISO 4217 currency code (e.g. `"USD"`).
    public let currencyCode: String

    /// Subscription-group context, when the product is an
    /// auto-renewing subscription. Nil for one-shot consumables /
    /// non-renewing products.
    public let subscriptionGroup: SubscriptionGroup?

    /// Private hold on the StoreKit product so `purchase()` doesn't
    /// have to re-resolve by ID. Excluded from `Equatable` (compared
    /// via `id` only) and from `Sendable` checks (boxed through the
    /// `Sendable`-via-`@unchecked` wrapper below).
    let storeKitProduct: StoreKitProductBox

    public static func == (lhs: BillingProduct, rhs: BillingProduct) -> Bool {
        lhs.id == rhs.id
    }

    init(
        id: String,
        displayName: String,
        description: String,
        displayPrice: String,
        price: Decimal,
        currencyCode: String,
        subscriptionGroup: SubscriptionGroup?,
        storeKitProduct: StoreKit.Product
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = currencyCode
        self.subscriptionGroup = subscriptionGroup
        self.storeKitProduct = StoreKitProductBox(storeKitProduct)
    }
}

extension BillingProduct {

    /// Map a `StoreKit.Product` into the kit's flat value. Pulls
    /// subscription metadata when the product is a subscription;
    /// otherwise `subscriptionGroup` is `nil`.
    ///
    /// `isEligibleForIntroOffer` is read from
    /// `subscriptionInfo.isEligibleForIntroOffer` when available; that
    /// API became reliable in iOS 17.4. Older runtimes fall through
    /// to `true` (the optimistic default) — the system purchase
    /// sheet will still enforce the actual eligibility, so the
    /// downside is showing a paywall with intro copy the user can't
    /// actually claim.
    init(storeKitProduct product: StoreKit.Product) async {
        let group: SubscriptionGroup?
        if let subscription = product.subscription {
            let eligible: Bool
            if #available(iOS 17.4, *) {
                eligible = await subscription.isEligibleForIntroOffer
            } else {
                eligible = true
            }
            group = SubscriptionGroup(
                groupID: subscription.subscriptionGroupID,
                displayName: subscription.groupLevel.description,
                isEligibleForIntroOffer: eligible,
                isFamilyShareable: product.isFamilyShareable
            )
        } else {
            group = nil
        }

        self.init(
            id: product.id,
            displayName: product.displayName,
            description: product.description,
            displayPrice: product.displayPrice,
            price: product.price,
            currencyCode: product.priceFormatStyle.currencyCode,
            subscriptionGroup: group,
            storeKitProduct: product
        )
    }
}

/// Internal wrapper that lets `BillingProduct` keep a hold on a
/// `StoreKit.Product` without exposing the non-`Sendable` type to
/// consumers. `@unchecked Sendable` is safe here because
/// `StoreKit.Product` is documented as thread-safe for read access,
/// and the box only ever reads.
struct StoreKitProductBox: @unchecked Sendable {
    let product: StoreKit.Product

    init(_ product: StoreKit.Product) {
        self.product = product
    }
}
