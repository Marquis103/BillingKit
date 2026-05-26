//
//  SubscriptionGroupTests.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Testing
@testable import BillingKit

@Suite("SubscriptionGroup")
struct SubscriptionGroupTests {

    @Test("Carries every constructor field through to the value")
    func storesAllFields() {
        let group = SubscriptionGroup(
            groupID: "21500000",
            displayName: "Pro",
            isEligibleForIntroOffer: true,
            isFamilyShareable: false
        )
        #expect(group.groupID == "21500000")
        #expect(group.displayName == "Pro")
        #expect(group.isEligibleForIntroOffer == true)
        #expect(group.isFamilyShareable == false)
    }

    @Test("Equality treats different intro-offer eligibility as distinct")
    func eligibilityChangesEquality() {
        let a = SubscriptionGroup(
            groupID: "21500000",
            displayName: "Pro",
            isEligibleForIntroOffer: true,
            isFamilyShareable: false
        )
        let b = SubscriptionGroup(
            groupID: "21500000",
            displayName: "Pro",
            isEligibleForIntroOffer: false,
            isFamilyShareable: false
        )
        #expect(a != b)
    }

    @Test("Family-shareable flag differentiates otherwise-identical groups")
    func familyShareableChangesEquality() {
        let a = SubscriptionGroup(
            groupID: "21500000",
            displayName: "Pro",
            isEligibleForIntroOffer: true,
            isFamilyShareable: true
        )
        let b = SubscriptionGroup(
            groupID: "21500000",
            displayName: "Pro",
            isEligibleForIntroOffer: true,
            isFamilyShareable: false
        )
        #expect(a != b)
    }
}
