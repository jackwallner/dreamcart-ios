# P0 Ship Blockers - Handoff

Simulator audit found 3 P0 items. All 3 are fixed, build succeeds, and DreamCartTests
passes (6/6).

## Checklist

1. [x] Add to cart opens wrong sheet (ProductDetailView.swift, CartView instead of CheckoutView)
2. [x] Checkout failures are silent (CheckoutView.swift, no .alert on failure)
3. [x] Interrupted IAP leaves stuck spinner (CoinShopView.swift, buying state not cleared on cancel)

## Item 1 - wrong checkout sheet

File: DreamCart/Views/ProductDetailView.swift

The buy bar's "Add to cart" / "Check out" button added the item to cart then presented
CartView() as a sheet instead of CheckoutView. Fixed by mirroring CartView's pattern:
present CheckoutView with an onPlaced closure, then run the same UnboxingView overlay
on success. Added `@State private var unboxing: [Product]?` to hold the post-purchase
celebration state. UnboxingView is defined in CartView.swift but is accessible from
ProductDetailView since both are in the DreamCart target.

## Item 2 - silent checkout failures

File: DreamCart/Views/CheckoutView.swift

`place()` only played a warning haptic on failure with no visible feedback. Added
`@State private var errorMessage: String?` and an `.alert` bound to it. Two failure
paths are handled: `shop.checkout()` returning nil (thrown/network - generic fallback
message) and returning a PurchaseResult with `ok == false` (reason-specific message via
a small `failureMessage(for:)` mapper). Checked the purchase_cart RPC
(supabase/migrations/20260706000100_economy_rpcs.sql) for the actual reason strings it
can return for this call: `insufficient_coins` and `nothing_to_buy`. Mapped both to
playful, short copy; anything else falls back to a generic message.

## Item 3 - stuck IAP spinner

File: DreamCart/Views/CoinShopView.swift

`buy()` already had `defer { buying = nil }` covering the whole async function, so on
paper it looked correct. The actual gap: when StoreKit's system sheet (e.g. Apple
Account sign-in) is dismissed in a way that leaves the underlying `Purchases.shared.purchase`
call suspended rather than throwing/cancelling, the awaiting Task itself never resumes,
so the defer never runs since the function never returns control. Added a scene-phase
guard: `@Environment(\.scenePhase)` + `.onChange(of: scenePhase)` that clears `buying`
whenever the app returns to `.active` and `store.isPurchasing` (StoreController's own
in-flight flag) is false. Also surfaced `store.lastError` as a small text banner above
the pack list (P1 item from the audit, was a one-liner) and clear it at the start of
each `buy()` attempt so stale errors don't linger.

## Verification

- `xcodebuild build -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"` - BUILD SUCCEEDED
- `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"` - TEST SUCCEEDED, 6/6 passed (testCartMathAndAffordability, testCartToggleAndSearch, testCoinFormatting, testCoinPackCatalogIntegrity, testHexColorParsingDoesNotCrash, testRarityMapping)
- Did not rerun `xcodegen generate` - no .swift files added/removed, project.yml untouched.
- simulator used: iPhone 17 Pro, UDID FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8 (was Shutdown, xcodebuild booted it for the test run; no Simulator.app opened).

## Notes for next phase (typography pass)

While reading through these three views I noticed font usage is consistent
(dcTitle/dcBody/dcSub/dcLabel/dcCaption etc. from a shared Theme/Font extension) but I
did not audit weights/sizes closely since it was out of scope here. Nothing else
jumped out as broken. CheckoutView's receipt card and CartView's checkout bar both
duplicate the "You need N more coins" copy/logic - not a bug, just a possible dedup
target if a typography/cleanup pass touches those files.

## Summary

All 3 P0 items fixed, verified building and passing tests on simulator. Changes:
- DreamCart/Views/ProductDetailView.swift
- DreamCart/Views/CheckoutView.swift
- DreamCart/Views/CoinShopView.swift

Committed as three separate conventional commits, then pushed.
