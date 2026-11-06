//
//  BillingServicingDefaultPurchaseTests.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
import Testing
@testable import BillingKit

/// The protocol-extension default for `purchase(_:appAccountToken:)`,
/// exercised through a conformer that implements `purchase(_:)` only
/// — the shape of every conformer written against 1.1.0.
@Suite("BillingServicing compatibility default for purchase(_:appAccountToken:)")
struct BillingServicingDefaultPurchaseTests {

    private let product = BillingProduct(
        id: "com.thatSwiftGuy.ayes.pro.monthly", displayName: "", description: "",
        displayPrice: "", price: 0, currencyCode: "USD"
    )

    @Test("A nil token forwards to purchase(_:) and returns its result unchanged")
    func nilTokenForwardsToPurchase() async {
        let service = MockLegacyBillingService(stubbedPurchaseResult: .pending)
        let billing: any BillingServicing = service

        let result = await billing.purchase(product, appAccountToken: nil)

        #expect(result == .pending)
        #expect(service.purchasedProductIDs == [product.id])
    }

    @Test("A token on a conformer that cannot attach it fails closed without starting a purchase")
    func tokenFailsClosedOnLegacyConformer() async {
        let service = MockLegacyBillingService(stubbedPurchaseResult: .pending)
        let billing: any BillingServicing = service

        let result = await billing.purchase(product, appAccountToken: UUID())

        guard case .failed(.purchaseFailed(let message)) = result else {
            Issue.record("Expected .failed(.purchaseFailed), got \(result)")
            return
        }
        #expect(message.contains(product.id))
        #expect(service.purchasedProductIDs.isEmpty)
    }

    @Test("purchase(_:) on an existing conformer is untouched by the new member")
    func existingPurchaseEntryPointIsUnchanged() async {
        let service = MockLegacyBillingService(stubbedPurchaseResult: .cancelled)

        let result = await service.purchase(product)

        #expect(result == .cancelled)
        #expect(service.purchasedProductIDs == [product.id])
    }
}
