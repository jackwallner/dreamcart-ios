# DreamCart Android: Play release prep

Status on 2026-10-20 (run shift-android-shop-1-1792547202, jmbp2). Engineering
port done and verified on the emulator. Not on Play yet.

Update 2026-10-21 (package run shift-android-package-shop-1-1792574995, Air):
signed packaging is blocked because there is no upload keystore, no
`local.properties` and no RevenueCat Play app. No APK or AAB was built. The
Supabase Google provider is now enabled; the Web client id still has to reach
the Air's `local.properties`. Details are in `.claude/rules/android.md`
under "Release packaging and Play state".

## Decisions Jack needs to make

1. **Android sign-in provider.** iOS uses Sign in with Apple only. Android code is
   ready for Sign in with Google (Credential Manager, hashed nonce, Supabase
   `id_token` exchange). To turn it on:
   - In Google Cloud, create a Web OAuth client id and an Android OAuth client
     for `com.jackwallner.shop` with the Play app-signing SHA-1 (and the upload
     key SHA-1 for internal testing).
   - In Supabase (account `jtest0979`), Authentication > Providers > Google:
     enable, paste the Web client id and secret, and allow the Android client id.
   - Put the Web client id in the Air's `android/local.properties` as
     `GOOGLE_WEB_CLIENT_ID`. Release builds refuse to build without it.
   Without a provider, Android users can only browse as guests, which is not
   shippable.
2. **Deploy `rc-webhook`** with the committed `:basePlan` stripping, or DreamCart+
   bought on Play will never set `is_plus`.
3. **Test Store and `is_plus`.** A Test Store purchase of the generic `monthly`
   package was followed by `is_plus = true` on the tester account. Confirm the
   deployed webhook ignores Test Store events (or reset the tester), so debug
   builds cannot grant membership.

## Play Console steps (after the decisions)

1. Create the app `DreamCart: Dopamine Shopping`, package `com.jackwallner.shop`,
   free, game or shopping category (Jack's call; iOS is Games > Simulation).
2. Upload the signed AAB from the Air to internal testing.
3. Products: five consumable in-app products with the iOS ids, then the
   subscription `com.jackwallner.shop.plus.weekly`, base plan `weekly`
   (auto-renewing, 1 week), offer: 3-day free trial for new customers. Set USD
   prices to match iOS (packs $1.99, $4.99, $9.99, $19.99, $49.99; Plus $0.99/week)
   and review Play's local conversions against the iOS PPP plan.
4. RevenueCat: add a Play Store app to project `proj2a25c871`, attach the Play
   service account (ask Jack first), import the six products, attach the
   subscription to the same entitlement/offering as iOS. Register the Play app
   in rc-clean (`~/.rc-clean/apps.json` on the Air, then copy to the MBP).
   Put the `goog_` key in the Air's `local.properties` as `REVENUECAT_PLAY_KEY`.
5. Listing: `android/play-assets/listing/` (title, short and full description,
   release notes), `android/play-assets/icon-512.png`. Still needed: a 1024 x 500
   feature graphic and composited 1080 x 1920 phone screenshots from
   `--ez screenshot true` captures (status bar in demo mode).
6. App content:
   - Privacy policy: https://jackwallner.github.io/dreamcart/privacy-policy.html.
     Update it before launch: add Google sign-in (email and Google account id
     shared with Supabase), Google Play payments, and "Android" next to Apple.
   - App access: all features reachable after Google sign-in with any account;
     no reviewer credentials needed once Google sign-in is live. Guests can
     browse without signing in.
   - Ads: none. Target audience: 13+ (policy says not directed to under 13).
   - Content rating (IARC): virtual currency purchases, no gambling with real
     money (coins have no cash value; the wheel is free and pays play coins).
   - Data Safety: collected: email address and user id (account), purchase
     history (RevenueCat), app interactions and in-app activity (analytics
     events, closet, favorites), all linked to the account, encrypted in transit,
     deletable in-app (You > Delete account). Shipping address stays on device
     and is not collected. Product images are fetched from Pollinations with no
     user data.
   - Financial features: none. Gambling: none (no real-money wagering).
7. Internal test with a licence tester: buy a pack, confirm coins arrive through
   `redeem`; start the Plus trial, confirm `is_plus` flips and Profile shows
   "Active"; cancel in Play and confirm expiry. Then the pre-launch report.
8. Production: follow the fleet pacing (one new app per production review).

## Verified in this run

- `./gradlew :app:testDebugUnitTest`: 29 JVM tests (parity with server wheel,
  pack grants, iOS catalog and copy; cart, search, ranking, funnel).
- `./gradlew :app:assembleDebug :app:lintDebug :app:assembleDebugAndroidTest`: pass,
  lint 0 errors.
- `connectedDebugAndroidTest` on agent-emu-1 (API 36): 6 tests (first run, guest
  boundary, guest add-to-cart gate, signed-in wallet and coin packs, Plus offer
  disclosure, checkout address gate).
- Manual run on the emulator with the live backend: daily claim, real spin
  (slice 1 landed, 1,500 granted), add to cart, pretend address with keyboard,
  coin checkout (530 coins), closet New haul, For You deck, coin shop, Plus offer,
  Test Store purchase sheet and success, coin history, dark mode.
