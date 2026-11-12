---
paths:
  - "DreamCart/Components/IPadLayout.swift"
  - "DreamCart/Components/UnfoldedColumn.swift"
  - "DreamCart/Views/**"
  - "Shared/Utilities/DeviceIdiom.swift"
  - "Shared/Utilities/UnfoldedSplit.swift"
  - "DreamCartUITests/IPadScreenshotTests.swift"
  - "project.yml"
  - "DreamCart/Info.plist"
---

# DreamCart: iPad layout (2026-11-12)

- `TARGETED_DEVICE_FAMILY "1,2"`, four orientations
  (`UISupportedInterfaceOrientations~ipad`), no `UIRequiresFullScreen`, so Split
  View and Slide Over work. iPhone stays portrait only. Once a version ships
  with iPad it cannot be removed.
- The iPhone Duo two-pane split is phone only: `DeviceIdiom.isPhone` gates
  `UnfoldedSplit.make`. An iPad is `.regular` width too and would otherwise
  get the Duo panes (hidden status bar, pane covers). Every Duo-only screen
  switch keys off `isUnfoldedPane`, which stays false on iPad.
- Layout keys off `horizontalSizeClass == .regular` (never the idiom), so a
  narrow Split View window falls back to the phone layout by itself.
- Widths live in `IPadLayout`: `content` 1100 (shelves, grids), `column` 640
  (Cart, You), `form` 520. `readableWidth(_:)` caps and centres. Phones are
  narrower than every cap.
- Product grids: `IPadLayout.productColumns` gives two flexible columns
  compact, adaptive tiles of 180 to 260 pt regular (Shop, brand page, Closet).
- Today: the claimed drop and the wheel sit side by side; shelf cards are 200
  pt (150 on a phone).
- For You: the deck is capped at 860 pt and the pass/add buttons flank the
  card when that leaves it taller (`DeckLayout.arrangement`).
- Product detail: photo beside the title, tags and specs; Complete the look
  below. The short-screen hero logic is skipped. The buy bar content is capped.
- Welcome, sign-in, and the onboarding DreamCart+ offer go through
  `UnfoldedColumn`: on iPad (window at least 640 pt) the brand fills the
  leading side and one phone column (max 560 pt) takes the trailing side, in
  portrait and landscape. The column is `.compact`, so it lays out as on a
  phone and the paywall keeps its zero-shift button slot. Narrower windows
  keep the single column.
- Sheets use `formSheetSizing()` (form size, 540 pt, iOS 18+). The wheel
  (`paneSheet(formSized: false)`) keeps the full page sheet for its height.
- The floating tab bar is 480 pt wide on iPad (355 on a phone).
- Capture: `DreamCartUITests/IPadScreenshotTests` on
  `gh-sim test --scheme DreamCartUITests --only DreamCartUITests/IPadScreenshotTests --device "iPad Pro 13-inch (M5)"`.
  It walks every route in portrait and landscape plus onboarding and the
  paywall and attaches the PNGs (`~/.gh-sim/results/<id>/attachments`). The
  `-DuoSeed` shopper is a Plus member and the screenshot paywall is
  `DREAMCART_PLUS_SHOT`.
