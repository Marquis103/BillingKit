//
//  BillingErrorTests.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Testing
@testable import BillingKit

@Suite("BillingError")
struct BillingErrorTests {

    @Test("Cases with associated values compare by payload")
    func equalityHonorsAssociatedValues() {
        #expect(BillingError.productNotFound("a") == .productNotFound("a"))
        #expect(BillingError.productNotFound("a") != .productNotFound("b"))
        #expect(BillingError.verificationFailed("x") == .verificationFailed("x"))
        #expect(BillingError.verificationFailed("x") != .verificationFailed("y"))
    }

    @Test("Cases without payloads are equal to themselves")
    func equalityForPayloadlessCases() {
        #expect(BillingError.productsUnavailable == .productsUnavailable)
        #expect(BillingError.userCancelled == .userCancelled)
    }

    @Test("Distinct cases never collide")
    func distinctCasesAreNotEqual() {
        #expect(BillingError.productsUnavailable != .userCancelled)
        #expect(BillingError.productNotFound("x") != .verificationFailed("x"))
        #expect(BillingError.purchaseFailed("x") != .unknown("x"))
    }
}
