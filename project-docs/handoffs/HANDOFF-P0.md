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

The bug: when StoreKit's system sheet (e.g. Apple Account sign-in) is dismissed in a way
that leaves `Purchases.shared.purchase` suspended rather than returning or throwing, the
awaiting task never resumes. Neither `buy()`'s `defer { buying = nil }` nor
StoreController's `defer { isPurchasing = false }` ever runs, so the pack row's spinner
sticks forever.

The first attempt (commit 69b836e) was wrong and has been replaced. It cleared `buying`
on return to `.active` only when `!store.isPurchasing`. But `isPurchasing` is set and
cleared by a set-then-defer pair wrapped around that same suspended await, so in the
stuck case it is pinned true and the guard never fires. In every non-stuck case the
view's own defer had already cleared `buying` anyway. The condition was unsatisfiable
exactly when it was needed.

The corrected approach (this commit):

- The buy operation is held in cancellable view state: `@State private var buyTask:
  Task<Void, Never>?`, assigned when a pack row is tapped.
- On return to `.active` with `buying != nil`, a `staleCheck` task waits a 2.5s grace
  period (`try? await Task.sleep`). A purchase that is legitimately completing clears
  `buying` via its own defer inside that window, so it is never killed. If the scene
  phase leaves `.active` again (user went back into the StoreKit sheet), `onChange`
  cancels the staleCheck and no cleanup happens.
- If `buying` is still non-nil after the grace period, the purchase is declared stale:
  cancel `buyTask` (so the suspended await unwinds if the SDK honors cancellation and
  both defers run), then clear `buying` and set `store.isPurchasing = false` explicitly,
  since the SDK's continuation may never resume even on cancel. Recovery therefore does
  not depend on `isPurchasing` being false. Sets
  `store.lastError = "Purchase didn't complete. You weren't charged."`.
- False-positive safety net: a purchase we wrongly cancel that actually settled is healed
  by the server-side grant. `shop.reconcilePurchases()` was only called at launch and on
  sign-in (DreamCartApp.swift, RootView.swift), not on foreground, so the stale-cleanup
  path calls it directly. If it credits coins, the error banner is cleared and the normal
  reward overlay is shown instead.
- The `store.lastError` banner above the pack list from the previous commit is kept, and
  `lastError` is still cleared at the start of each `buy()` attempt.

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
