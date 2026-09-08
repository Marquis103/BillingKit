# BillingKit portability — Android (Skip Fuse)

Written for Ayes Android Phase 4, increment W2.7 (`docs/architecture/android-phase4/W2-kits.md`
in the Ayes repo). This file is the authoritative record of what is portable, what is
Darwin-gated, and what each gated surface's Android successor is.

## No manifest gate

Unlike PageKit 2.1.0 / PermissionsKit 1.1.0 there is no `SKIP_ANDROID` bimodal manifest:
this kit has zero package dependencies, no skip imports, no skipstone plugin, no `skip.yml`.
The module is plain Swift on the Android triple; `Package.swift` is identical in every mode
(and unchanged by W2.7 — the macOS `.v14` floor it already declares satisfies resolution).

## What is portable

The entire seam. All of it is Foundation-only and compiles on the Android triple:

- **`BillingServicing`** — all 7 members. The W2.7 audit walked every signature: no
  StoreKit type appears in any of them (`fetchProducts()`, `purchase(_:)`,
  `restorePurchases()`, `currentEntitlements()`, `transactionStream`,
  `startObservingTransactionUpdates()`, `stopObservingTransactionUpdates()`).
- **`ReceiptVerifier`** — the JWS crosses as a plain `String`; `VerificationGate`
  (internal) is Foundation-only and stays ungated.
- **`BillingProduct`** — flat public fields plus a **portable public initializer**
  (new in W2.7). The StoreKit hold (`StoreKitProductBox`) is a Darwin-only optional
  internal detail.
- **`BillingTransaction`** — flat fields + public memberwise initializer.
- **`BillingPurchaseResult`**, **`BillingError`**, **`SubscriptionGroup`**,
  **`VerifiedReceipt`** — pure value types.

## What is gated, and the successor

| Surface | Framework | Android status |
|---|---|---|
| `Core/BillingService.swift` (whole file) | StoreKit 2 (`Product.products`, `.purchase()`, `Transaction.updates`, `AppStore.sync()`, `VerificationResult`) | **Successor: skip-marketplace Play Billing adapter (`SkipMarketplaceBillingAdapter`), W5.4b** — conforms to `BillingServicing`, registered only in the Android composition root. W5.4a gates on reproducing skip-marketplace issue #13 first |
| `BillingProduct`'s `storeKitProduct` box + StoreKit initializers | StoreKit | Darwin-only; the adapter constructs products via the portable public init and re-resolves by `id` at purchase time |
| `BillingTransaction.init(transaction:)` | StoreKit | Darwin-only; the adapter maps Play purchases through the public memberwise init |

## Behavioral notes for the W5.4b adapter (and every consumer)

- **`purchase(_:)` on a hand-constructed product** (portable public init, Darwin) returns
  `.failed(.purchaseFailed("… no StoreKit backing …"))`. Kit-fetched products always carry
  their backing, so nothing reachable through `fetchProducts()` changes behavior.
- **Never add a `BillingError` case.** Ayes' `PaywallError.from(_:)` switches the enum
  exhaustively with no `default`; a new case is a source break for the flagship consumer.
  Map adapter-side failures into the existing cases (`purchaseFailed`, `unknown`, …).
- `.failed(.verificationFailed)` / the `.unverified` JWS path is StoreKit-shaped and never
  produced on Android (the Play adapter's server truth is `validate-play-receipt`).
- `transactionStream` is single-continuation, created once in `init` — one consumer
  (Ayes: `BillingObserverService`). Mirror that contract in the adapter.

## Verification performed (W2.7)

- `swift test`: 23 tests / 6 suites passed — 14 executed + 9 skipped by design (the two
  `SKTestSession` suites are `.disabled` for CLI runs, documented in-suite). Baseline
  before W2.7: 20 / 5 (11 executed + the same 9 skipped). The 3 new tests include the
  first enabled `BillingService` path test (the unbacked-product guard).
- Grep proof: the only `import StoreKit` statements in `Sources/` sit inside
  `#if !os(Android)`; both protocol files import Foundation only.
- Android compile: the kit builds for the Android triple inside the Ayes `AyesApp/` Skip
  Fuse graph via an uncommitted path override (`gradle assembleDebug`, W2.7 PR evidence).
- Darwin surface: additive-only (the public init); every existing declaration is
  byte-identical outside `#if !os(Android)` regions.
