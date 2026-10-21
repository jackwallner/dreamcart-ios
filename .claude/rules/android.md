---
paths:
  - "android/**"
---

# DreamCart Android

Native Kotlin/Compose port in `android/`, screen for screen with iOS. Same
Supabase project, RPCs and RLS; same RevenueCat project (`proj2a25c871`).

## Identity

- Package and namespace `com.jackwallner.shop` (permanent once uploaded).
  Listing name `DreamCart: Dopamine Shopping`. minSdk 26, target/compile 36.
- Products (same ids as iOS): consumables `com.jackwallner.shop.coins.{pocket,bag,haul,spree,vault}`
  (1000/3200/8500/20000/60000 coins); subscription `com.jackwallner.shop.plus.weekly`
  with base plan `weekly` and a 3-day free-trial offer. RevenueCat names the Play
  subscription `com.jackwallner.shop.plus.weekly:weekly`; `rc-webhook` strips the
  `:basePlan` suffix (committed 2026-10-20, **not deployed yet**).
- No client-side entitlement gate: coins and `profiles.is_plus` are granted
  server-side (redeem function and webhook), exactly as on iOS.

## Deliberate differences from iOS

- **Sign-in**: Sign in with Apple has no Android equivalent. The app uses Sign in
  with Google through Credential Manager (`data/GoogleSignIn.kt`, Supabase
  `grant_type=id_token`, provider `google`, hashed nonce). It needs
  `GOOGLE_WEB_CLIENT_ID` in `local.properties`, and the Supabase Google provider
  enabled with that client id. Neither exists yet (Supabase `/auth/v1/settings`
  showed `google: false` on 2026-10-20). Until then the button is hidden, guests
  can browse, and release builds fail `validateReleaseConfiguration`. This is
  Jack's decision; do not invent another provider.
- Spin card: a DreamCart+ member keeps "Spin the wheel" after spinning (the
  server allows unlimited member spins). iOS hides it after one spin.
- Reminders: one inexact daily alarm at 9:00 AM (no time picker yet), no
  exact-alarm permission.
- Settings "Rate DreamCart" opens the Play listing; "Send feedback" opens a mail
  draft. No in-app review prompt yet (Google forbids a sentiment gate).
- Debug builds send no analytics rows; release sends the iOS events to
  `analytics_events` with `props.platform = "android"`.

## Build and test (fm-gradle, never on the Air)

```sh
cd android
fm-gradle :app:testDebugUnitTest :app:assembleDebug :app:lintDebug -Pkotlin.compiler.execution.strategy=in-process
ANDROID_SERIAL=emulator-5554 fm-gradle :app:connectedDebugAndroidTest -Pkotlin.compiler.execution.strategy=in-process
```

- `local.properties` (ignored): `sdk.dir`, `REVENUECAT_TEST_KEY` (the Test Store
  app `appa8bd3dce4f` public key, readable with the shop RC secret),
  `REVENUECAT_PLAY_KEY`, `GOOGLE_WEB_CLIENT_ID`, `PLAY_UPLOAD_*`.
- JVM parity tests read the wheel table from the newest `spin()` migration and
  the pack table from `redeem` and `rc-webhook`, plus iOS `Config.swift` and
  `SpinView.swift`. Change the server and the Android build fails until the
  client matches.
- Connected tests hit the live Supabase project; signed-in tests use the debug
  tester account (`tester@dreamcart.dev`, same as the iOS DEBUG button).
- Debug launch extras: `--ez onboarded true`, `--ez tester true`, `--ez guest true`,
  `--es appearance dark`, `--ez screenshot true`, `--ez rcProbe true` (Plus button buys
  the Test Store offering's first package).

## jmbp2 emulator notes (2026-10-20)

- agent-emu-1 (API 36 Play image, 2 vCPU, SwiftShader) renders about 1 to 10 fps.
  Stop Gradle daemons (`./gradlew --stop`) before driving it on this 8 GB host;
  with both running the guest's system_server restarted twice.
- After a cold boot telephony and Wi-Fi take a few minutes; wait for
  `dumpsys connectivity` to show an active default network before testing.
- Set animator scales to 0 for automation. The app honours that as Reduce Motion
  (no splash pulse or shimmer loop); with the pulse running the splash starved
  the emulator CPU.
- `pm clear com.jackwallner.shop` returned `Failed` once; reinstalling the APK
  worked.

## Test Store finding (2026-10-20)

A Test Store "valid purchase" of the generic `monthly` package with the debug
tester signed in was followed by `profiles.is_plus = true` on that tester. The
repo's `rc-webhook` ignores `monthly`, so the deployed webhook or another
integration differs. Check the deployed function before Play launch.

## Play state

No Play app record yet (2026-10-20). Steps are in
`project-docs/android/play-release-prep.md`.
