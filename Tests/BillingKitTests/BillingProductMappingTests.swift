//
//  BillingProductMappingTests.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import StoreKit
import StoreKitTest
import Testing
@testable import BillingKit

/// Same caveat as `BillingServiceTests` — `SKTestSession` only works
/// under the Xcode IDE / clean-state `xcodebuild test`, not under
/// SwiftPM CLI.
@Suite(
    "BillingProduct (StoreKit.Product mapping)",
    .serialized,
    .disabled("Run interactively via Xcode IDE — SKTestSession state is fragile under SwiftPM / xcodebuild CLI")
)
struct BillingProductMappingTests {

    @Test("Subscription product maps id, display name, price, and group metadata")
    func mapsSubscriptionProductFields() async throws {
        let url = try #require(
            Bundle.module.url(forResource: "BillingKitTests", withExtension: "storekit")
        )
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        session.clearTransactions()
        defer { session.clearTransactions() }

        let products = try await StoreKit.Product.products(
            for: ["com.thatSwiftGuy.ayes.pro.monthly"]
        )
        let raw = try #require(products.first)
        let mapped = await BillingProduct(storeKitProduct: raw)

        #expect(mapped.id == "com.thatSwiftGuy.ayes.pro.monthly")
        #expect(mapped.displayName == "Ayes Pro Monthly")
        #expect(mapped.description == "Unlock the full Ayes Pro experience.")
        #expect(mapped.displayPrice.contains("4.99"))
        #expect(mapped.price == Decimal(string: "4.99"))
        #expect(mapped.currencyCode == "USD")

        let group = try #require(mapped.subscriptionGroup)
        #expect(group.isFamilyShareable == false)
    }

    @Test("Identifiable id matches productID")
    func identifiableIDMatchesProductID() async throws {
        let url = try #require(
            Bundle.module.url(forResource: "BillingKitTests", withExtension: "storekit")
        )
        let session = try SKTestSession(contentsOf: url)
        session.disableDialogs = true
        defer { session.clearTransactions() }

        let products = try await StoreKit.Product.products(
            for: ["com.thatSwiftGuy.ayes.pro.monthly"]
        )
        let raw = try #require(products.first)
        let mapped = await BillingProduct(storeKitProduct: raw)
        #expect(mapped.id == raw.id)
    }
}
