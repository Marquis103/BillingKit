//
//  BillingServicePurchaseOptionsTests.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

#if !os(Android)

import Foundation
import StoreKit
import Testing
@testable import BillingKit

/// The StoreKit pass-through for `purchase(_:appAccountToken:)`,
/// checked at the seam `BillingService` hands to
/// `Product.purchase(options:)` — deterministic under `swift test`,
/// no `SKTestSession`. The end-to-end round trip (the token coming
/// back on the transaction) lives in `BillingServiceTests`.
@Suite("BillingService purchase options")
struct BillingServicePurchaseOptionsTests {

    @Test("A nil token sends no purchase options — today's purchase() call")
    func nilTokenSendsNoOptions() {
        #expect(BillingService.purchaseOptions(appAccountToken: nil).isEmpty)
    }

    @Test("A token is sent as exactly one appAccountToken purchase option carrying the caller's UUID")
    func tokenBecomesAppAccountTokenOption() throws {
        let token = try #require(UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF"))

        let options = BillingService.purchaseOptions(appAccountToken: token)

        #expect(options.count == 1)
        let option = try #require(options.first)
        // Kind check: StoreKit equality matches any `.appAccountToken`.
        #expect(option == StoreKit.Product.PurchaseOption.appAccountToken(UUID()))
        // Value check: the option carries this exact UUID.
        #expect(carriedUUIDs(in: option) == [token])
    }

    @Test("Each call carries its own token — no token is reused across purchases")
    func distinctTokensAreCarriedDistinctly() throws {
        let first = UUID()
        let second = UUID()

        let a = try #require(BillingService.purchaseOptions(appAccountToken: first).first)
        let b = try #require(BillingService.purchaseOptions(appAccountToken: second).first)

        #expect(carriedUUIDs(in: a) == [first])
        #expect(carriedUUIDs(in: b) == [second])
    }

    @Test("BillingService implements the token member itself — an unbacked product fails on the kit's guard, not the compatibility default")
    func unbackedProductWithTokenHitsTheBackingGuard() async {
        let verifier = MockReceiptVerifier()
        let service = BillingService(productIDs: [], verifier: verifier)
        let billing: any BillingServicing = service
        let product = BillingProduct(
            id: "unbacked", displayName: "", description: "",
            displayPrice: "", price: 0, currencyCode: "USD"
        )

        let result = await billing.purchase(product, appAccountToken: UUID())

        guard case .failed(.purchaseFailed(let message)) = result else {
            Issue.record("Expected .failed(.purchaseFailed), got \(result)")
            return
        }
        #expect(message.contains("no StoreKit backing"))
        #expect(verifier.callCount == 0)
    }

    // MARK: - Private

    /// Every `UUID` reachable inside `value`, depth-first.
    /// `StoreKit.Product.PurchaseOption`'s `Equatable` / `Hashable`
    /// compare the option KIND only (`.appAccountToken(a) ==
    /// .appAccountToken(b)` for any `a`, `b`), so the carried token is
    /// read back by reflection. The walk matches on type, not on
    /// StoreKit's private labels; a layout change makes it return `[]`,
    /// which fails the expectation rather than passing it.
    private func carriedUUIDs(in value: Any) -> [UUID] {
        if let uuid = value as? UUID { return [uuid] }
        return Mirror(reflecting: value).children.flatMap { carriedUUIDs(in: $0.value) }
    }
}

#endif // !os(Android)
