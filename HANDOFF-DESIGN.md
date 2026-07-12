# DreamCart Design Language Handoff

## Status

- [x] Capture before screenshots in light and dark
- [x] Enforce typography and icon tokens
- [x] Audit editorial and functional voice consistency
- [x] Polish hierarchy, spacing, radii, overlines, truncation, and contrast
- [x] Capture and inspect after screenshots in light and dark
- [x] Run final tests and document remaining exceptions and punts

## Policy decisions

- Editorial serif is reserved for screen heroes, section headers, card headlines, and product names.
- Functional SF is used for buttons, prices, rows, captions, numerals, and micro-labels.
- SF Symbols use five fixed tokens: `dcIconS` at 14 medium, `dcIconM` at 18 semibold, `dcIconL` at 24 bold, `dcIconXL` at 44 medium, and `dcIconHero` at 78 semibold.

## Changes by file

- `Shared/Utilities/Theme.swift`: added the documented SF Symbol scale.
- `DreamCart/Components/Common.swift`: moved empty-state artwork to `dcIconXL`.
- `DreamCart/Components/ProductCard.swift`: moved retry artwork to `dcIconL`.
- `DreamCart/Components/CoinViews.swift`: moved the wallet action to `dcIconM` and documented two parametric font exceptions.
- `DreamCart/Views/ProfileView.swift`: normalized stat, appearance, row, and chevron icons.
- `DreamCart/Views/WelcomeView.swift`: moved onboarding artwork to `dcIconHero`.
- `DreamCart/Views/CheckoutView.swift`: normalized delivery selectors and card-header icons.
- `DreamCart/Views/CartView.swift`: moved the row removal control to `dcIconL`.
- `DreamCart/Views/OutfitBuilderView.swift`: normalized empty, slot, selection, and removal icons.
- `DreamCart/Views/ClosetView.swift`: normalized summary and dress-up icons.
- `DreamCart/Views/TodayView.swift`: moved the daily reward icon to `dcIconL`.
- `DreamCart/Views/ProductDetailView.swift`: moved the favorite control to `dcIconM`.
- `DreamCart/Views/CoinShopView.swift`: normalized coin-pack feature icons.
- `DreamCart/RootView.swift`: documented the parametric logo glyph exception.
- `Shared/Utilities/Theme.swift`: strengthened the light-mode subtle text color and kept the existing dark-mode value.
- `DreamCart/Components/Common.swift`: normalized the shared candy button to `Theme.cardCorner`.
- `DreamCart/Components/ProductCard.swift`: gave every grid and shelf product title two reserved lines.
- `DreamCart/Views/WelcomeView.swift`: normalized the Apple sign-in control to `Theme.cardCorner`.
- `DreamCart/Views/CheckoutView.swift`: made summary product names editorial `dcItem` text with two reserved lines.
- `DreamCart/Views/CartView.swift`: reserved two lines for product names so rows align without abrupt truncation.
- `DreamCart/Views/OutfitBuilderView.swift`: made selected product names use the shared editorial item token.
- `DreamCart/Views/ClosetView.swift`: gave closet tile names two reserved lines.

## Screenshot paths

- Before: `sim77-design/before/`
- After: `sim77-design/after/`

The baseline audit captured the available authenticated screens with `xcrun simctl io` on simulator `FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8`. The tester account did not expose the outfit-builder route during the baseline tour. That state became available and was captured during final verification.

The authoritative after set uses canonical names in `sim77-design/after/`:

- Light: `light-today.png`, `light-shop.png`, `light-product-detail.png`, `light-cart.png`, `light-checkout.png`, `light-coin-shop.png`, `light-closet.png`, `light-outfit-builder.png`, `light-profile.png`, `light-spin.png`.
- Dark: `dark-today.png`, `dark-shop.png`, `dark-product-detail.png`, `dark-cart.png`, `dark-checkout.png`, `dark-coin-shop.png`, `dark-closet.png`, `dark-outfit-builder.png`, `dark-profile.png`, `dark-spin.png`.

All canonical after screenshots were captured with `xcrun simctl io` and visually inspected. The tester account gained owned pieces during the audit, so the after set includes the dressing room that was unavailable in the baseline state.

## Justified remaining system fonts

- `DreamCart/Components/CoinViews.swift`: the dollar mark scales relative to `CoinIcon.size`.
- `DreamCart/Components/CoinViews.swift`: the amount scales relative to the reusable `CoinLabel.size` supplied by callers.
- `DreamCart/RootView.swift`: the sparkle glyph scales relative to `BagMark.size`.

## Verification log

- Token enforcement: `rg -n '\.font\(\.system' DreamCart Shared` returns only the three documented parametric cases.
- Token enforcement tests: 6 tests passed on the required simulator with `xcodebuild test`.
- Voice and hierarchy tests: 6 tests passed on the required simulator with `xcodebuild test`.
- Final gate: 6 tests passed with 0 failures on the required simulator. The final raw-font grep still returns only the three documented parametric cases.

## Deliberately left unchanged

- Feature surfaces keep `Theme.corner`, while standard cards use `Theme.cardCorner`. Smaller raw radii remain only on nested media, fields, confetti, and avatar placeholders where the radius follows the element scale.
- Navigation structure, screen composition, candy gradients, gold coins, serif editorial identity, and reward moments were preserved.
- No design issues were punted after visual inspection. Numbered after files are intermediate audit artifacts; the canonical `light-*` and `dark-*` files are the reviewed deliverables.
