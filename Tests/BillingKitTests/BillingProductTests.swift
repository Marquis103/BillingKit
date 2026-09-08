//
//  BillingProductTests.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
import Testing
@testable import BillingKit

@Suite("BillingProduct (portable value)")
struct BillingProductTests {

    @Test("Public initializer carries every field")
    func publicInitStoresFields() {
        let group = SubscriptionGroup(
            groupID: "21500000",
            isEligibleForIntroOffer: true,
            isFamilyShareable: false
        )
        let product = BillingProduct(
            id: "com.thatSwiftGuy.ayes.pro.monthly",
            displayName: "Ayes Pro Monthly",
            description: "Unlock the full Ayes Pro experience.",
            displayPrice: "$4.99",
            price: Decimal(string: "4.99")!,
            currencyCode: "USD",
            subscriptionGroup: group
        )
        #expect(product.id == "com.thatSwiftGuy.ayes.pro.monthly")
        #expect(product.displayName == "Ayes Pro Monthly")
        #expect(product.description == "Unlock the full Ayes Pro experience.")
        #expect(product.displayPrice == "$4.99")
        #expect(product.price == Decimal(string: "4.99"))
        #expect(product.currencyCode == "USD")
        #expect(product.subscriptionGroup == group)
    }

    @Test("Equality compares id only — display fields don't participate")
    func equalityIsIDOnly() {
        let a = BillingProduct(
            id: "p", displayName: "A", description: "",
            displayPrice: "$1", price: 1, currencyCode: "USD"
        )
        let b = BillingProduct(
            id: "p", displayName: "B", description: "x",
            displayPrice: "$2", price: 2, currencyCode: "EUR"
        )
        let c = BillingProduct(
            id: "q", displayName: "A", description: "",
            displayPrice: "$1", price: 1, currencyCode: "USD"
        )
        #expect(a == b)
        #expect(a != c)
    }

#if !os(Android)
    /// The first *enabled* test to exercise a `BillingService` code
    /// path: the unbacked-product guard fires before any StoreKit
    /// call, so it runs deterministically under plain `swift test`
    /// (no `SKTestSession`).
    @Test("purchase on a hand-constructed product fails without touching StoreKit")
    func purchaseWithoutBackingFails() async {
        let verifier = MockReceiptVerifier()
        let service = BillingService(productIDs: [], verifier: verifier)
        let product = BillingProduct(
            id: "unbacked", displayName: "", description: "",
            displayPrice: "", price: 0, currencyCode: "USD"
        )
        let result = await service.purchase(product)
        guard case .failed(.purchaseFailed) = result else {
            Issue.record("Expected .failed(.purchaseFailed), got \(result)")
            return
        }
        #expect(verifier.callCount == 0)
    }
#endif
}
