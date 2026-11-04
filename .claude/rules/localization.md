---
paths:
  - "DreamCart/**"
  - "Shared/**"
  - "Tools/Localization/**"
---

# DreamCart: localization (added 2026-11-04)

Every user-facing string in the iOS app routes through the catalog, which holds
`en` only for now. Separate runs add the other languages, then list them in
`CFBundleLocalizations` in `DreamCart/Info.plist` and in `LANGS` in `check.py`.
`android/` has its own strings and is out of this.

## Setup
- One catalog, `Shared/Localizable.xcstrings` (source `en`, every key
  `extractionState: manual`, every key with an `en` value). `Shared/` is a source
  of the app and the unit tests, so both compile it. XcodeGen 2.39+ reads its
  languages into `knownRegions`.
- `Info.plist` holds no purpose string and the app has no App Shortcuts or widgets,
  so there is no `InfoPlist.xcstrings` or `AppShortcuts.xcstrings`. Add one if that
  changes. The display name is the brand and stays out.
- `python3 Tools/Localization/check.py` (repo root, no Xcode needed) fails on a
  source literal with no key, a key with no source, a missing `en` value,
  mismatched format specifiers, and plain copy that can reach the screen: a
  `return "..."`, a ternary or `??` of literals, a `case .x: "..."`, an
  assignment, a copy-named argument, a copy helper's copy argument, a
  sentence-shaped literal, or a literal beside a String expression inside
  `Text(...)`. Run it before every build that touches copy. Identifiers it
  mistakes for copy go in its `ALLOWED` set, and new copy helpers in `COPY_FUNCS`.
- `check.py` compares `%@` and `%lld` loosely, since it has no compiler. The
  catalog key must match what Swift generates exactly (`Int` is `%lld`, `String`
  is `%@`), or the lookup silently falls back to the English in the source.
- `LocalizationTests` proves the catalog compiles to `en.lproj` and that plural,
  substitution and formatter output keep the English wording.

## Adding or changing copy
- `Text("literal")`, `Button`, `Label`, `Section`, `navigationTitle`, `alert`,
  `ProgressView` and friends localize themselves. Copy held in a `String` (view
  parameters such as `CandyButton(title:)` and `EmptyState`, enums, notifications,
  error messages) must be `String(localized: "...")`. Logs, analytics, RevenueCat
  ids, stored keys and tags stay plain.
- `Text(flag ? "literal" : someString)` compiles to String and shows the literal
  verbatim. Wrap the literal in `String(localized:)`.
- Whole sentences only, never spliced fragments. Branch and give each variant its
  own key (see the spin reward subtitle in `SpinView`). No `.capitalized` or
  `.uppercased()` on copy, and no logic that reads translated text: `Rarity` has
  `label` and `badgeLabel`, and `CoinPack` logic reads `productId` or `Badge`.
- Counts go in plural variations, or a `%#@n@` substitution when the sentence has
  other arguments. Pass the `Int` itself (`"\(pack.coins) coins"`), since `%lld`
  groups digits and picks the plural; a preformatted string can do neither. A count
  whose English never changes still carries a plural with `other` only, so a
  translator sees it is a count. English only has a `one` form where the source
  already had a singular wording ("1 coins" stays as it was).
- A count label drawn beside a separately rendered number cannot be a plural key:
  Xcode rejects plural variants that omit the number. `PluralLabel` asks the
  catalog's `"%lld plural category"` key for the CLDR category, then picks one
  whole key per category. The `(few)`, `(many)` and `(one)` keys carry an `en`
  value so English never shows the key.
- Coin amounts go through `DisplayFormat`; bare numbers through
  `Text(n, format: .number)` or `n.formatted()`. Prices come only from StoreKit,
  apart from the `StoreController` and `PlusPlan` placeholders shown until it answers.
- Never localize stored or server values: ledger `reason`, `product.category`,
  RPC error codes and analytics props stay as they are, and are mapped to a key at
  display time. Product names, brands, colors and style tags come from Supabase in
  English and are not in the catalog.
- Brand stays untranslated in meaning: DreamCart, DreamCart+, Apple Account.

## Proving a change
`python3 Tools/Localization/check.py`, then `gh-sim test --scheme DreamCart`.
