//
//  BillingTransactionTests.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation
import Testing
@testable import BillingKit

@Suite("BillingTransaction (portable value)")
struct BillingTransactionTests {

    private let purchaseDate = Date(timeIntervalSince1970: 1_700_000_000)

    @Test("The public initializer leaves appAccountToken nil when no token is given")
    func appAccountTokenDefaultsToNil() {
        let transaction = BillingTransaction(
            transactionID: "t1",
            originalTransactionID: "o1",
            productID: "com.thatSwiftGuy.ayes.pro.monthly",
            purchaseDate: purchaseDate
        )
        #expect(transaction.appAccountToken == nil)
    }

    @Test("The public initializer carries the account token through to the value")
    func appAccountTokenIsExposed() throws {
        let token = try #require(UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF"))
        let transaction = BillingTransaction(
            transactionID: "t1",
            originalTransactionID: "o1",
            productID: "com.thatSwiftGuy.ayes.pro.monthly",
            purchaseDate: purchaseDate,
            appAccountToken: token
        )
        #expect(transaction.appAccountToken == token)
        #expect(transaction.isUpgraded == false)
    }

    @Test("Transactions that differ only by account token are not equal")
    func equalityIncludesAppAccountToken() {
        let a = BillingTransaction(
            transactionID: "t1", originalTransactionID: "o1",
            productID: "p", purchaseDate: purchaseDate, appAccountToken: UUID()
        )
        let b = BillingTransaction(
            transactionID: "t1", originalTransactionID: "o1",
            productID: "p", purchaseDate: purchaseDate, appAccountToken: UUID()
        )
        let unbound = BillingTransaction(
            transactionID: "t1", originalTransactionID: "o1",
            productID: "p", purchaseDate: purchaseDate
        )
        #expect(a != b)
        #expect(a != unbound)
        #expect(a == a)
    }
}
