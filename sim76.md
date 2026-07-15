# sim76 — DreamCart Simulator Audit

**Date:** 2026-07-06  
**Build:** Debug `DreamCart` on iOS Simulator (Xcode, `DreamCart.storekit` attached)  
**Tester account:** `tester@dreamcart.dev` (DEBUG “Continue as tester”)  
**Screenshots:** `sim76/screenshots/` (103 captures on iPhone 17 Pro; additional passes on iPhone 17 Pro Max and iPhone 16e)

> **Historical status (2026-07-14):** This report captures the 2026-07-06 build and is not a current defect list. The product-detail checkout destination, checkout/catalog error presentation, empty-cart CTA, display-name fallback, title truncation, category icons, delisted closet navigation, reset-time copy, and several accessibility labels were fixed after this audit. The generated screenshots and AX logs are intentionally excluded from git; rerun `sim76/run-audit.sh` to regenerate evidence.

---

## Executive summary

DreamCart’s core fantasy loop works end-to-end in the simulator: daily coins, spin wheel, browse → cart → checkout, closet ownership, outfit builder, and the RevenueCat coin shop all load and respond. The visual language is strong — candy gradients, serif headlines, rarity badges — and the “fake checkout with real coin cost” concept lands.

However, several issues undermine trust and polish:

1. **A definite navigation bug:** tapping **Add to cart** on product detail opens the **Cart tab UI as a sheet**, not checkout (`ProductDetailView` wires `showCheckout` to `CartView()`).
2. **Silent failures everywhere:** checkout errors, catalog load errors, and IAP errors are computed but rarely shown.
3. **Onboarding/account gaps:** profile still reads “Shopper”; sign-out is buried; ledger is easy to miss.
4. **Image pipeline fragility:** product grids spend noticeable time in shimmer/retry states; uncached shots 429 under burst load.
5. **IAP friction in sim:** StoreKit purchase triggers a system **Sign in to Apple Account** sheet; interrupted purchases can leave a spinner on a pack row.

None of these are cosmetic-only. The product-detail → cart sheet bug alone breaks the intended “add and drop straight into checkout” flow described in code comments.

---

## Test methodology

| Area | What we did |
|------|-------------|
| **Devices** | iPhone 17 Pro (primary, 402×874), iPhone 17 Pro Max, iPhone 16e |
| **Modes** | Signed-in tester; attempted signed-out onboarding; in-app Light appearance; system Dark via `simctl ui appearance dark` |
| **Paid** | Coin shop sheet, Pocket pack purchase attempt (StoreKit + RevenueCat), Restore Purchases link |
| **Unpaid** | Daily claim, spin wheel, browse/search/filter, cart, checkout (when cart populated), closet, outfit builder, profile/ledger |
| **Automation** | Headless sim (`agent-sim boot shop`), `axe` tap/screenshot, accessibility trees dumped to `sim76/logs/` |

**Caveat:** Automated taps frequently missed tab-bar targets when the app backgrounded (often after StoreKit system sheets). Manual label-based navigation (`axe tap --label "Closet"`) was more reliable. Findings below combine screenshot review, AX trees, and source inspection.

---

## Screenshot index (representative)

| File | Screen |
|------|--------|
| `iphone17pro/A-today-home.png` | Today tab — daily drop, spin card, new drops shelf |
| `iphone17pro/A-daily-claimed.png` | Daily reward overlay (+125, streak 2) |
| `iphone17pro/M-spin.png` | Spin wheel sheet |
| `iphone17pro/M-spin-won.png` | Spin reward overlay (+100) |
| `iphone17pro/C-shop-home.png` / `M-shop-dark.png` | Shop grid (categories, rarity badges) |
| `iphone17pro/D-product-detail.png` | Product detail — Ironwood jeans, Add to cart bar |
| `iphone17pro/D-checkout-sheet.png` | **Bug capture:** sheet shows Cart, not Checkout |
| `iphone17pro/E-cart-with-items.png` | Cart with 1 item, checkout CTA |
| `iphone17pro/M-checkout.png` | Empty cart state |
| `iphone17pro/K-coin-shop.png` | Get Coins — 5 packs, balance header |
| `iphone17pro/K-ledger.png` | Coin history (partially obscured by Apple ID sheet during IAP) |
| `iphone17pro/L-closet.png` | Closet — stats, avatar CTA, owned grid |
| `iphone17pro/L-outfit-builder.png` | Dressing room — look picker, slot list |
| `iphone17pro/M-profile.png` | Profile — stats, appearance, actions |
| `iphone17pro/iphone17promax/today.png` | Welcome onboarding on Max width |
| `iphone17pro/iphone16e/today.png` | Welcome on smaller phone (system notification visible) |

Full set: `sim76/screenshots/iphone17pro/` (103 PNGs).

---

## Flow-by-flow findings

### 1. Splash & auth

| Observation | Severity | Notes |
|-------------|----------|-------|
| Splash (`Theme.candy` + pulsing bag) is on-brand, brief | OK | `RootView` → `SplashView` while `auth.state == .unknown` |
| Welcome 3-slide pager reads well | OK | Value props: guilt-free shop, daily coins, closet |
| **Sign in with Apple** untested in sim | — | Requires real Apple ID flow |
| **Continue as tester** (DEBUG only) works | OK | Hidden in Release — correct |
| Onboarding dots don’t indicate swipe affordance beyond dots | Low | No “Swipe to learn more” copy |
| iPhone 16e showed **Apple Intelligence** banner over welcome | Low | OS notification, not app bug — but reduces first-run polish on SE-class devices |

**Improvements**
- Add subtle swipe hint on slide 1.
- Consider persisting “has seen onboarding” so returning sign-outs skip slides.

---

### 2. Today tab (home)

| Observation | Severity | Notes |
|-------------|----------|-------|
| Time-aware greeting (“Late-night haul”) | Nice | `TodayView.greeting` |
| Wallet pill (+ coin balance) consistent across tabs | OK | `WalletToolbar` |
| Daily Drop card dominates viewport | Medium | Pushes “Just dropped” below fold on all tested phones |
| Daily claim → `RewardOverlay` with streak copy | OK | Tested: +125, “Streak 2 days” |
| Post-claim card correctly shows “Claimed” / disabled | OK | |
| Spin card opens full-screen `SpinView` sheet | OK | |
| Horizontal new-drops shelf navigates to detail | OK | |
| Only **4 brand shelves** on Today (`brands.prefix(4)`) | Low | Rest invisible until Shop |
| Product names **truncated** in 150pt cards (“Verona Ochre Ba…”) | Medium | Hurts browse confidence |
| Some shelf thumbnails were **flat color placeholders** during load | Medium | `RemoteImage` shimmer/retry — see Performance |
| Pull-to-refresh wired | OK | `refreshable { await shop.refreshAll() }` |
| **`shop.loadError` never displayed** | High | User sees empty/stale data silently |

**Improvements**
- Collapse daily card after claim (or shrink to compact streak chip).
- Two-line `lineLimit(2)` on product titles in cards.
- Banner when `loadError != nil` with retry.

---

### 3. Spin wheel

| Observation | Severity | Notes |
|-------------|----------|-------|
| Wheel renders 8 slices, gold rim, pointer | OK | Matches server `prizes` array |
| Spin animation ~3.2s easeOut | OK | Lands on server `slice` |
| Win overlay: “You won” / “JACKPOT!” at ≥800 | OK | Tested +100 overlay |
| **Bottom-half slice labels upside-down** | Medium | Readable but awkward |
| “Come back tomorrow” when `canSpin == false` | OK | No disabled-state explanation of reset time |
| Close is plain text at bottom | Low | Easy to miss vs swipe-down |

**Improvements**
- Rotate slice text to stay upright.
- Show “Resets at midnight” (or server-provided time).

---

### 4. Shop tab

| Observation | Severity | Notes |
|-------------|----------|-------|
| 2-column grid, category chips, search | OK | 10 categories |
| Category chips **ignore `icon` field** in data | Low | Labels only — missed visual wayfinding |
| Search matches name, color, category, brand, tags | OK | `ShopStore.search` |
| Empty search shows `EmptyState` | OK | |
| Rarity + NEW badges on cards | OK | EPIC / RARE / LEGENDARY read well |
| Brand “See all” → `BrandView` | OK | Large title + tagline color |
| Dark mode (in-app) — shop screenshot still light | Medium | Appearance segmented control on Profile may override system dark during audit |

**Improvements**
- SF Symbol per category chip.
- Respect `@AppStorage("appearance")` *and* system when set to Auto.

---

### 5. Product detail

| Observation | Severity | Notes |
|-------------|----------|-------|
| Large hero image, rarity tag, favorite heart | OK | |
| Brand link → brand page | OK | |
| Style tags as `#chips` | OK | |
| Spec rows: color, category, rarity | OK | |
| Owned state → green “In your closet” | OK | |
| **Add to cart opens `CartView` sheet, not `CheckoutView`** | **Critical** | ```66:66:DreamCart/Views/ProductDetailView.swift``` `.sheet(isPresented: $showCheckout) { CartView() }` — comment says “drops you straight into checkout” |
| Tab bar still highlights **Today** when opened from Today shelf | Medium | User may think they left the tab |
| Favorite toggle has no toast/undo | Low | |
| No “similar items” or share | Low | |

**Improvements**
- Replace sheet content with `CheckoutView(onPlaced:)` or navigate to Cart with checkout auto-presented.
- When pushing detail from a tab, consider switching `tab` selection or hiding tab bar on detail.

---

### 6. Cart & checkout

| Observation | Severity | Notes |
|-------------|----------|-------|
| Empty state copy is clear | OK | “Checkout is free with coins” |
| **No CTA to Shop** on empty cart | Medium | Dead end |
| Cart row: image, name, price, remove | OK | |
| Badge count on tab | OK | |
| Checkout bar: total, afford check | OK | |
| “Get more coins” when underfunded | OK | Opens coin shop |
| Checkout sheet: address, shipping method, faux receipt | OK | Immersive fantasy |
| Address fields **persist in `@AppStorage`** | OK | Convenient for repeat play |
| **State field optional for `addressComplete`** | Low | Only name/street/city/zip required — fine for fantasy |
| Virtual disclaimer present | OK | |
| **`checkout()` failure → only `Haptics.warning()`** | High | No alert; coins/validation reasons invisible |
| Unboxing `UnboxingView` not captured cleanly in audit | — | Code path exists after successful `onPlaced` |
| Duplicate **“Check out”** accessibility labels (cart bar + detail) | Medium | AXe warned “Multiple matched” |

**Improvements**
- Empty cart: primary “Browse shop” button.
- Surface `PurchaseResult.reason` in an alert.
- Add accessibility identifiers: `cartCheckoutButton`, `detailCheckoutButton`.

---

### 7. Closet & outfit builder

| Observation | Severity | Notes |
|-------------|----------|-------|
| Stats card: owned, spent, best streak | OK | |
| “Dress up your avatar” → `OutfitBuilderView` | OK | |
| Owned grid with category filters | OK | Filters use raw category strings (“Hat”, “Jewelry”) |
| **Item names truncated** in closet tiles | Medium | `lineLimit(1)` |
| Outfit builder: 6 looks (Aria–Rio) | OK | |
| Empty avatar preview until picks | OK | Clear placeholder copy |
| Slot list with “None owned” disabled rows | OK | |
| Slot picker sheet grid | OK | |
| **Composite avatar uses Vision cutouts** — placeholder rects while processing | Medium | Purple boxes during segmentation |
| Save outfit clears picks after success | OK | No confirmation beyond “Saved!” flash |
| Saved looks: Try on / Delete | OK | |
| Navigate to detail from closet **only if product still in catalog** | Medium | `if let full = shop.products.first…` — stale items unreachable |

**Improvements**
- Human-readable filter labels (map `headwear` → “Hats”).
- Show loading spinner on avatar composite, not empty purple rects.
- Keep minimal `Product` in closet for detail even if delisted.

---

### 8. Profile & account

| Observation | Severity | Notes |
|-------------|----------|-------|
| Avatar initial + **“Shopper”** display name | Medium | Tester account should show real `displayName` from `me` |
| Coin balance shown **twice** (wallet + stat tile) | Low | Redundant on this screen |
| 2-day streak under name | OK | |
| Appearance: Light / Dark / Auto segmented | OK | |
| Get more coins, Coin history, Sign out | OK | |
| **Sign out** requires scroll on smaller phones | Medium | Near delete account |
| Delete account + confirmation dialog | OK | Destructive pattern correct |
| Virtual-game disclaimer footer | OK | App Review friendly |
| Coin history (`LedgerView`) — list with reason labels | OK | Couldn’t capture clean shot during IAP dialog |
| **`auth.errorMessage` only on Welcome** | Medium | Profile actions fail silently |

**Improvements**
- Bind `shop.me?.displayName` — fallback “Shopper” only when nil.
- Move sign out higher or into settings section with more spacing from delete.
- Show `StoreController.lastError` on coin shop after failed purchase.

---

### 9. Coin shop (paid / IAP)

| Observation | Severity | Notes |
|-------------|----------|-------|
| Balance header on candy gradient | OK | |
| 5 packs: Pocket $1.99 → Vault $49.99 | OK | Matches `DreamCart.storekit` |
| POPULAR (Bag), BEST VALUE (Spree) badges | OK | |
| Localized prices from RevenueCat | OK | Fallback hardcoded prices if offline |
| Purchase → `store.purchase` → `shop.reconcilePurchases()` | OK | |
| Reward overlay on success | OK | |
| Restore Purchases link | OK | Consumables — mostly noop; still required |
| **Simulator prompts Apple Account sign-in** | Expected | Blocks unattended IAP testing |
| **Interrupted purchase left `ProgressView` on pack row** | High | `buying` state stuck after system dialog |
| No loading state on Restore | Low | |
| Footer disclaimer | OK | |

**Improvements**
- `defer { buying = nil }` already exists — ensure cancellation of system sheet clears state (may need `PurchasesDelegate`/scene phase).
- Present sandbox setup instructions in DEBUG when `lastError` mentions account.
- Consider highlighting coins-per-dollar on each row.

---

## Unpaid vs paid economy balance

| Source | Tested | Notes |
|--------|--------|-------|
| Welcome bonus | Not isolated | Ledger label exists |
| Daily drop | Yes | +125, streak tracking |
| Spin | Yes | +100 in test |
| Checkout (spend) | Partially | Cart flow OK; checkout completion not screenshot-verified |
| IAP packs | Attempted | System login blocked full verification |

**Observation:** Starting tester had **4,520** coins; after daily (+125), spin (+100), and possible IAP, balance reached **4,745**. Economy feels generous for browsing; epic/legendary pieces (760–840+) still require saving or paid packs — appropriate.

**Risk:** Without visible earn/spend history in main UI, users may not understand why balance changed (ledger is buried).

---

## Device matrix

| Device | Resolution (approx) | Findings |
|--------|---------------------|----------|
| **iPhone 17 Pro** | 402×874 | Primary audit device; tab bar tap Y≈840 |
| **iPhone 17 Pro Max** | Wider | Welcome layout scales; more horizontal breathing room on onboarding |
| **iPhone 16e** | Narrower, no Dynamic Island | Welcome fits; **system notification** ate top margin; tab targets need recalibration for automation |

**Layout wins**
- Serif large titles scale well.
- Bottom checkout bars use `safeAreaInset` — shouldn’t overlap home indicator.
- Coin shop list scrolls on all sizes.

**Layout risks**
- Today daily card + spin + shelf = **long scroll** on 16e.
- Product detail buy bar + tab bar = crowded; consider hiding tab bar on detail.
- Wheel at 300pt may feel small on Max (unused vertical space in spin sheet).

---

## Performance & networking

| Issue | Evidence | Code |
|-------|----------|------|
| Image shimmer on first paint | Today shelf placeholders in early screenshots | `RemoteImage` + `ImageFetchGate` (limit 3) |
| 429 / 5xx retries | Comment in `ProductCard.swift` | Up to 5 retries, backoff |
| Aggressive URL cache at app launch | 64MB mem / 512MB disk | `DreamCartApp.init` |
| Catalog fetch 1000 products at once | Possible slow first `refreshAll` | `ShopStore.refreshAll` |
| No skeleton for brand shelves | Empty gap then pop-in | |

**Improvements**
- Prefetch above-the-fold images after `refreshAll`.
- Show stale-while-revalidate (cached thumb + refresh).
- Paginate or lazy-load catalog beyond first screen.

---

## Accessibility audit

| Issue | Detail |
|-------|--------|
| Duplicate labels | “Check out” on cart + detail |
| Coin button labeled “$, 4,520” | Screen reader awkward |
| Many AX nodes `AXLabel: null` in trees | Decorative images lack labels |
| Spin slice values | Not individually accessible |
| Reward overlays | Dismiss via “Nice” — background tap also works (good) |
| Dynamic Type | Not verified; serif hero may clip at XXXL |
| Contrast | `Theme.subtle` on cream bg — verify WCAG for captions |

**Improvements**
- `accessibilityLabel` on `ProductCard`: “{brand}, {name}, {price} coins, {rarity}”.
- `accessibilityIdentifier` on all primary CTAs for UI tests.
- VoiceOver hint on daily/spin when disabled.

---

## Security & trust

| OK | Gap |
|----|-----|
| Sign in with Apple + Supabase | No visible privacy policy link on Welcome |
| Keychain session restore | Delete account is one tap + confirm — good |
| Coins “no cash value” disclaimers | Shipping address form may confuse users about real data collection |

**Improvements**
- Link to privacy policy near Sign in with Apple.
- Clarify address is fictional (checkbox “Save fake address for next time”).

---

## Prioritized improvement backlog

### P0 — Ship blockers
1. **Fix product detail sheet** — present `CheckoutView`, not `CartView`.
2. **Surface checkout errors** — show `PurchaseResult.reason` / insufficient coins.
3. **Clear IAP `buying` spinner** when StoreKit sheet dismisses without purchase.

### P1 — High impact UX
4. Empty cart → “Browse shop” CTA.
5. Banner for `shop.loadError` with retry on Today/Shop.
6. Show `StoreController.lastError` in coin shop.
7. Fix profile display name (use `me.displayName`).
8. Reduce daily card height after claim.

### P2 — Polish
9. Product/card title `lineLimit(2)`.
10. Category chip icons.
11. Spin wheel label orientation + reset time.
12. Outfit builder loading state for cutouts.
13. Closet detail for delisted products.
14. Hide tab bar on product detail or sync selected tab.

### P3 — Nice to have
15. Favorites collection view.
16. Similar items on detail.
17. Share outfit / product.
18. Haptics already good — add sound toggle.

---

## Code references (bugs cited)

**Product detail opens wrong sheet:**
```104:67:DreamCart/Views/ProductDetailView.swift
    .safeAreaInset(edge: .bottom) { buyBar }
    .sheet(isPresented: $showCoinShop) { CoinShopView() }
    .sheet(isPresented: $showCheckout) { CartView() }  // ← should be CheckoutView
```

**Checkout failure silent:**
```211:221:DreamCart/Views/CheckoutView.swift
    if let r = await shop.checkout(), r.ok {
        Haptics.celebrate()
        onPlaced(bought)
    } else {
        Haptics.warning()  // ← no user-visible error
    }
```

**Load errors stored but not shown:**
```31:47:Shared/Services/ShopStore.swift
    func refreshAll() async {
        ...
        } catch {
            loadError = (error as? SBError)?.errorDescription ?? error.localizedDescription
        }
    }
```
(No view binds `shop.loadError`.)

---

## What’s working well (keep)

- **Visual identity** — candy gradient, gold coins, serif titles: distinctive and cohesive.
- **Reward moments** — `RewardOverlay`, confetti, unboxing sequence: strong dopamine design.
- **Checkout fantasy** — faux tax/shipping with “FREE” shipping: sells the bit without real charges.
- **Economy integrity** — server RPCs for coins; client doesn’t mutate balance locally.
- **Image resilience** — `RemoteImage` retry/backoff is thoughtful for pollinations rate limits.
- **DEBUG tester login** — makes QA possible without Apple ID.
- **StoreKit config** — local `DreamCart.storekit` enables IAP UI work offline.

---

## Recommended next QA pass

1. Fix P0 items, then re-run `sim76/run-audit.sh` (update swipe commands — already patched).
2. Sign in to **StoreKit sandbox** in Simulator Settings → App Store to complete IAP screenshots.
3. Add one UI test: add → checkout → unboxing path.
4. Test **Release** build (no tester button) for onboarding-only path.
5. VoiceOver walkthrough on Today → Shop → Cart.

---

*Generated from simulator session 76. No app code was modified during this audit.*
