---
paths:
  - "DreamCart/Views/MainTabView.swift"
  - "DreamCart/Components/PaneSheet.swift"
  - "DreamCart/Components/UnfoldedColumn.swift"
  - "DreamCart/DuoScreenshotMode.swift"
  - "DreamCart/RootView.swift"
  - "Shared/Utilities/UnfoldedSplit.swift"
---

# DreamCart: iPhone Duo (2026-10-21)

- Unfolded (regular width, at least 720 pt), `MainTabView` puts the browsing
  tabs (Today, For You, Closet, You, and the floating tab bar) on the leading
  side of the fold and the Cart on the trailing side, so a piece added from a
  grid, a detail or the For You deck lands in view. The Cart button leaves the
  tab bar while split; a route asking for the Cart tab keeps the current tab.
  Fold edges come from `GeometryProxy.verticalFold()` (iOS 27.1
  `reservedRegions(.division)`), else an even split (`UnfoldedSplit`, tested
  in `UnfoldedSplitTests`). Folded, every ordinary iPhone, and the unfolded
  Duo held in portrait keep the single column.
- Both panes get `horizontalSizeClass = .compact`, so each lays out as on a
  phone. Folding only moves frames: tabs stay mounted and keep their stacks.
  Do not wrap a pane in an `if`.
- `paneSheet` replaces `.sheet` for checkout (Cart and product detail), the
  coin shop (wallet pill), the spin wheel and the shipping form: unfolded,
  the content covers only its own pane via that pane's `PaneCoverHost`,
  outside the pane's NavigationStack. Views shown that way use
  `@PaneAwareDismiss` instead of `\.dismiss`. Folding hands an open cover
  back to a sheet.
- Splash, Welcome and the onboarding DreamCart+ offer go through
  `UnfoldedColumn`: trailing pane for the screen, brand pane on the left.
- Still system sheets, so centred across the fold: the coin upsell, the
  DreamCart+ offer from You, the ledger, notification primer and sign-in
  prompt.
- Captures: DEBUG `-DuoSeed -DuoTour` (`DuoScreenshotMode.swift`) seeds a
  local shopper (real public catalog, no session, no RevenueCat, analytics
  kept off the server) and walks `-DuoRoutes` on a timer. Recipe and timing
  flags: the run's `duo-run.sh` in `~/fleet-evidence/shift-duo-shop-*`.
