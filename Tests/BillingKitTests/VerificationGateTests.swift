//
//  VerificationGateTests.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Testing
@testable import BillingKit

@Suite("VerificationGate")
struct VerificationGateTests {

    @Test("Returns silently when the verifier accepts the receipt")
    func returnsSilentlyOnSuccess() async throws {
        let verifier = MockReceiptVerifier(mode: .succeed)
        let gate = VerificationGate(verifier: verifier)

        try await gate.verify(jws: "any-jws")

        #expect(verifier.callCount == 1)
    }

    @Test("Throws .verificationFailed when the verifier rejects")
    func throwsOnVerifierRejection() async {
        let verifier = MockReceiptVerifier(
            mode: .fail(MockReceiptVerifier.Failure.rejected)
        )
        let gate = VerificationGate(verifier: verifier)

        do {
            try await gate.verify(jws: "any-jws")
            Issue.record("Expected gate.verify to throw, but it returned")
        } catch let error as BillingError {
            guard case .verificationFailed = error else {
                Issue.record("Expected .verificationFailed, got \(error)")
                return
            }
        } catch {
            Issue.record("Expected BillingError.verificationFailed, got \(error)")
        }
    }

    @Test("Wraps any verifier error type into .verificationFailed")
    func wrapsArbitraryErrorIntoVerificationFailed() async {
        struct WeirdError: Error {}
        let verifier = MockReceiptVerifier(mode: .fail(WeirdError()))
        let gate = VerificationGate(verifier: verifier)

        do {
            try await gate.verify(jws: "any-jws")
            Issue.record("Expected gate.verify to throw")
        } catch let billing as BillingError {
            guard case .verificationFailed = billing else {
                Issue.record("Expected .verificationFailed, got \(billing)")
                return
            }
        } catch {
            Issue.record("Expected BillingError, got \(error)")
        }
    }

    @Test("Forwards the JWS payload to the verifier verbatim")
    func forwardsJWSVerbatim() async throws {
        let verifier = MockReceiptVerifier()
        let gate = VerificationGate(verifier: verifier)

        try await gate.verify(jws: "header.payload.signature")

        #expect(verifier.receivedTransactions == ["header.payload.signature"])
    }

    @Test("Each call invokes the verifier once — no caching across calls")
    func doesNotCacheAcrossCalls() async throws {
        let verifier = MockReceiptVerifier()
        let gate = VerificationGate(verifier: verifier)

        try await gate.verify(jws: "a")
        try await gate.verify(jws: "b")
        try await gate.verify(jws: "c")

        #expect(verifier.callCount == 3)
        #expect(verifier.receivedTransactions == ["a", "b", "c"])
    }
}
