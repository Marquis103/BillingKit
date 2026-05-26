//
//  ReceiptVerifier.swift
//
//  Copyright © 2026 BillingKit. All rights reserved.
//

import Foundation

/// Server-side receipt verification contract. The host app provides
/// the implementation — `BillingKit` deliberately ships no concrete
/// verifier, because shipping a "local-only" verifier would make it
/// trivially easy for a consumer to ship unverified Pro state to
/// production.
///
/// The verifier sits on the hot path for every transaction. Every
/// purchase, restore, and `Transaction.updates` event is funneled
/// through `verify(_:)` before `BillingService` calls
/// `transaction.finish()`. If the verifier throws, the transaction
/// is left unfinished — StoreKit will re-deliver it on the next
/// app launch, which is the desired retry semantics for transient
/// network failures.
///
/// Implementation contract:
///
///   * Input is the JWS string from `Transaction.jwsRepresentation`
///     (StoreKit 2). Forward it as-is to the verification server; the
///     server is responsible for parsing the JWS and validating
///     against the App Store Server API.
///   * Output is a `VerifiedReceipt` carrying the canonical post-
///     verification facts (product ID, original transaction ID,
///     purchase / expires / revocation dates).
///   * Throw on ANY ambiguity: network failure, server returns
///     non-2xx, server says "this receipt is fraudulent", JSON
///     decoding failure. The caller treats any thrown error as
///     "do not grant entitlement, do not finish transaction".
public protocol ReceiptVerifier: Sendable {

    /// Verify a signed StoreKit transaction.
    ///
    /// - Parameter signedTransaction: The JWS representation from
    ///   `Transaction.jwsRepresentation`. Opaque to `BillingKit`;
    ///   parsed and validated by the verifier's server-side
    ///   counterpart.
    /// - Returns: A `VerifiedReceipt` derived from the server's
    ///   response. Must reflect the SERVER's view of the transaction,
    ///   not a local re-decode of the JWS.
    /// - Throws: Any error if verification fails. `BillingKit`
    ///   surfaces these as `BillingError.verificationFailed` to the
    ///   host, with the error's `String(describing:)` representation
    ///   as the associated message.
    func verify(_ signedTransaction: String) async throws -> VerifiedReceipt
}
