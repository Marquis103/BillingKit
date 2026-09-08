//
//  BillingProduct.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
#if !os(Android)
import StoreKit
#endif

/// `Sendable` projection of `StoreKit.Product`. Carries the fields a
/// paywall typically renders (display name, description, price) plus,
/// on Darwin, a private hold on the underlying `Product` so
/// `BillingService.purchase(_:)` can call `.purchase()` on it
/// without re-fetching.
///
/// The underlying `StoreKit.Product` is intentionally not exposed:
/// it lacks `Sendable` conformance and pinning it to the public
/// surface would force every consumer into `@unchecked Sendable`
/// workarounds. The kit hands back a flat value; the kit alone
/// reaches through to `Product` when it needs to. The public surface
/// is identical on every platform — only the private hold is
/// Darwin-gated, which is what lets the type (and the whole
/// `BillingServicing` seam) compile for Android.
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

#if !os(Android)
    /// Private hold on the StoreKit product so `purchase()` doesn't
    /// have to re-resolve by ID. `nil` for values built with the
    /// public initializer (host mocks, non-StoreKit stores) —
    /// `BillingService.purchase(_:)` refuses those with
    /// `.failed(.purchaseFailed)`. Excluded from `Equatable`
    /// (compared via `id` only) and from `Sendable` checks (boxed
    /// through the `Sendable`-via-`@unchecked` wrapper below).
    /// Darwin-only: the Play Billing adapter
    /// (SkipMarketplaceBillingAdapter, W5.4b) re-resolves by `id`
    /// instead of holding a platform object.
    let storeKitProduct: StoreKitProductBox?
#endif

    public static func == (lhs: BillingProduct, rhs: BillingProduct) -> Bool {
        lhs.id == rhs.id
    }

    /// Portable public initializer. Values built this way carry no
    /// StoreKit backing: on Darwin, passing one to
    /// `BillingService.purchase(_:)` returns
    /// `.failed(.purchaseFailed(...))` — purchase only products
    /// obtained from `fetchProducts()`. Intended for host test
    /// mocks/previews and for non-StoreKit billing adapters
    /// (Play Billing, W5.4b).
    public init(
        id: String,
        displayName: String,
        description: String,
        displayPrice: String,
        price: Decimal,
        currencyCode: String,
        subscriptionGroup: SubscriptionGroup? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.description = description
        self.displayPrice = displayPrice
        self.price = price
        self.currencyCode = currencyCode
        self.subscriptionGroup = subscriptionGroup
#if !os(Android)
        self.storeKitProduct = nil
#endif
    }

#if !os(Android)
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
#endif
}

// Android: excluded — StoreKit.Product mapping + the live-product box.
// Successor: skip-marketplace Play Billing adapter (SkipMarketplaceBillingAdapter), W5.4b.
#if !os(Android)

extension BillingProduct {

    /// Map a `StoreKit.Product` into the kit's flat value. Pulls
    /// subscription metadata when the product is a subscription;
    /// otherwise `subscriptionGroup` is `nil`.
    ///
    /// `isEligibleForIntroOffer` is read from
    /// `subscriptionInfo.isEligibleForIntroOffer` when available; that
    /// API became reliable in iOS 17.4. Older runtimes fall through
    /// to `false` — showing "7 days free" copy a user can't actually
    /// claim looks like a bait-and-switch in the paywall and has
    /// drawn App Store review attention before; under-selling the
    /// offer is the safer side to err on.
    init(storeKitProduct product: StoreKit.Product) async {
        let group: SubscriptionGroup?
        if let subscription = product.subscription {
            let eligible: Bool
            if #available(iOS 17.4, *) {
                eligible = await subscription.isEligibleForIntroOffer
            } else {
                eligible = false
            }
            group = SubscriptionGroup(
                groupID: subscription.subscriptionGroupID,
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
/// consumers. `@unchecked Sendable` is sound here because every
/// consumer reaches the boxed `product` from inside `BillingService`
/// (an actor), so all access is serialized through a single
/// isolation domain — there is no concurrent reader/writer pair to
/// race. The box never mutates the product; it only forwards `.purchase()`.
struct StoreKitProductBox: @unchecked Sendable {
    let product: StoreKit.Product

    init(_ product: StoreKit.Product) {
        self.product = product
    }
}

#endif // !os(Android)
