# State machine audit, 2026-11-24

Scope: the DreamCart iOS app (`DreamCart/`, `Shared/`). No widgets, Watch app, App Intents or notification extension; the one scheduled notification is the repeating "NEW DROP" reminder. Coins, the daily claim, the wheel and checkout are server RPCs (Supabase), so the client holds a snapshot (`MeSnapshot`) and no local money ledger. Android is out of scope. Audited from commit `134b8be` with no app code changed.

**Summary: 1 bug proved by a failing test, 2 code paths not proved.** Plus 6 product calls (not counted).

Evidence run: `gh-sim test --scheme DreamCart --only DreamCartTests/StateMachineAuditRepro` on the audited commit plus the repro file, run id in the Phase 2 section below. The repro suite is `state-machines-2026-11-24-repro.swift` beside this file (copy it into `DreamCartTests/` to run it). No build settings or secrets are needed; the simulator never configures RevenueCat (`StoreController.configure`, `targetEnvironment(simulator)` returns early).

Test seams used: `LocalNotificationCenter` (protocol, `Shared/Services/LocalNotificationCoordinator.swift:9`) with a fake center and a suite `UserDefaults`. Seams that do not exist: the views (`DreamCart/`) are not compiled into the unit-test bundle (only `Shared/` is, `project.yml` DreamCartTests sources), and RevenueCat is not injected into `StoreController`. That is why the purchase-surface claims below stay code paths.

## Bugs ranked by impact

| ID | Bug | What the user sees | Promise | User route | Impact | Evidence | file:line |
|---|---|---|---|---|---|---|---|
| B1 | Reminders the shopper turned on are switched off for good the first time iOS permission is off, and never return when it is allowed again | The daily "NEW DROP" reminder stops. Profile first says "Notifications are off in Settings" with an "Allow notifications in Settings" button; after following it and allowing notifications, the toggle reads Off and no reminder is ever scheduled until the shopper finds the toggle and turns it on again. | `ProfileView.swift:310-311`: the "Allow notifications in Settings" button offered while denied. `ProfileView.swift:322`: "One reminder daily at %@" while on. `NotificationPrimerView.swift:18`: "you can change this anytime in Profile." Fleet rule: never clear a stored setting because of an inferred state. | You tab, New drop reminders on (permission allowed). iOS Settings, DreamCart, Notifications off. Return to DreamCart (`DreamCartApp.swift:119` calls `refreshStatus()` on every `.active`, which writes `notifications.enabled = false`, `LocalNotificationCoordinator.swift:140-145`). Tap "Allow notifications in Settings", allow, return. Toggle Off, nothing pending. | Every shopper who turned reminders on and later switched DreamCart's notifications off in iOS Settings, even briefly (Focus setup, a notification clean-up). The reminder is the app's only re-engagement channel, so the loss is silent and permanent. Low frequency, high cost per hit. | Test `testRemindersComeBackWhenPermissionIsAllowedAgain` fails at `isNotificationsEnabled` ("the reminder toggle the shopper turned on must be on again once iOS allows it"). Preconditions asserted: reminder on and scheduled, the app saw denied, then saw authorized. Control `testControlRemindersTurnedOffInTheAppStayOff` passes. | `LocalNotificationCoordinator.swift:140-145` (`refreshStatus` clears the wish), `:167-171` (`disable`), `DreamCartApp.swift:119` |
| C1 | (Code path, not proved) The shared purchase error line follows the shopper to the other purchase screen | After a failed Restore in the DreamCart+ sheet ("No previous DreamCart+ membership on this Apple Account."), opening Get Coins from the wallet pill shows that line above the coin packs. The reverse also happens: "Purchase didn't complete. You weren't charged." from Get Coins shows up under the DreamCart+ perks before anything was tapped. | `CoinUpsellView.swift:76` clears `store.lastError` on appear, the intended lifecycle; `PlusOfferView` and `CoinShopView` never clear it, so the copy describes an action the shopper did not take on that screen. | You tab, DreamCart+, Restore (no membership), Maybe later, wallet pill, Get Coins. | Every shopper who taps Restore without a membership and then opens Get Coins in the same session; and anyone whose coin purchase fails and then opens DreamCart+. | Not run: the views are not in the unit-test bundle and `StoreController` has no seam for a RevenueCat result. | `StoreController.swift:19`, `PlusOfferView.swift:93,326`, `CoinShopView.swift:26,237` |
| C2 | (Code path, not proved) A purchase that is still settling when the shopper returns from Apple's sheet can be declared "You weren't charged" | The coin shop's stale-spinner guard fires 2.5 s after `.active` if the purchase has not returned, shows "Purchase didn't complete. You weren't charged.", and cancels the task. If RevenueCat then finishes, `buy` records the pending delivery but `reconcile` exits on the cancelled task (`PurchaseRecovery.swift:74` `Task.checkCancellation()`), so the coins wait for the next foreground. | The copy "You weren't charged" (`CoinShopView.swift:237`, `CoinUpsellView.swift:220`). | Get Coins, buy a pack, confirm, return while RevenueCat's post-purchase receipt call is slow. | Slow networks only; the pending delivery is persisted, so no coins are lost, but the copy is wrong for that session. | Not run: needs a RevenueCat purchase that resolves after a delay, which no seam provides. | `CoinShopView.swift:228-249`, `CoinUpsellView.swift:212-230` |

## Product calls (not counted: documented, or no cited promise)

1. The daily claim and the wheel follow the server's UTC day (`ShopStore.todayUTC`, `MeSnapshot.liveStreak`). A US shopper's "Come back tomorrow" turns over at 4 or 5 PM local time. Documented in `Models.swift` (`liveStreak`).
2. A shopper who keeps DreamCart on screen across the UTC day boundary keeps seeing "Daily claimed" until they background the app or pull to refresh: `me` is refreshed on `.active` (through `reconcilePurchases`) and on pull to refresh, not on a clock.
3. The cart is in memory only (`ShopStore.cartIds`); a relaunch empties it. No copy promises a saved cart.
4. The fake-checkout shipping address is device-local and not keyed by account (`ShippingAddressStore`), so it survives sign-out and Delete account. The privacy policy says it "is stored locally for the simulated checkout"; account deletion promises backend data only.
5. An Ask to Buy approved later unlocks on the next foreground (`DreamCartApp.swift:122`, `reconcilePurchases` refreshes `is_plus` and the balance), not while the app stays on screen. There is no RevenueCat delegate; membership is the server's `profiles.is_plus`, by design (`StoreController.purchasePlus` doc comment).
6. `OnboardingCoinOfferView` is no longer constructed anywhere (RootView shows `PlusOfferView`); it is dead code.

## State machines

### SM1. Reminder (`LocalNotificationCoordinator`)

State: stored `notifications.enabled` (the shopper's wish), `notifications.primerShown`, `notifications.preferredMinuteOfDay`, in-memory `authorizationState`, and the one pending request `dreamcart.new-drops` (repeating calendar trigger, floating local time).

Invariants: N1 a request is pending only while wish and permission are both on; N2 the request carries the current language and time (rebuilt on launch); N3 the wish changes only by the shopper's own action (toggle, primer); N4 permission allowed again restores what the wish says.

| From | Event | To | Invariant |
|---|---|---|---|
| no permission asked | primer Turn on, allowed | wish on, scheduled | N1 |
| no permission asked | primer Turn on, denied | wish off | N3 (the shopper's answer) |
| wish on, scheduled | Profile toggle off | wish off, removed | N1 |
| wish on, scheduled | reminder time changed | rescheduled at the new time | N2 |
| wish on, scheduled | launch | rebuilt in the current language | N2 |
| wish on, scheduled | permission off in iOS Settings, return | **wish cleared** (B1); request removed at the next launch | N3 broken |
| wish cleared by B1 | permission on again, return | **stays off, nothing scheduled** (B1) | N4 broken |

Time zone and DST: the trigger is hour and minute without a time zone, so it fires at the chosen local time after travel. Fine.

### SM2. Account and session (`AuthController`, `ShopStore`, `PurchaseRecovery`)

States: unknown, signedOut, guest, signedIn. Storage: Keychain session, `dreamcart.browsingAsGuest`, per-account `purchaseRecovery.<id>`.

Invariants: A1 the store never shows the last account's balance, closet or cart to the next one (`forgetAccount`, covered by `AccountStateTests`); A2 pending purchase recovery is per account and survives relaunch; A3 a server-ended session lands on Welcome with a reason.

| From | Event | To | Invariant |
|---|---|---|---|
| unknown | bootstrap, session | signedIn, recovery selects account, RevenueCat logs in | A2 |
| unknown | bootstrap, guest flag | guest, catalog only | A1 |
| signedIn | sign out, delete, `supabaseSessionEnded` | signedOut, `forgetAccount`, recovery deselected | A1, A3 |
| guest | sign in | signedIn, guest flag cleared for good | A1 |

No invalid transition found.

### SM3. Purchase and recovery (`StoreController`, `PurchaseRecovery`, the three purchase screens)

State: `isPurchasing`, shared `lastError`, `plusTrialEligible`, per screen `buying` and `buyTask`, persisted `PendingCoinDelivery` and `plus` per account, `confirmedPlus`, `lastDeliveredCoins`.

Invariants: P1 a purchase Apple completed is persisted before any network call that could fail (`beginCoins`, `beginPlus`); P2 delivery is confirmed by a ledger row after the pre-purchase boundary, not by a balance change; P3 the button never stays spinning (stale guard); P4 an error line belongs to the screen that raised it (C1); P5 a pending Ask to Buy is not an error (Rollout A, same date).

| From | Event | To | Invariant |
|---|---|---|---|
| idle | buy pack, Apple ok | pending coins persisted, reconcile | P1 |
| pending coins | ledger row found | delivered, "Coins added" | P2 |
| pending coins | redeem or network fails 3 times | pending kept, Retry delivery shown | P1 |
| buying | Apple sheet dismissed, purchase never returns | after 2.5 s: idle, "You weren't charged" | P3 (C2 on a slow settle) |
| buying | `paymentPendingError` (Ask to Buy) | idle, RevenueCat's English description in pink | P5 broken (fixed by Rollout A) |
| any screen with an error | open the other purchase screen | error shown there | P4 broken (C1) |
| pending plus | `is_plus` true on refresh | confirmed, "DreamCart+ unlocked" | none |

### SM4. Daily claim, wheel, streak (server, `MeSnapshot`)

State lives on the server (`claim_daily`, `spin`, `me`); the client reads `canClaimDaily`, `canSpin`, `streak`, `lastDailyClaim`. `liveStreak` hides a streak the next claim would reset (covered by `StreakTests`). `canSpin` lifts the daily limit for members (`SpinAvailabilityTests`). Day turnover follows UTC (product calls 1 and 2). No invalid client transition found.

### SM5. Cart and checkout (`ShopStore`)

Invariants: K1 a lost checkout answer does not leave owned pieces in the cart (`syncCartWithCloset`); K2 an order of only owned pieces clears them instead of failing every retry; K3 Place order is disabled while placing (`CheckoutView.placing`). Covered by `ShopStoreNetworkTests`. No invalid transition found.

### SM6. Onboarding

`AuthController.justCompletedOnboarding` (in memory) shows the DreamCart+ offer once after the first sign-in; `onDone` clears it. A relaunch never shows it again. Out of scope for changes (onboarding order and paywall timing are Jack's).

## Phase 2, skeptical self-review

- B1 survives. The route uses only shipping UI (the Profile toggle, iOS Settings, the in-app "Allow notifications in Settings" button), and the test drives the same coordinator calls the app makes on `.active`. The control shows the harness distinguishes a shopper's own Off from a permission change. The fix must keep `testReconcileLeavesNoReminderWhenPermissionWasRevoked` (nothing scheduled while denied).
- C1 stays a code path: the route is reachable in production, but no headless test can host the views. Not counted. Rollout A (same date) has to give the purchase screens a message lifecycle anyway (the pending notice clears when the screen closes), so the same close also clears the error line; recorded in the rollout doc, not as an audit fix.
- C2 stays a code path and is not fixed: it needs a delayed RevenueCat purchase to prove, and the pending delivery is already persisted, so no coins are lost.
- Dropped: none.

Run: see `state-machines-2026-11-24-fixes.md` for the run id and per-test result on the audited commit.
