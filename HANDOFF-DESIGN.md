# DreamCart Design Language Handoff

## Status

- [x] Capture before screenshots in light and dark
- [x] Enforce typography and icon tokens
- [x] Audit editorial and functional voice consistency
- [x] Polish hierarchy, spacing, radii, overlines, truncation, and contrast
- [ ] Capture and inspect after screenshots in light and dark
- [ ] Run final tests and document remaining exceptions and punts

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

The baseline audit captured the available authenticated screens with `xcrun simctl io` on simulator `FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8`. The current tester account did not expose the outfit-builder route during the automated baseline tour. Required missing or misrouted states will be supplemented where the account state permits during final verification.

## Justified remaining system fonts

- `DreamCart/Components/CoinViews.swift`: the dollar mark scales relative to `CoinIcon.size`.
- `DreamCart/Components/CoinViews.swift`: the amount scales relative to the reusable `CoinLabel.size` supplied by callers.
- `DreamCart/RootView.swift`: the sparkle glyph scales relative to `BagMark.size`.

## Verification log

- Token enforcement: `rg -n '\.font\(\.system' DreamCart Shared` returns only the three documented parametric cases.
- Token enforcement tests: 6 tests passed on the required simulator with `xcodebuild test`.
- Voice and hierarchy tests: 6 tests passed on the required simulator with `xcodebuild test`.

## Deliberately left unchanged

Pending.
