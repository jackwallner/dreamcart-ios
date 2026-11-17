# DreamCart pre-submit review, deep pass (2026-11-08)

Scope: every user-reachable path on `origin/main` (6623bb3, 1.0.5 build 51), with
extra attention to the app changes since the live 1.0.4 (last 1.0.4 commit
cf8e449, build 48): the localization pass, `DisplayFormat`, `PluralLabel`, the
Language row and `CoinPack.Badge`. Areas read: purchase and restore
(`StoreController`, `PurchaseRecovery`, `PlusOfferView`, `CoinShopView`,
`CoinUpsellView`), onboarding and auth (`WelcomeView`, `RootView`,
`AuthController`, `SupabaseClient`), persistence (`ShippingAddressStore`,
notification and appearance defaults), notifications, iPhone Duo panes and
every main tab. The app has no widgets or App Intents.

Clean: no force unwrap on server or saved data, no unbounded index, saved
`ShippingAddress` and `PurchaseRecovery` data still decodes, trial copy follows
`plusTrialEligible`, Restore, Terms and Privacy are on the DreamCart+ offer and
the coin shop, the onboarding offer always has an enabled exit, the tester
sign-in and Duo tour are `#if DEBUG` only, and `check.py` passes (346 keys, 8
languages, 0 problems).

| Severity | Location | What happens | Status |
| --- | --- | --- | --- |
| P1 | DreamCart/DreamCartApp.swift:97 | The daily "NEW DROP" reminder keeps the copy of the language it was scheduled in, and nothing rescheduled it on launch. A shopper who switches language with the new Language row keeps getting reminders in the old language. | Fixed: launch reconciles the reminder (`LocalNotificationCoordinatorTests`). |
| P1 | Shared/Services/ShopStore.swift:395 | If `purchase_cart` commits but its answer is lost, the pieces stay in the cart. The retry finds them owned, the server answers `nothing_to_buy`, and every retry says "Your cart looks empty" over a full cart with stale coins and closet. | Fixed: a lost answer or `nothing_to_buy` reloads the closet and balance and drops owned pieces from the cart (`testCheckoutOfPiecesAlreadyOwnedClearsThemFromTheCart`). |
| P2 | Shared/Services/ShippingAddressStore.swift:10 | The pretend shipping address is device-wide and survives sign-out and account deletion, so the next account on the device sees it. It never leaves the device. | Not fixed: needs a product call on whether a session that ended should also forget it. |
| P2 | Shared/Services/ShopStore.swift:125 | A refresh replaces the catalog with its first 200 rows before the rest pages back in. Until then a carted piece past row 200 drops out of the cart list and total while the tab badge still counts it. | Not fixed: the window is one paging request and the server charges only what the shopper carted. |
| P2 | DreamCart/Views/SpinView.swift:99 | Close is disabled mid-spin, but a swipe down still dismisses the sheet. The prize is credited; the reward overlay and post-spin upsell are lost. | Not fixed: no coin loss. |
| P2 | DreamCart/Views/SpinView.swift:94, DreamCart/Views/TodayView.swift:275, :385 | "Resets at midnight" and "Resets tomorrow" mean UTC midnight (server `current_date`), which is afternoon or evening in the Americas. | Not fixed: copy change. |
| P2 | Shared/Services/ShopStore.swift:22 | The cart lives in memory only and empties on relaunch. | Not fixed: long-standing behavior. |
| P2 | DreamCart/AppDelegate.swift:5 | On a cold launch from a reminder tap, the route handler is set from the root view's `.task`; a response delivered before that runs would be dropped and the app opens on Today. Not reproduced. | Not fixed: unverified timing. |
| P2 | Shared/Services/StoreController.swift:122 | Before StoreKit answers, coin packs show US-dollar placeholder prices in every storefront. | Not fixed: documented placeholder, replaced as soon as products load. |
| P2 | DreamCart/Views/ProfileView.swift:486 | Coin history shows raw `YYYY-MM-DD` dates in every language. | Not fixed: cosmetic. |

Tests: `gh-sim test --scheme DreamCart` on the review branch (run id in the
commit that adds this report's result line, or the session report).
