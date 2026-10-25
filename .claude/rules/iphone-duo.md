---
paths:
  - "DreamCart/Views/MainTabView.swift"
  - "DreamCart/Components/PaneSheet.swift"
  - "DreamCart/Components/UnfoldedColumn.swift"
  - "DreamCart/DuoScreenshotMode.swift"
  - "DreamCart/RootView.swift"
  - "Shared/Utilities/UnfoldedSplit.swift"
  - "Shared/Utilities/ShortScreenLayout.swift"
  - "DreamCart/Views/ProductDetailView.swift"
  - "DreamCart/Views/CartView.swift"
  - "DreamCart/Views/ClosetView.swift"
  - "Shared/Services/ImageDownsampler.swift"
  - "DreamCart/Components/ProductCard.swift"
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
- Scroll content runs beneath the floating tab bar
  (`FloatingTabBarReservation` reserves its height so the last row scrolls
  clear). Folded, `TabBarEdgeBlur` blurs it progressively down to the screen
  edge. Unfolded (review rejection, 2026-10-23: tiles blurred under the bar
  read as hidden there) the bar sits on a page-colour band from its top edge
  to the screen bottom (`TabBarPaneBand`), and each browsing screen ends its
  first screen on whole tiles above it: `FirstScreenRow` picks the fewest
  columns whose row fits (Today's Just dropped, every Today shelf at that
  card width, the Closet grid's first row), and what follows starts below
  the bar. Rows are measured in window space against the bar's top
  (`\.floatingTabBarTop`) only while the page rests at its top
  (`tracksScrollRest`). Unfolded, Today shows the claimed drop and the wheel
  as two short tiles side by side, and Closet drops the collection card (All
  pieces already counts them). Shelves stay inside the 16 pt margins: run
  to the fold, the last card was cut there (rejected twice). The row keeps
  12 pt clear of the bar (`FirstScreenRow.barGap`): at 20 pt three Today
  cards missed by 0.1 pt and four narrow ones wrapped their badges ("RAR /
  E"). Badges are `fixedSize`, and in a pane tile names shrink to 75%
  before truncating.
- Unfolded, the tab bar stays over a pushed product detail (folded it
  hides): every inner screen keeps one navigation. The detail reserves the
  bar's height under its buy bar.
- Unfolded, the status bar is hidden (`statusBarHidden` while split): the
  inner display's vertical status column (Wi-Fi in a charging ring, dots)
  read as a loading or debug badge beside the Cart.
- The Cart pane's rows and checkout bar end on the safe-area edge beside the
  inner display's 84 pt vertical status bar, in line with the wallet pill
  (`CartListLayout.trailingPadding`), not 16 pt further in.
- Pollinations stamps "pollinations.ai" in the bottom-right corner despite
  `nologo=true`; `ImageDownsampler` trims the bottom 6% of every product
  image (thumbnail cache key `v2:`). `RemoteImage` takes its frame from
  the backdrop and fills it with the art, so a trimmed (wider) image never
  widens a tile past its column.
- Short screens (a 669 pt pane, the 466x678 pt outer display): the product
  photo caps its height to keep the name above the buy bar, the claimed-daily
  strip drops "More tomorrow" rather than truncating, and the wallet pill
  reserves five digits because the toolbar kept its pre-load size ("18,4...").
  The leading pane ignores the trailing container inset, which the 24A94232
  simulator wrongly handed it (an 84 pt gutter at the fold).
- Nothing rests half under a bottom bar (review rejection, 2026-10-23):
  product detail shrinks its photo so the first screen ends on the tags and
  the spec card starts below the buy bar; the Cart tightens its rows when
  regular ones would cut the last; Closet chips that do not fit whole beside
  the sort button go in a "More" menu. Math in `ShortScreenLayout.swift`
  (`ShortScreenLayoutTests`). Product detail measures the buy bar's own
  global frame against the scroll view's top: on a scroll view carrying the
  bar's `safeAreaInset`, both `GeometryProxy` insets and iOS 18 scroll
  geometry undercounted the visible height by 70 to 145 pt, so the photo cap
  always fell to its floor. Its top is the larger of the scroll view's global
  minY and its top inset, never their sum: pushed in a pane, the frame
  already starts below the navigation bar and still reports it as an inset.
  The Cart (bar inset on an enclosing view) uses `onVisibleScrollSize`.
- Panes use their landscape shape (review rejection, 2026-10-23: phone-width
  columns centred in a pane). `\.isUnfoldedPane` is true in both panes and
  drives: the For You pass/add buttons flanking a taller card
  (`DeckLayout.arrangement`, tested); the capped product photo spanning the
  pane, the whole piece, sides feathered, on a blur of its own art
  (`RemoteImage showsWholePiece`; a `Color.clear` frame, since a ZStack grew
  to the filled wash and the art filled too), `DetailHeroLayout.widePhotoAspect`);
  shelves and grids of whole tiles across the pane (`FirstScreenRow`); and the product buy bar on the
  page background with an inset hairline, so no strip of material ends short
  of the Cart pane. Only the browsing pane shows the wallet pill
  (`\.showsWalletPill` is false for the Cart pane). Folded keeps every phone
  layout.
- For You card tags show as many whole tags as fit (`ViewThatFits`), never
  "#streetwear...".
- Both panes get `horizontalSizeClass = .compact`, so each lays out as on a
  phone. Folding only moves frames: tabs stay mounted and keep their stacks.
  Do not wrap a pane in an `if`.
- The tab ZStack is framed to fill before `onGeometryChange` measures it.
  Without that it shrank to the leading pane the moment the split framed it
  (the Cart pane mounts a tick later) and the split undid itself.
- Shop's search goes in the navigation bar drawer inside a pane (in the
  leading pane iOS laid it along the bottom edge, under the tab bar); folded
  keeps the automatic placement.
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
- gh-sim runners boot either iOS 27.1 build: 24A94232 (preinstalled) or
  24A94425 (downloaded). Judge captures on 24A94425; the `osBuildNumber` is in
  `test-summary.json`.
- Captures: DEBUG `-DuoSeed -DuoTour` (`DuoScreenshotMode.swift`) seeds a
  local shopper (real public catalog, no session, no RevenueCat, analytics
  kept off the server) and walks `-DuoRoutes` on a timer. Recipe and timing
  flags: the run's `duo-run.sh` in `~/fleet-evidence/shift-duo-shop-*`.
  One `gh-sim all` run captures every surface: pass one
  `--screen "-DuoRoutes <route>"` per surface (gh-sim relaunches per screen,
  folded and unfolded). Never `--url`: `dreamcart://` links raise the system
  "Open in DreamCart?" alert in the shot, and made-up URLs are not allowed.
  Results of a job started by another session: `gh run download <run> -R
  jackwallner/gh-sim` (`gh-sim get` only knows its own session's runs).
