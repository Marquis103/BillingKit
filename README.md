# BillingKit

StoreKit 2 wrapper for the portfolio iOS apps. Fetches products, runs purchases through a host-provided server-side receipt verifier, observes out-of-band transaction updates (refunds, renewals, family-sharing revocations), and surfaces a flat `Sendable` API to consumers so view models don't have to import `StoreKit` directly.

The kit ships no concrete `ReceiptVerifier` by design — every host wires its own, so production builds cannot accidentally ship without server-side verification.

## Install

```swift
.package(url: "https://github.com/Marquis103/BillingKit", from: "1.0.0")
```

## Quick start

```swift
import BillingKit

// 1. Implement the verifier — calls your backend, which talks to
//    Apple's App Store Server API.
struct ServerVerifier: ReceiptVerifier {
    let client: APIClient

    func verify(_ signedTransaction: String) async throws -> VerifiedReceipt {
        let request = VerifyReceiptRequest(jws: signedTransaction)
        let response = try await client.execute(request)
        return VerifiedReceipt(
            productID: response.productID,
            originalTransactionID: response.originalTransactionID,
            purchaseDate: response.purchaseDate,
            expiresDate: response.expiresDate,
            revocationDate: response.revocationDate
        )
    }
}

// 2. Stand up the service at app launch.
let billing = BillingService(
    productIDs: ["com.thatSwiftGuy.app.pro.monthly"],
    verifier: ServerVerifier(client: apiClient)
)

// 3. Observe out-of-band transactions (refunds, renewals).
//    The kit does NOT auto-start observation — call once at app
//    launch after wiring your consumer so test code that constructs
//    a service for a fetch-only check doesn't leak a background task.
Task {
    for await transaction in billing.transactionStream {
        await entitlementStore.apply(transaction)
    }
}
await billing.startObservingTransactionUpdates()

// 4. Render a paywall.
let products = try await billing.fetchProducts()
let pro = products.first(where: { $0.id == "com.thatSwiftGuy.app.pro.monthly" })!

// 5. Purchase.
switch try await billing.purchase(pro) {
case .success(let transaction):
    await coordinator.openConfirmation(transaction)
case .pending:
    await coordinator.showAskToBuyPending()
case .cancelled:
    break
case .failed(let error):
    await coordinator.showError(error)
}
```

## ReceiptVerifier contract

The verifier sits on the hot path for every transaction. Every purchase, restore, and `Transaction.updates` event is funneled through it before `BillingService` calls `transaction.finish()`. There is exactly one code path in the kit that finishes transactions — no future change can accidentally bypass verification.

* **Input**: the JWS string from `Transaction.jwsRepresentation` (StoreKit 2). Opaque to `BillingKit` — forward as-is to your server, which parses and validates against Apple's App Store Server API.
* **Output**: a `VerifiedReceipt` reflecting the SERVER's view of the transaction (product ID, original transaction ID, purchase / expires / revocation dates). The kit does not currently consume the fields beyond confirming the call returned, but they're surfaced so hosts can update their entitlement record directly from the result.
* **Errors**: throw on ANY ambiguity — network failure, server returns non-2xx, server rejects the receipt, JSON decoding fails. `BillingKit` surfaces these to the host as `BillingError.verificationFailed`. The transaction is left unfinished, so StoreKit re-delivers on next launch — the intended retry semantics for transient failures.

## Sandbox testing

Two flavors of testing — pick based on what you need:

### `SKTestSession` (unit tests, no Apple account needed)

`BillingKit` ships with `Tests/BillingKitTests/Resources/BillingKitTests.storekit` and a `BillingServiceTests` suite that exercises `BillingService` end-to-end against a local fake App Store. Hosts can take the same approach:

```swift
let url = Bundle.module.url(forResource: "MyConfig", withExtension: "storekit")!
let session = try SKTestSession(contentsOf: url)
session.disableDialogs = true
let service = BillingService(productIDs: ["..."], verifier: MockVerifier())
let products = try await service.fetchProducts()
```

The `BillingServiceTests` and `BillingProductMappingTests` suites are gated with `.disabled(...)` because `SKTestSession` cannot write its scratch state under SwiftPM's CLI helper, and the simulator daemon caches purchase state across `xcodebuild test` invocations causing the suite to hang. **Run them interactively via Xcode (Product → Test on the BillingKit scheme)** before tagging a release — the pure-Swift model tests (`BillingError`, `SubscriptionGroup`) cover the rest and stay green under `swift test` / CI.

### Sandbox accounts (manual QA in TestFlight or Xcode-attached device)

1. Create a Sandbox Tester in App Store Connect → Users and Access → Sandbox.
2. On the device: Settings → Developer → Sandbox Apple Account → sign in with the tester.
3. Run the app from Xcode (or install via TestFlight); purchases route through Apple's sandbox, with no actual charges.
4. Verify your server-side `ReceiptVerifier` validates against Apple's sandbox URL (`sandbox.itunes.apple.com`) — the JWS payload carries an `environment` claim your server can switch on.

## Architecture

```
                ┌───────────────────────────────────────┐
                │              Host app                 │
                │                                       │
                │  ┌──────────────────────────────────┐ │
                │  │       SubscriptionService        │ │
                │  │  (renders paywall, entitlements) │ │
                │  └──────────┬───────────────────────┘ │
                └─────────────┼─────────────────────────┘
                              │
                ┌─────────────▼─────────────┐
                │      BillingService       │  actor
                │  ┌─────────────────────┐  │
                │  │ Product cache (5m)  │  │
                │  └─────────────────────┘  │
                │  ┌─────────────────────┐  │
                │  │ Transaction stream  ├──┼─── StoreKit.Transaction.updates
                │  └──────────┬──────────┘  │
                │             │             │
                │      ┌──────▼──────┐      │
                │      │ verifyAnd-  │      │
                │      │   Finish    │──────┼─── verifier.verify(jws)
                │      │  (chokepoint)      │
                │      └──────┬──────┘      │
                │             │             │
                │  ┌──────────▼──────────┐  │
                │  │ transaction.finish() │  │  (only after verifier approves)
                │  └─────────────────────┘  │
                └───────────────────────────┘
```

## What's NOT here

* **Paywall UI** — that's `PageKitUI` + your design system.
* **Entitlement persistence** — combine `transactionStream` with `PersistenceKit` (or whatever your host uses for local state).
* **Server-side App Store Server API client** — the kit defines the verifier interface; the implementation is your backend's concern.
* **Promo codes / offer codes** — call `Product.PromotionalOffer` or `SKPaymentQueue.presentCodeRedemptionSheet()` directly from the host until a use case justifies a kit-level helper.
* **Refund request sheet** — Apple's `Transaction.beginRefundRequest(in:)` is one line at the call site; not worth wrapping.

---

Copyright © 2026 BillingKit. All rights reserved.
