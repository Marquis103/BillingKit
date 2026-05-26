//
//  VerificationGate.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation

/// The receipt-verification chokepoint factored out of
/// `BillingService` so it can be unit-tested without `SKTestSession`.
///
/// Background: the kit's most important invariant is "no transaction
/// is finished until the host's `ReceiptVerifier` has approved it"
/// (PE-272). The actual `transaction.finish()` call lives inside
/// `BillingService.verifyAndFinish(_:)`, but the *decision* — should
/// this transaction be finished, based on what the verifier says? —
/// is what's at risk if someone refactors the call site. By isolating
/// the decision in this type, we can:
///
///   * Unit-test the "verifier throws → gate throws
///     `.verificationFailed`" path against any `ReceiptVerifier`,
///     without StoreKit in the loop.
///   * Keep the call sites in `BillingService` thin enough that a
///     code reviewer can confirm "every `transaction.finish()` is
///     preceded by `gate.verify(...)`" by reading one method.
///
/// `internal` rather than `public`: the host never touches a gate
/// directly. They inject a `ReceiptVerifier`; `BillingService` builds
/// the gate around it.
struct VerificationGate: Sendable {

    // MARK: - Properties

    let verifier: ReceiptVerifier

    // MARK: - Lifecycle

    init(verifier: ReceiptVerifier) {
        self.verifier = verifier
    }

    // MARK: - Internal

    /// Run the host's verifier against `jws`. Returns silently if the
    /// verifier accepts the receipt — call sites can then proceed to
    /// `transaction.finish()`. Throws
    /// `BillingError.verificationFailed` (carrying the verifier's
    /// error description) if the verifier rejects or fails, in which
    /// case the caller MUST NOT finish the transaction.
    func verify(jws: String) async throws {
        do {
            _ = try await verifier.verify(jws)
        } catch {
            throw BillingError.verificationFailed(String(describing: error))
        }
    }
}
