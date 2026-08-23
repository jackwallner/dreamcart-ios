# DreamCart (shop) audit823

Audit date: 2026-08-23

## Scope and evidence discipline

This is an implementation handoff audit for the DreamCart repository at
/Users/jackwallner/shop. The review covered:

- SwiftUI source, shared services, models, StoreKit, RevenueCat integration,
  Supabase functions and migrations.
- project.yml, generated Xcode project references, Info.plist, entitlements,
  tests, release scripts, App Store Connect metadata sources, screenshots,
  subscription setup, review notes, and screenshot capture tests.
- onboarding, authentication, guest browsing, first value, daily reward, spin,
  shop, product detail, cart, virtual checkout, unboxing, closet, outfits,
  profile, coin shop, coin upsells, DreamCart+, restore, legal links,
  accessibility labels, loading, retry, cancellation, and error states.
- landing site, privacy, terms, support, analytics privacy notes, ASO notes,
  handoffs, design screenshots, archive notes, CLAUDE.md, and the absence of
  README.md, AGENTS.md, or Cursor rules in the repository.

Evidence labels used below:

- Evidence: directly observed in source, local assets, local scripts, or the
  read-only ASC command output recorded below.
- Inference: a likely consequence of the evidence that still needs runtime or
  production confirmation.
- Recommendation: work for the implementation agent. It is not a claim that
  the recommendation is already implemented.

No download, conversion, trial-start, revenue, rating, crash, or RevenueCat
dashboard metric was fabricated. No live RevenueCat dashboard data was
available in this repository pass. RevenueCat tracking and data-collection disclosure consistency is intentionally omitted as requested. Other product,
website, legal, analytics, and subscription consistency issues are included.

The audit worker did not build, upload, submit, or modify app code or
configuration. The only intended output from this worker is this file.

## Executive decision

DreamCart has a strong, differentiated core loop and polished local store
assets. The most urgent implementation work is not visual polish:

1. Clear the live ASC release blocker. The read-only
   scripts/asc-release-audit.py run on 2026-08-23 reported exactly one
   blocker: expected one READY_FOR_REVIEW submission, found 0.
2. Make DreamCart+ truthful everywhere. The binary, StoreKit file, paywall,
   review notes, and release scripts describe an active weekly subscription,
   while the public landing page, support page, terms, privacy context, and
   localized store descriptions still describe a product with no subscription.
3. Prevent false success and invisible failure around the trial and daily
   value loop. A successful Apple purchase can show an unlocked overlay before
   the server has set is_plus, and daily claim or spin failures can return to
   the idle UI without an explanation or retry.
4. Add a production release-watchdog path. There is no evidence of a crash
   reporter, MetricKit collector, ASC crash polling, or server-side alert
   scaffold in this repository.
5. Add a real ratings funnel and structured monetization telemetry. There is
   no requestReview call, no Profile rate or feedback entry, no RevenueCat
   custom attribute setup, and no explicit trial-start event.

The local metadata validator is healthy, so the metadata work is primarily
truthfulness, experiment design, localization QA, and live release
verification rather than character-limit repair.

## 1. Prioritized findings

Severity meanings:

- P0: blocks release correctness, monetization correctness, or a material
  user promise.
- P1: likely harms conversion, retention, trust, or production recovery.
- P2: important quality, maintainability, or scale improvement.

| ID | Severity | Impact | Effort | Confidence | Finding and evidence |
|---|---|---|---|---|---|
| F-01 | P0 | Release cannot be submitted through the expected flow | S | High | Read-only ASC audit reported no READY_FOR_REVIEW submission. Evidence: scripts/asc-release-audit.py:112-126 and command output on 2026-08-23. |
| F-02 | P0 | Public users, reviewers, and agents receive contradictory monetization promises | M | High | Active DreamCart+ is present in DreamCart.storekit:87-116, PlusOfferView.swift:200-223, and scripts/asc-setup-release.py:16-30, but docs/index.html:606-610 says there is no subscription. |
| F-03 | P1 | New subscribers can see an unlocked message before server state is active | M | High | PlusOfferView.swift:241-247 calls refreshMe immediately after purchase, while ShopStore.swift:162-164 swallows refresh failure and redeem is not called on this path. |
| F-04 | P1 | Trial and daily-value failures silently look like ordinary idle state | S | High | ShopStore.swift:198-212 returns nil from claimDaily and spin; TodayView.swift:219-228 and SpinView.swift:327-335 stop loading without an error or retry. |
| F-05 | P1 | Ratings and review growth are entirely unaddressed | M | High | No requestReview, SKStoreReviewController, rating, or feedback runtime implementation was found. ProfileView.swift:285-337 has no rate or feedback row. |
| F-06 | P1 | A release regression can affect users without an automated detection path | M | High | No MetricKit, crash SDK, ASC crash polling, watchdog, or server alert scaffold was found. Existing telemetry is best effort and silently dropped: Analytics.swift:81-97. |
| F-07 | P1 | RevenueCat cannot segment paywall, trial, or lifecycle behavior beyond impressions | M | High | No setAttributes, customer attribute, offering, currentOffering, RevenueCatUI, or explicit trial-start implementation was found. StoreController.swift:64-76 only sends custom paywall impressions. |
| F-08 | P1 | The trial is offered before the user has experienced the free loop | M | Medium | A brand-new signed-in user goes from onboarding into PlusOfferView before the tab loop: RootView.swift:23-40. The app has not yet claimed daily coins, spun, browsed, or unboxed. |
| F-09 | P1 | Store screenshots are polished but obscure lower content in several frames and do not sell the membership | S | Medium | Local 1320x2868 screenshots are valid and visually polished, but the floating tab bar overlaps lower card copy in shop, coins, and closet frames. No app preview video asset was found. |
| F-10 | P1 | ASO passes limits but does not explain the current monetization or trial proposition | M | High | Local source descriptions in scripts/asc-localized-copy.json:42-44 and all locale variants describe optional coin packs but never DreamCart+ or the 3-day trial. |
| F-11 | P1 | Price and availability states can show a generic or hardcoded US price | S | High | StoreController.swift:80-91 uses hardcoded dollar fallbacks; PlusOfferView.swift:215-223 can render a weekly charge with no price while the CTA remains active. |
| F-12 | P1 | Support and legal pages omit the current subscription path and one landing-page claim conflicts with local storage | M | High | support.html:29-65 covers only coin packs; docs/index.html:588 says no shipping address is ever collected while CheckoutView.swift:68-109 and ShippingAddressStore.swift persist a fictional address locally. |
| F-13 | P2 | Swift 6 and iOS 27 warnings can become release regressions | S | High | ios27DreamCart.md:1-26 records main-actor warnings in Haptics.swift:5-45 and an unused mutable declaration in SupabaseClient.swift:123. No current build was run during this audit. |
| F-14 | P2 | Agents can act on stale product truth or nonexistent paths | S | High | Completed root handoffs remain beside active instructions, OnboardingCoinOfferView.swift is an orphaned legacy surface, and HANDOFF-UX.md:71-77 and HANDOFF-DESIGN.md:28 reference CompositeAvatarView.swift and OutfitBuilderView.swift that are not present in the current file list. |
| F-15 | P2 | Accessibility and localization can break the densest paywall controls | S | Medium | PlusOfferView.swift:104-126 uses a fixed four-control HStack without a ViewThatFits or explicit accessibility identifiers. The paywall has not been validated at XXL Dynamic Type or RTL in this pass. |
| F-16 | P2 | Product ID drift can create dormant products and mismatched lifecycle handling | M | High | rc-webhook/index.ts:22-26 lists weekly, monthly, and yearly Plus IDs, while the app and StoreKit file define weekly only. |

## 2. Product and architecture map

### Current product promise

DreamCart is a virtual fashion shopping game. The free loop is:

1. Browse original virtual fashion.
2. Claim a daily coin drop.
3. Spin the free wheel.
4. Add items to a cart.
5. Check out with virtual coins.
6. Watch the unboxing moment.
7. Keep the item in a closet and assemble outfits.

Optional monetization is currently:

- Five consumable coin packs, from $1.99 to $49.99 in the local StoreKit
  configuration.
- DreamCart+ weekly at $0.99 with a three-day free trial in the local
  StoreKit configuration. It doubles daily coins and removes the daily spin
  limit.

The code source of truth is split between:

- SwiftUI product flow in DreamCart/.
- Shared services in Shared/Services/.
- Product and price constants in Shared/Services/Config.swift.
- StoreKit testing in DreamCart.storekit.
- ASC scripts and copy in scripts/.
- Backend fulfillment and membership state in supabase/.
- Public promises in docs/.

This split is workable, but it currently permits the public website, ASC copy,
StoreKit, backend product sets, and agent docs to drift independently.

### Current install-to-value path

| Stage | Observed behavior | Conversion or UX implication |
|---|---|---|
| Launch | DreamCartApp.swift:67-84 tracks session_start, restores auth, loads catalog, reconciles purchases, and keeps RootView on SplashView until hasLoadedOnce. | Good protection against an empty shell, but startup duration and failure-to-ready are not measured. |
| Onboarding | WelcomeView.swift:10-59 has three slides, page dots, Next, and Get started. It explains guilt-free shopping, daily coins, and the closet. | Clear promise, but it does not show an actual product, daily reward, or trial value before the account decision. |
| Account decision | SignInPanel offers Sign in with Apple and Browse without an account. Guest browsing is allowed, but cart, closet, coins, favorites, and other account actions call requireAccount. | Guest access is App Review friendly, but the first meaningful reward is account gated. Test whether guest-first browsing increases sign-in completion or only creates dead ends. |
| First signed-in load | RootView.swift:23-40 waits for catalog load, then shows PlusOfferView for a first-run signed-in user before MainTabView. | The user is asked to subscribe before seeing the free daily coin or wheel result. |
| First value | TodayView.swift contains the daily claim and spin path. Shop and For You provide discovery. | The free loop is strong, but claim and spin backend failures are silent. |
| Spend moment | Cart and checkout use virtual coins. Insufficient balance opens CoinUpsellView, then CoinShopView. | Good contextual upsell location. The current telemetry does not include balance, cart value bucket, or whether the upsell returned the user to checkout. |
| Membership | PlusOfferView is reachable from onboarding and ProfileView.swift:320-335. | Existing users have a path, but the post-purchase state depends on the webhook and immediate profile refresh. |
| Retention | Local daily drop notification and new-drops deep link exist in LocalNotificationCoordinator.swift:177-203. | No notification-open, notification-conversion, or permission-denied funnel is recorded. |

## 3. Download growth and App Store Connect audit

### Live ASC check

I ran the existing read-only command with the shared ASC credentials:

    source /Users/jackwallner/.baseball_credentials && python3 scripts/asc-release-audit.py

Observed output on 2026-08-23:

    validated 50 locales at 24/24/94+ within Apple limits, no price references
    blockers: 1
    BLOCKER: expected one READY_FOR_REVIEW submission, found 0

The command did not print another blocker or warning. This is release-state
evidence only. It is not a download, conversion, rating, revenue, or trial
metric. The command is read-only in its normal audit path. The implementation
agent should create or attach the intended review submission, then rerun this
check before release.

### Metadata character counts

Source: scripts/asc-localize-metadata.py and scripts/asc-localized-copy.json.
The validator covers 50 locales and enforces the local target minimums and
Apple maximums.

| Field | en-US exact count | All 50 locales | Local limit or target |
|---|---:|---:|---|
| Name | 28 | 24 to 30 | Target 24 to 30, Apple max 30 |
| Subtitle | 28 | 24 to 30 | Target 24 to 30, Apple max 30 |
| Keywords | 100 | 97 to 100 | Target 94 to 100, Apple max 100 |
| Promotional text | 112 | 40 to 159 | Apple max 170 |
| Description | 883 | 391 to 1141 | Apple max 4000 |

Exact en-US source values:

- Name: DreamCart: Dopamine Shopping, 28 characters.
- Subtitle: Outfit Maker & Dress Up Game, 28 characters.
- Keywords: fashion,retail,therapy,stylist,planner,creator,clothes,closet,app,wardrobe,shopaholic,simulator,glam, 100 characters.
- Promotional text: New coins every day. Spin, shop, collect virtual fashion, and build your dream closet without a real-world bill., 112 characters.
- Description: the 883-character value at scripts/asc-localized-copy.json:42-44.

Evidence:

- scripts/asc-localize-metadata.py:28-35 defines the 50 locale list.
- scripts/asc-localize-metadata.py:114-182 defines subtitle and keyword
  overrides.
- scripts/asc-localize-metadata.py:235-282 builds and validates metadata.
- scripts/asc-localized-copy.json:42-44 contains the en-US description and
  promotional text.

Recommendations:

1. Keep the current title and subtitle as a control. They are within limits
   and communicate the category.
2. Add an experiment variant that emphasizes the immediate free loop, for
   example daily coins plus virtual fashion, versus the current outfit-maker
   framing. Do not change title, subtitle, keywords, and screenshots at the
   same time.
3. Consider replacing low-intent or ambiguous keywords only after using the
   existing Astro keyword data in docs/astro-aso-setup.md. Do not infer
   keyword demand from memory. The ASO note says it was last validated July
   19, 2026 and describes a temporary Astro app ID. Revalidate before using
   its ranking data.
4. Update descriptions and promotional text to accurately explain that
   DreamCart+ exists, has a three-day trial, renews weekly, and is optional.
   Keep the free-play promise explicit. Do not put a volatile price in title
   or subtitle.
5. Audit every localized description for native fluency, terminology for
   virtual currency, trial language, and the legal URLs. The character pass
   does not prove translation quality. Some keyword rows retain English
   words such as trend, brand, haul, fashion, and game inside otherwise
   localized keyword strings. That may be intentional ASO practice, but it
   needs locale-specific validation.
6. Add subscription localization checks to the ASC audit. The current
   asc-release-audit.py checks five consumable IAPs, but not DreamCart+
   subscription state, group localization, all subscription localizations,
   introductory offer coverage, or entitlement wiring.

### Screenshot, icon, and preview audit

Local assets:

- fastlane/screenshots/en-US/appstore_01_shop.png through
  appstore_05_spin.png are all 1320x2868, 8-bit RGB PNGs.
- docs/appstore-screenshot-01.png through -05.png are byte-for-byte matches
  to the five fastlane assets, confirmed by SHA-256 on 2026-08-23.
- fastlane/iap_screenshots/plus_weekly.png is 1206x2622 RGB and shows the
  three-day trial, $0.99 weekly price, renewal, cancellation, Restore,
  Terms, and Privacy.
- DreamCart/Assets.xcassets/AppIcon.appiconset/icon_1024.png is 1024x1024
  RGB. docs/icon_256.png is the matching web icon.
- No .mov or .mp4 app preview asset was found in the repository.

Visual evidence from the five local App Store screenshots:

- The visual identity is cohesive, recognizable, and high quality. The
  purple, coral, gold, and editorial type treatment is consistent.
- appstore_01_shop.png, appstore_02_coins.png, and appstore_04_closet.png
  show the floating tab bar overlapping or competing with lower product
  content. The problem is most visible where a title or card edge sits behind
  the bar.
- appstore_03_checkout.png has the clearest transaction story and is a good
  conversion frame.
- appstore_05_spin.png clearly communicates the free wheel and the reward
  moment.
- The public five-frame set does not show DreamCart+, a trial, or the
  membership benefits. This is acceptable for a free-loop control, but it
  leaves the subscription acquisition story entirely to in-app traffic.

Recommendations:

- Re-capture or crop the affected frames after reserving the floating tab-bar
  safe area. Compare a current frame against the existing SHA values before
  replacing both fastlane and docs copies.
- Test first-three-frame ordering as an ASO experiment: core shopping,
  daily/free loop, then checkout or spin. Keep the current ordering as the
  control.
- Add an App Preview only after a real flow capture proves that network images,
  daily rewards, and checkout render reliably. A preview that starts on a
  loading shimmer or shows a failed image will reduce trust.
- Keep the icon family, but test 29px and 40px legibility and dark/light
  contrast. The mark is recognizable at full size; no evidence was collected
  for small-size App Library or notification contexts.
- Add screenshot dimension, color mode, alpha, duplicate SHA, ordering, and
  stale-display checks to the release script. The upload script currently
  uploads sorted PNGs and computes a checksum for ASC, but does not validate
  dimensions, alpha, order semantics, or duplicate content:
  scripts/asc-upload-screenshots.py:18-21 and :60-120.

## 4. Install, first value, trial, and user experience

### Onboarding and authentication

Evidence:

- WelcomeView.swift:10-17 presents three slides.
- WelcomeView.swift:31-59 records onboarding steps and completion.
- SignInPanel.swift presents Sign in with Apple, Browse without an account,
  privacy, and Apple Standard EULA links.
- AuthController.swift:15-69 explicitly permits guest catalog browsing and
  records signin_prompted with a feature value.
- RootView.swift:23-40 decides whether a new signed-in user sees PlusOfferView.

Observed strengths:

- The promise is emotionally clear and differentiated: shopping ritual without
  real-world cost.
- Guest browsing is available before account creation.
- Apple sign-in errors and progress are visible.
- The onboarding page dots have labels and selected traits.
- Reduce Motion is honored on the onboarding page animation.

Conversion risks:

1. The user must complete three slides, finish the sign-in decision, wait for
   catalog load, and then receive a full-screen membership offer before
   seeing the daily reward or wheel. This is a long path to first value.
2. Guest browsing can lead to account gates when a user tries to claim,
   favorite, add to cart, or use the wallet. The gate has a useful sign-in
   path, but the user may experience a sequence of blocked actions before
   deciding to register.
3. There is no explicit first-value event for daily claim, first spin,
   first product view, first cart add, first checkout, or first unboxing in
   the onboarding funnel. Existing events can be joined, but a simple
   first_value_completed marker is missing.

Experiments:

- Control: current onboarding slides, sign-in, immediate PlusOfferView.
- Variant A: same slides, allow one guest catalog session, prompt sign-in
  after a daily reward or first cart intent.
- Variant B: sign-in, then daily claim and spin, then PlusOfferView after the
  first reward. Keep a soft exit.
- Variant C: sign-in, show a compact benefit card on Today, open the full
  offer after the user has claimed or spun.

Guardrails:

- Measure onboarding completion, sign-in completion, guest-to-sign-in,
  first-value completion, Plus offer view, trial start, seven-day return,
  and uninstall proxy if available.
- Do not make sign-in or trial purchase required for the free loop.
- Keep the current path as a control until each variant has enough users for
  a stable decision. No live rates are asserted in this audit.

### Paywall and monetization surface inventory

| Surface | Entry | Product | Current state | Main issue or opportunity |
|---|---|---|---|---|
| Onboarding Plus | New signed-in user after catalog load | DreamCart+ weekly | Full screen, trial-aware headline, soft exit | Test after first value. Add explicit loading and purchase-result states. |
| Profile Plus | ProfileView.swift:320-335 | DreamCart+ weekly | Active member opens Apple manage URL; nonmember opens sheet | Good reachability fix. Add offer impression context and restore outcome events. |
| Wallet coin shop | WalletPill and Get more coins | Five consumables | Full list, localized RC prices, error banner, Restore intentionally absent for consumables | Add price state, selected-pack event, purchase failure event, and return-to-intent event. |
| Insufficient balance | Checkout place bar | Recommended Bag pack | CoinUpsellView with full shop fallback | Good contextual nudge. Measure whether users return to checkout or abandon. |
| Post-spin low balance | Reward completion when balance is low | Recommended Bag pack | Capped nonblocking upsell | Test delay, copy, and whether the reward overlay should finish before the sheet. |
| Legacy onboarding offer | Orphaned OnboardingCoinOfferView.swift | Bag coin pack | Not referenced by current RootView | Remove or archive from active source after confirming no build target or deep link uses it. |

### Paywall state audit

DreamCart+:

- Loading: PlusOfferView.task calls loadProducts and
  refreshPlusTrialEligibility at PlusOfferView.swift:137-140.
- Price available: disclosure includes trial, localized price, weekly period,
  renewal, and cancellation at PlusOfferView.swift:215-223.
- Price unavailable: disclosure becomes a generic weekly charge or billing
  statement, but the CTA remains available. There is no visible price
  loading state, retry button, or unavailable state.
- Trial eligibility: StoreController.swift:120-138 checks RevenueCat
  introductory eligibility when configured. On the StoreKit testing path,
  StoreController.swift:102-112 derives it from the local product.
- Purchase: PlusOfferView.swift:228-248 tracks start, awaits purchase, calls
  refreshMe, and shows unlocked on success.
- Cancel: the soft-exit button remains present. The view cancels buyTask on
  disappearance at PlusOfferView.swift:141-146.
- Restore: PlusOfferView.swift:250-261 calls RevenueCat restore and shows an
  error if no membership is returned.
- Legal: Terms is Apple Standard EULA and Privacy points to the GitHub Pages
  policy at PlusOfferView.swift:265-270.
- Accessibility: button labels are readable, but there are no stable
  accessibility identifiers for the primary CTA, Restore, Terms, or Privacy.

Coin shop and upsell:

- CoinShopView.swift:19-45 shows the balance, error banner, five packs, and
  impression event.
- CoinShopView.swift:54-70 cancels tasks and resets state on disappearance and
  watches scene phase.
- CoinShopView.swift:180-211 has a specific stale StoreKit recovery path.
- CoinUpsellView.swift:74-104 records trigger and impression, has a soft exit,
  and mirrors stale purchase recovery at :203-223.
- CheckoutView.swift:174-220 exposes insufficient coins, address resolution,
  a place-order loading state, and reason-specific alerts.

Important missing or weak states:

1. Plus purchase has no equivalent to CoinShopView.recoverIfStale. A
   suspended StoreKit await can leave local buying state or the shared
   StoreController state stale.
2. Plus restore has no started, succeeded, no-membership, cancelled, or
   latency event. A support agent cannot distinguish a user who tapped
   Restore from one who never saw the offer.
3. The Plus success overlay says unlocked even if the webhook has not yet
   set profiles.is_plus. The implementation should show a pending
   confirmation state or poll/reconcile with a bounded timeout.
4. Purchase success is not separated into trial start, paid initial purchase,
   renewal, restore, and delayed fulfillment. plus_purchased is too coarse.
5. CoinShopView only records a completed purchase when the balance increases.
   A valid Apple purchase with delayed backend fulfillment has no explicit
   pending or failure event.
6. Claim and spin failure return to the idle state without a visible reason.
7. Refresh-me, closet, favorite, recommendation, and redemption errors are
   often suppressed with try? and no user-facing retry.

### Checkout and virtual shipping

CheckoutView.swift:68-109 asks the user to add a fictional address or tap Skip
for now. CheckoutView.swift:37 says no real address is needed and nothing
ships. This is a playful differentiator, but it adds a detour between cart and
the reward moment.

Recommendation:

- Keep the address as an optional post-purchase flavor experiment, not a
  required pre-checkout choice. Compare current explicit choice against a
  default skip with an optional Add a pretend address link.
- If the current choice remains, add an analytics property for
  address_choice, not the address itself, and measure checkout completion.
- Keep the local-only storage statement aligned with the website and privacy
  page. Do not claim that no address is ever collected when the app stores an
  address locally.

### Accessibility and poor-flow checks

Observed strengths:

- ProductCard.swift:86 and nearby components provide a retry state for image
  failures.
- Product detail favorite has a stateful accessibility label at
  ProductDetailView.swift:122-134.
- SpinView.swift:70-76 labels the wheel and exposes its prize values.
- MainTabView.swift:74-100 labels tabs and selected state.
- Reduce Motion is handled in onboarding, spin, reward, and celebration paths.

Validation gaps:

- Test PlusOfferView at the largest Dynamic Type size. Its bottom HStack at
  PlusOfferView.swift:114-126 has four controls and no wrapping fallback.
- Test RTL, long localized terms, long subscription prices, and the longest
  localized description or disclosure on the device.
- Add accessibility identifiers to all monetization controls and use them in
  UI tests. The current PlusPaywallScreenshotTests.swift:21-39 waits for text
  containing per week, which verifies price text but not the CTA, Restore,
  legal links, or soft exit.
- Test VoiceOver focus order on the price disclosure, CTA, Restore, Terms,
  Privacy, and close action.
- Test the floating tab bar with large text and a keyboard. MainTabView.swift:
  13-45 describes the safe-area workaround, and the screenshot overlap shows
  why an actual device-size regression test is still needed.

## 5. RevenueCat, StoreKit, attributes, and events

### Current implementation

Evidence:

- project.yml:18-21 uses RevenueCat from 5.72.0.
- project.yml:65-68 compiles HAS_REVENUECAT and links the package.
- DreamCart.storekit:87-116 contains SG-PLUS and the weekly subscription with
  a P3D free trial.
- StoreController.swift:25-41 configures RevenueCat and calls loadProducts.
- StoreController.swift:43-60 fetches five coin IDs plus the weekly Plus ID
  directly by product identifier.
- StoreController.swift:64-76 sends RevenueCat custom paywall impressions.
- StoreController.swift:120-138 checks introductory-offer eligibility.
- StoreController.swift:141-175 purchases and restores Plus.
- ShopStore.swift:425-433 calls the redeem function at launch, sign-in, and
  after coin purchases.
- supabase/functions/redeem/index.ts:115-121 sets is_plus based on whether
  any active entitlement exists.
- supabase/functions/rc-webhook/index.ts:22-26 has weekly, monthly, and yearly
  IDs and :58-65 toggles membership for selected lifecycle events.

Not found:

- No Purchases.shared.setAttributes or equivalent customer attribute setup.
- No RevenueCat offerings or currentOffering call.
- No RevenueCatUI or native RevenueCat paywall.
- No explicit first-party trial-start event.
- No restore funnel events.
- No event carrying variant, price state, eligibility state, or purchase
  result for the Plus paywall.

This means the app is using direct product lookup and custom SwiftUI
paywalls. There are no RevenueCat native paywall knobs currently in use.

### Recommended attribute model

Use only low-sensitivity, bucketed product context. Do not add raw addresses,
email, free-form user content, or unneeded taste detail as RevenueCat
attributes. Keep first-party event detail in the existing analytics pipeline
where it is already designed for product analysis.

| Attribute | Value shape | Exact insertion location | Why |
|---|---|---|---|
| app_version | short version plus build | StoreController.configure after RevenueCat configuration, StoreController.swift:25-38 | Segment release regressions and price or paywall behavior. |
| locale | BCP-47 locale string | Same configure path | Compare localized price and copy behavior. |
| auth_state | guest or signed_in | DreamCartApp.swift:73-80 after auth bootstrap | Separate acquisition and guest-to-account behavior. |
| onboarding_completed | boolean | WelcomeView.swift:48-55 when Get started completes | Compare users who saw the full offer. |
| first_value_state | none, claim, spin, browse, cart, checkout | At first-value transitions in TodayView, ProductDetailView, CartView, and Celebration | Target trial timing without joining many events. |
| coin_balance_bucket | zero, 1-999, 1k-4.9k, 5k+ | Before coin shop and upsell impressions in CoinShopView.swift:42-45 and CoinUpsellView.swift:74-78 | Explain purchase intent without exposing a raw balance. |
| cart_value_bucket | zero, low, medium, high | CoinUpsellView buy path and CheckoutView place path | Compare insufficient-balance conversion. |
| plus_eligibility | eligible, ineligible, unknown | PlusOfferView.task and onAppear, PlusOfferView.swift:137-145 | Separate trial promise from returning subscribers. |
| plus_surface | onboarding or profile | PlusOfferView.swift:55-61 and :142-144 | Compare placement. |
| plus_state | none, trial, active, expired, billing_issue | After CustomerInfo or server profile reconciliation | Segment retention and recovery. |
| paywall_variant | stable experiment assignment | Before each paywall impression in StoreController.swift:67-76 | Make A/B results reproducible. |

RevenueCat's current SDK method names should be verified against the pinned
5.72.0 API before implementation. The insertion locations above are exact
source boundaries, not a claim about an unverified method signature.

### Recommended event additions

First-party events should be explicit enough to diagnose the funnel without
reading UI text:

| Event | Add at | Required properties |
|---|---|---|
| first_value_completed | First successful daily claim, first successful spin, or chosen canonical value moment | value_type, source, app_version |
| plus_offer_state | PlusOfferView after product and eligibility load | source, paywall_id, variant, eligibility, price_state, localized_price_present |
| plus_purchase_started | Existing PlusOfferView.swift:235-236 | source, paywall_id, variant, eligibility, price_state |
| plus_trial_started | After RevenueCat CustomerInfo or webhook confirms trial period | product_id, source, variant, period_type, confirmation_latency_seconds |
| plus_initial_purchase | After paid initial purchase confirmation | product_id, source, variant, period_type |
| plus_purchase_failed | All false returns and thrown purchase errors | source, product_id, error_code, user_cancelled, price_state |
| plus_restore_started | PlusOfferView.swift:250 | source |
| plus_restore_result | PlusOfferView.swift:254-260 | source, outcome, latency_seconds |
| plus_entitlement_pending | When Apple purchase succeeds but profile is not active | product_id, source, elapsed_seconds |
| coin_purchase_failed | CoinShopView.swift:160-177 and CoinUpsellView.swift:176-200 | product_id, trigger, error_code, balance_bucket |
| purchase_fulfillment_pending | After Apple success and before balance delta is observed | product_id, expected_coins, elapsed_seconds |
| daily_claim_failed | ShopStore.swift:198-203 | error_code, retryable, app_state |
| wheel_spin_failed | ShopStore.swift:205-212 | error_code, retryable, balance_bucket |
| notification_permission_result | LocalNotificationCoordinator.swift:147-164 | result, previous_state |
| notification_opened | AppDelegate route handler in DreamCartApp.swift:67-72 | route |
| rating_prompt_shown, rating_positive, feedback_started | New review gate | trigger, days_since_install, completed_value_count |

Avoid using localized error strings as event keys. Normalize errors into a
small code set such as product_unavailable, network, user_cancelled,
not_entitled, server_pending, and unknown.

### Backend membership risks

1. redeem/index.ts:115 still says DreamCart+ entitlement if ever added, even
   though it is active. The comment is stale and can mislead an agent.
2. redeem/index.ts:118-121 treats any active entitlement as Plus. Use an
   explicit entitlement identifier or product set so an unrelated entitlement
   cannot grant membership.
3. rc-webhook/index.ts:22-26 contains monthly and yearly IDs that are not in
   the app or StoreKit file. Choose one canonical product set and make the
   scanner fail on drift.
4. The webhook maps app_user_id directly to the Supabase user ID. Add an
   unknown-user and empty-user guard with an observable failure path.
5. Webhook calls to set_plus do not report response failure. Add structured
   logs and a retry or dead-letter path for RPC failure.
6. Plus purchase does not call redeem after the device purchase. It relies on
   the webhook plus immediate refreshMe. Add a bounded reconcile/poll path so
   the UI can distinguish pending backend state from failed purchase.

## 6. Ratings, reviews, and trust growth

Evidence:

- A repository search found no requestReview, SKStoreReviewController, rating,
  feedback, or native review request implementation.
- ProfileView.swift:285-337 has DreamCart+, coin shop, shipping, ledger, and
  sign-out actions, but no Rate DreamCart or Send feedback row.
- Existing success events include checkout_completed and
  celebration_completed, which provide reasonable positive-intent triggers.

Recommended funnel:

1. Ask a lightweight satisfaction question after an earned success, such as
   the first completed unboxing, a second successful daily return, or a
   successful Plus trial start. Do not ask on cold launch or immediately after
   an error.
2. If positive, call StoreKit's request-review API. The system may suppress
   the visible prompt, so track the attempt rather than claiming that the
   sheet appeared.
3. If negative, open a private feedback or support path and record only the
   selected reason and trigger, not free-form private content in RevenueCat.
4. Add a Profile row for Rate DreamCart and Send feedback. The row should
   deep-link to the App Store or mail/support flow without blocking any app
   action.
5. Cap prompts by user and version. A practical starting policy is one
   satisfaction gate per major success milestone and no more than one native
   review request per version, subject to Apple's system limits.

Experiments:

- Trigger after first unboxing versus after the second daily return.
- Positive preprompt wording focused on the shopping ritual versus the free
  daily loop.
- Profile row present versus hidden behind a Help section.

Validation:

- Unit test the gate policy with simulated install date, app version,
  success count, negative response, and cooldown.
- UI test both branches without relying on the system review sheet appearing.
- Verify an error or payment failure never triggers the prompt.

## 7. Website, legal, support, and metadata consistency

### Contradictions requiring immediate repair

| Topic | Evidence | Risk | Required decision |
|---|---|---|---|
| Subscription existence | docs/index.html:606-610 says No paid tier and no subscription. StoreKit and paywall define DreamCart+ weekly. | Users and reviewers can see a false product statement. | Make the subscription real in all public copy, or remove it consistently. Current code and review notes indicate it should remain. |
| Subscription support | support.html:48-53 only describes coin packs and says consumables cannot be restored. It has no trial, renewal, manage, or Plus restore guidance. | A trial or billing issue sends users to incomplete support. | Add DreamCart+ trial, renewal, cancellation, restore, Apple account billing, and Manage Subscription guidance. |
| Terms | terms.html:98-150 covers virtual products and Apple billing but has no explicit DreamCart+ weekly trial, auto-renewal, cancellation timing, or membership benefit. | Subscription promise and legal terms are incomplete. | Add an accurate subscription section and keep Apple EULA link visible in app and web. |
| Privacy page context | privacy-policy.html:98-166 describes account, game, local address, and service processing, but does not clearly explain the current Plus customer-state flow. | Users cannot understand membership-state handling. | Update product context without expanding the excluded RevenueCat disclosure audit. |
| Address statement | docs/index.html:588 says no shipping address is ever collected because nothing ships. CheckoutView.swift:68-109 and ShippingAddressStore.swift store a fictional address locally. | Public copy is literally inconsistent with the app behavior. | Say that an optional fictional address is stored locally and nothing physical ships. |
| JSON-LD prices | docs/index.html:30-54 lists free, $1.99, $4.99, and $9.99 only. It omits $19.99, $49.99, and DreamCart+. | Search engines and agents receive an incomplete offer set. | Prefer stable free-play schema and link to current store facts, or maintain the full current catalog from one source. |
| JSON-LD version | docs/index.html:56-60 says softwareVersion 1.0, while project.yml:14-15 is 1.0.1 build 26. | Release pages look stale after each build. | Generate version facts from the release source or remove volatile softwareVersion. |
| Host URLs | docs/index.html:10, :16-22 uses jackwallner.com for canonical and GitHub Pages for images. ASC script source uses GitHub Pages support, marketing, and privacy URLs. | A redirect, missing page, or different canonical host can split indexing and review links. | Choose one canonical host, verify redirects and every localized URL, then use it consistently. |
| Public App Store promise | docs/index.html:499-503 says no real purchases required, which is compatible with optional packs, but it does not mention the optional membership. | The free promise is good; monetization is hidden and inconsistent. | Say optional coin packs and optional DreamCart+ without making payment sound required. |
| ASC localized description | scripts/asc-localized-copy.json:42-44 and its locale variants mention optional coin packs only. | Store users who discover Plus in-app have not been pre-qualified by store copy. | Add a concise, accurate membership paragraph to each locale after native review. |

The requested RevenueCat tracking/data-collection disclosure comparison is not
included here. The address and first-party product-copy inconsistencies above
are separate and should be fixed.

### Website growth recommendations

- Put one clear primary CTA above the fold and keep the App Store URL stable.
- Add a concise DreamCart+ section below the free-loop section:
  three-day trial when eligible, weekly renewal, optional benefits, and
  manage/cancel through Apple.
- Keep the no-merchandise and no-cash-value message prominent. It is a trust
  advantage and helps distinguish the product.
- Add support links for coin delivery pending, Plus restore, trial eligibility,
  and account deletion.
- Use the same five screenshot copies across web and ASC, but do not allow
  the website to claim a version or price that is not generated from the
  current release source.

## 8. Release regression, crash, hang, and deprecated UX audit

### Existing signals

Positive evidence:

- CoinShopView.swift:180-211 and CoinUpsellView.swift:203-223 have explicit
  recovery for suspended StoreKit purchases.
- RemoteImage retries five times and exposes Tap to load after failure:
  DreamCart/Components/RemoteImage.swift:4-91.
- Load errors have retry or dismiss behavior in the shared error banner.
- Checkout has an alert for nil and reason-specific RPC failures:
  CheckoutView.swift:56-63 and :196-220.
- LocalNotificationCoordinator has authorization, denied, disabled, and
  schedule reconciliation states.
- Historical iOS 27 audit reports a successful build, tests, install, and
  smoke test on 2026-08-05.

Risk evidence:

- Analytics.swift:81-97 removes the batch before sending and silently drops it
  on failure. There is no durable queue, retry count, or telemetry-health
  event.
- ShopStore.swift:162-164 ignores refreshMe errors.
- ShopStore.swift:198-212 suppresses daily and spin errors.
- ShopStore.swift:428-433 suppresses redeem errors and does not expose pending
  fulfillment to the user.
- SupabaseClient.swift:122-143 signs out locally when token refresh fails,
  but no explicit session-expired UX event is emitted.
- StoreController.swift:25-38 ignores the RevenueCat logIn callback result.
- StoreController.swift:80-91 has fixed US dollar fallback prices.
- PlusOfferView.swift:146 only cancels the view task. It has no stale
  purchase recovery equivalent to coin flows.
- ios27DreamCart.md:20-22 records concurrency warnings in haptics and an
  unused mutable declaration. No current compiler run was performed in this
  audit, so the warning status is not revalidated.
- A search found no @available deprecated declarations or explicit deprecated
  API use. That is not proof that the current SDK build is warning-free.

### Production release-watchdog signals

Implement the following as a configurable, read-only monitor. Thresholds
should live in a local config file or environment variables and notifications
should be scaffolded, not deployed by this audit.

App Store and device signals:

- Crash-free users and crash-free sessions by marketing version, build, device,
  and OS version.
- New crash signatures appearing after a build goes live.
- Crash count and affected-user count in rolling 1-hour, 6-hour, and 24-hour
  windows compared with the preceding release baseline.
- App launch hangs, watchdog terminations, and launch-to-ready latency.
- MetricKit crash diagnostics and hang diagnostics if the app adds a
  MetricKit collector.
- App Store version/build mismatch, missing valid build, missing screenshot,
  and missing review submission.

Purchase and trial signals:

- plus_offer_shown with no plus_purchase_started after a configurable window.
- plus_purchase_started with no trial or initial purchase confirmation.
- Apple purchase success with no active is_plus after a bounded reconcile
  window.
- Restore started with no result, restore error rate, and restore latency.
- Coin purchase success with no balance grant after 30 seconds, 5 minutes,
  and next launch.
- Purchase sheets or local buying state stuck for more than 30 seconds.
- Price missing, product unavailable, or fallback price displayed on a
  release build.
- Product ID in the client not found in ASC, RevenueCat, StoreKit, webhook,
  or redeem maps.

Core-loop and degraded UX signals:

- Root splash visible beyond 5 seconds and beyond 15 seconds.
- Catalog load failure, partial catalog retry failure, and empty active
  catalog.
- Daily claim or spin RPC error rate and nil-result rate.
- Product image 429, 5xx, timeout, decode failure, and retry exhaustion.
- Checkout started with no completed or failed result.
- Unboxing shown with no completion or skip event.
- Notification permission prompt result and notification-open rate.
- Analytics batch send failures, dropped-batch count, queue age, and queue
  depth.
- Sign-in start, cancel, failure, and successful exchange.

Backend and RevenueCat operational signals:

- rc-webhook non-2xx responses, malformed events, missing app_user_id,
  unknown product IDs, unknown event types, and failed set_plus or
  grant_coin_pack RPCs.
- redeem lookup failures, RC API latency, RC 4xx/5xx rate, and unmatched
  product mappings.
- Active entitlement count that does not agree with profiles.is_plus after a
  configured delay.
- render-avatar latency, Pollinations 429/5xx, and cache-hit rate.
- Supabase RPC 4xx/5xx and p95 latency for me, claim_daily, spin,
  purchase_cart, and redeem.

Release comparison:

- Capture a baseline for the previous stable build.
- Compare each new build at 1 hour, 6 hours, 24 hours, and 72 hours.
- Alert on both absolute thresholds and relative increases. A small app can
  have a severe regression with only a few users, so show affected-user
  count and raw event count together.
- Include a release annotation with commit, marketing version, build, ASC
  submission date, and feature flags.

### Crash reporting recommendation

The simplest scaffold is a small MetricKit collector plus a local or
server-side polling script. The collector should:

1. Register once at app launch.
2. Persist crash and hang diagnostic summaries with build and OS metadata.
3. Send them when the next launch is healthy, with a bounded retry queue.
4. Avoid blocking launch or exposing diagnostics to the user.
5. Emit a separate health heartbeat so a missing report source is visible.

If App Store Connect Organizer or ASC API crash data is the chosen source,
keep the script read-only and do not confuse delayed Apple processing with a
zero-crash result. The notification scaffold can send an email, but this
audit does not configure credentials or deploy alerts.

## 9. Concrete non-AI scanner rules

The future fleet scanner should produce machine-readable findings with app,
rule ID, severity, path, line, observed value, expected value, and a suggested
fix. It should never silently turn unavailable live data into zero.

### Metadata and ASC rules

1. Parse scripts/asc-localize-metadata.py and
   scripts/asc-localized-copy.json. Assert the locale set is identical,
   names and subtitles are 1 to 30 characters, keywords are 1 to 100,
   promotional text is 0 to 170, and descriptions are 0 to 4000.
2. Also enforce local fleet targets of name >=24, subtitle >=24, and keywords
   >=94, but label a target miss as a recommendation rather than an Apple
   blocker.
3. Reject name and subtitle price strings and currency symbols.
4. Count each field using Unicode-aware character counts and report code
   points plus grapheme count for non-ASCII locales.
5. Require privacy, support, and marketing URLs in every locale and verify
   local URL files and live HTTP status separately.
6. Parse the StoreKit file and ASC setup scripts. If a recurring subscription
   exists, require subscription localization, group localization, trial
   duration, subscription period, renewal copy, and an explicit audit result.
7. Compare live ASC product IDs against Config.swift, DreamCart.storekit,
   asc-iap-localizations.json, asc-setup-plus-subscription.py,
   rc-webhook/index.ts, and redeem/index.ts.
8. Require one current build attached to the editable version, the expected
   screenshot display set, complete screenshot assets, review notes, and an
   intended review submission. Never mutate ASC from the audit command.
9. Check screenshot dimensions, RGB or RGBA policy, alpha policy, file order,
   duplicate SHA-256, stale display types, and missing public preview assets.
10. Compare current project marketing version and build with website
    JSON-LD softwareVersion and release documents.

### Website, terms, and support rules

1. Parse docs/index.html, privacy-policy.html, terms.html, and support.html.
2. If a recurring StoreKit product exists, fail on phrases such as no
   subscription, no paid tier, or no subscription and report the exact line.
3. Require a subscription support section with trial, weekly renewal,
   cancellation, restore, manage subscription, and Apple billing guidance.
4. Require all public pages to agree on whether a fictional address is stored
   locally. Exclude the RevenueCat tracking disclosure comparison by design.
5. Extract App Store URLs, canonical URLs, policy URLs, and screenshot URLs;
   detect mixed canonical hosts and missing local targets.
6. Detect stale version strings, stale dates older than the current release,
   and stale handoff claims such as a completed build number.

### Swift and flow rules

1. Find every purchase start event and require a success, explicit failure,
   cancellation, or pending fulfillment event in the same flow.
2. Find every async UI action that catches with try? and returns nil. Require
   either a user-facing retry/error state or an intentional telemetry event.
3. Find every paywall and upsell impression. Require stable paywall ID,
   source, variant, price state, eligibility state, soft exit, and legal links.
4. Find every StoreKit purchase await. Require cancellation and stale-state
   recovery, including subscription paths.
5. Find every RevenueCat configure or logIn call. Require observable
   completion or error and a customer identity check.
6. Find every hardcoded price. Permit only test fixtures and require a
   localized StoreKit value before showing a purchasable CTA in release.
7. Detect @available deprecation diagnostics, Swift concurrency warnings,
   force unwraps in remote or legal URL setup, and compiler warning output.
8. Require stable accessibility identifiers for purchase CTA, Restore,
   Terms, Privacy, Close, and error retry controls.
9. Require review funnel code or an explicit documented decision not to ask.
10. Detect source files referenced in active docs but absent from the
    repository, and source surfaces no longer referenced by any route.

### Runtime watchdog rules

1. Startup heartbeat: emit launch_started, auth_ready, catalog_ready, and
   first_value_completed with elapsed milliseconds.
2. Purchase watchdog: alert on started without terminal result past the
   configured timeout.
3. Membership watchdog: alert on Apple success without entitlement or profile
   activation after the configured reconcile window.
4. Fulfillment watchdog: alert on coin purchase success without a balance
   delta, with an idempotent transaction ID.
5. Core-loop watchdog: alert on daily claim or spin nil/error result and on
   checkout started without result.
6. Asset watchdog: alert on image retry exhaustion and sustained 429 or 5xx
   rate.
7. Release watchdog: compare crash, hang, startup, purchase, and RPC error
   rates by version and build against the prior stable baseline.
8. Data health watchdog: alert when analytics flush drops a batch, but never
   block the user or treat missing telemetry as a product failure by itself.

## 10. Agent workspace and documentation hygiene

### Current documentation inventory

| Path | Current classification | Action for implementation agent |
|---|---|---|
| CLAUDE.md | Active app guide | Keep as app-specific source of truth, update the current Plus flow, live ASC submission state, version 1.0.1 build 26, and the current test/release recipe. |
| README.md | Missing | Add a short repository entry point with product truth, setup, test, ASC read-only audit, and document map. |
| AGENTS.md | Missing in repo | Add one canonical repository agent guide, or explicitly state that the global guide is authoritative. Do not create conflicting copies. |
| .cursor rules | Missing | Add only Cursor-specific adapter rules after the canonical guide exists. Do not duplicate product facts. |
| HANDOFF-P0.md | Completed handoff at root | Move to docs/archive with date and status. Its historical test destination and six-test claim must not be read as current release proof. |
| HANDOFF-UX.md | Completed handoff at root | Move to docs/archive. Update or remove references to files no longer present. |
| HANDOFF-DESIGN.md | Completed handoff at root | Move to docs/archive or docs/design/archive. Keep screenshots as historical evidence, not active instructions. |
| ios27DreamCart.md | Dated compatibility audit | Keep the warning as historical evidence, then move to docs/archive after a current Swift 6/Xcode recheck. |
| archive/README.md | Archive index | Keep and expand with dates, current status, and links to active docs. |
| archive/sim76.md | Historical simulator audit | Keep archived. It is useful evidence, not a current app contract. |
| docs/analytics-privacy.md | Active but stale in places | Keep, update event list and user ID semantics. Its claim that pre-auth events are not later linked conflicts with Analytics.swift:85-93, which backfills IDs. |
| docs/astro-aso-setup.md | ASO setup note | Update the temporary Astro app/version references or move to archive after revalidation. |
| docs/index.html, privacy-policy.html, terms.html, support.html | Public active pages | Update together from one product facts checklist, then verify all links and dates. |
| sim77-design/ | Historical design evidence | Move under docs/design/archive or clearly label as historical. Keep only a small current reference set active. |
| DreamCart/Views/OnboardingCoinOfferView.swift | Orphaned legacy surface | Confirm no route or target uses it, then remove or move out of active source. Its old analytics names could confuse scanners and agents. |

### Stale or contradictory agent facts

- Root RootView comments correctly describe the new Plus flow, but the
  orphaned OnboardingCoinOfferView.swift still describes the old coin-pack
  onboarding offer.
- AuthController.swift:29-34 says the flag decides whether to show the
  onboarding coin pack offer, while RootView now shows PlusOfferView. This
  stale comment should be corrected.
- supabase/functions/redeem/index.ts:115 says Plus may be added in the future,
  even though it is active.
- HANDOFF-P0.md and HANDOFF-UX.md say six tests passed and describe earlier
  simulator runs. They do not establish the current build or current
  subscription behavior.
- HANDOFF-DESIGN.md references CompositeAvatarView.swift and
  OutfitBuilderView.swift. Those paths were not present in the current
  repository file list, so an agent may waste time editing nonexistent files.
- docs/analytics-privacy.md says pre-auth events are not later linked, but
  Analytics.swift backfills nil user IDs when a signed-in user exists.
- The handoff references build 7 while project.yml now says marketing version
  1.0.1 and build 26.

### Canonical Cursor, Claude, and Codex layout

Recommended future layout:

    AGENTS.md
    CLAUDE.md
    README.md
    .cursor/rules/00-repo-agent.md
    docs/active/product-facts.md
    docs/active/release.md
    docs/active/analytics-and-funnel.md
    docs/decisions/
    docs/design/current/
    docs/archive/
    scripts/

Rules for this layout:

- AGENTS.md owns repository-wide operating rules and the canonical product
  facts link.
- CLAUDE.md is either a symlink to AGENTS.md or a short Claude-specific
  adapter. It must not contain a second product contract.
- Cursor rules contain only Cursor-specific behavior or tool conventions.
- README.md is the human and agent entry point, not a historical handoff.
- Active docs describe the current release and link to the canonical facts.
- Every archive document begins with status, date, superseded-by, and whether
  it is safe for an implementation agent to follow.
- Handoffs are moved out of the repository root after completion.
- Product IDs, version, prices, trial terms, public URLs, and legal claims
  should have one source or a scanner-enforced consistency check.

## 11. Implementation handoff by workstream

### Release and truthfulness

1. Inspect the ASC submission state and create the intended review submission.
2. Update docs/index.html, support.html, terms.html, privacy context,
   localized metadata descriptions, and review notes from one Plus facts
   sheet.
3. Reconcile canonical website host and all ASC URLs.
4. Rerun the read-only ASC audit and save its output outside the repository
   or in a dated release record only if the implementation agent is
   authorized to add that record.

### Trial and paywall

1. Add explicit product loading, unavailable, price missing, eligible, and
   ineligible states.
2. Add stale purchase recovery for Plus.
3. Reconcile or poll membership after purchase and show pending status until
   profiles.is_plus is confirmed, with a timeout and support path.
4. Add trial-start, paid-start, restore, failure, and pending events.
5. Test current immediate offer against a post-first-value offer.
6. Add stable accessibility IDs and Dynamic Type, RTL, and legal-copy UI
   coverage.

### Free loop and conversion

1. Add visible failure and retry for daily claim and spin.
2. Add first-value and return-to-intent events.
3. Measure guest browsing to sign-in and each account gate by feature.
4. Test the insufficient-balance and post-spin upsells with balance and cart
   buckets.

### Reviews and retention

1. Add a satisfaction gate and native review request after a positive success.
2. Add Profile Rate DreamCart and Send feedback rows.
3. Add notification permission, schedule, denial, and open events.
4. Test notification copy and timing against daily drop behavior.

### Reliability and watchdog

1. Add MetricKit or an approved crash diagnostic source.
2. Add startup, purchase, fulfillment, RPC, image, and analytics health
   signals.
3. Add a read-only ASC and backend polling scaffold with configurable
   thresholds and email output disabled by default.
4. Add a release comparison report keyed by version, build, commit, and
   feature flags.

### Agent hygiene

1. Move completed handoffs and design captures to dated archive locations.
2. Correct stale comments and missing path references.
3. Add README, canonical AGENTS, and Cursor adapter structure.
4. Add a generated document map or scanner check so every active doc has an
   owner, date, and supersession state.

## 12. Validation matrix

The implementation agent should validate each change with a test that proves
the user-visible result, not only a static grep.

| Area | Validation |
|---|---|
| ASC release | Run scripts/asc-release-audit.py read-only. Confirm exactly one intended review submission, valid attached build, complete screenshots, five IAPs, Plus subscription state, and no metadata blocker. |
| Metadata | Run scripts/asc-localize-metadata.py --validate-only. Print locale count and exact min/max character counts. Add subscription-copy checks. |
| Website | Parse all local links, fetch canonical and GitHub Pages URLs in a read-only check, compare App Store ID, version, prices, Plus claims, support date, and legal links. |
| Onboarding | Fresh signed-out install: complete all three pages, test Apple sign-in error/cancel, test guest browse, test account gate, test catalog failure and retry. |
| First value | Signed-in test account: claim daily coins, spin, browse, add to cart, checkout, unbox. Simulate claim and spin RPC failure and verify visible retry. |
| Plus trial | StoreKit test scheme: eligible trial, ineligible subscriber, price loading, product unavailable, purchase cancel, suspended purchase recovery, successful purchase, delayed webhook, restore success, restore empty, and restore error. |
| Coin purchase | Device or TestFlight: all five packs, localized price, Apple sheet cancel, suspended sheet, delayed fulfillment, duplicate reconciliation, and insufficient balance upsell. |
| Backend | Send fixture webhook events for each supported product and lifecycle type. Verify idempotent grant, explicit Plus entitlement, unknown user, unknown product, RPC failure, and retry/observability. |
| Ratings | Test positive and negative preprompt branches, cooldown, version cap, and native request attempt without assuming a system sheet. |
| Accessibility | VoiceOver focus order, Dynamic Type XXL, RTL, reduced motion, high contrast, paywall links, checkout address choice, tab bar, and error retry. |
| Release regression | Run current unit and UI suites under the required headless simulator workflow, capture compiler warnings, and compare launch and purchase watchdog outputs with the previous stable build. |
| Documentation | Run the stale-doc scanner. It must flag the no-subscription website claim, build 7 handoff, stale Plus comments, missing referenced source paths, and analytics privacy mismatch until fixed. |

## 13. Scope limits and unknowns

- No live download, revenue, trial, rating, crash, or conversion metric was
  available, so prioritization uses product flow, code evidence, and
  release-risk inference.
- The ASC audit was run read-only and supplied release-state evidence only.
- RevenueCat dashboard or customer-level data was not queried.
- No current build or simulator run was performed by this audit worker because
  the worker was instructed to modify only audit823.md. Historical test
  results are labeled as historical, not current verification.
- Runtime network latency, webhook delivery latency, Apple purchase behavior,
  and real localized rendering still need the validation matrix above.
- RevenueCat tracking and data-collection disclosure inconsistencies are
  explicitly excluded as requested.

## Bottom line for the implementation agent

Treat the current app as a polished free virtual-shopping loop with a newly
introduced subscription whose public truth has not caught up. Clear the ASC
submission blocker, synchronize every public and agent-facing product fact,
make Plus activation and free-reward errors observable and recoverable, add
structured trial and fulfillment signals, and install a release watchdog
before optimizing copy or price. The local metadata and core visual assets
are already strong enough to support controlled growth experiments once those
trust and reliability gaps are closed.
