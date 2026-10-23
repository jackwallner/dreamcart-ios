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
  enabled with that client id. Supabase showed `google: true` on 2026-10-21 and
  the Air's `~/shop/android/local.properties` has the client id (2026-10-23).
  Debug builds without it hide the button and let guests browse; release builds
  fail `validateReleaseConfiguration` without it. This is
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

## Play store assets

`android/play-assets/` holds the listing in `play_stage.py` layout; its README
records how each asset was made. On agent-emu-1 at `wm size 1080x2160` the
app drew black until force-stopped and relaunched. Don't use `--ez screenshot
true` for store captures: it replaces product art with placeholder gradients.

## Release packaging (signed builds stay on the Air)

`fm-gradle` strips `local.properties` and keystores, so it cannot sign. The upload
key `~/.android/keystores/shop-upload.p12` (alias `upload`, backup byte-identical in
`backups/`) and the production `local.properties` live only on the Air, where the
Gradle guard allows signed release builds:

```sh
cp ~/shop/android/local.properties android/   # in a worktree
cd android && JAVA_HOME=/Library/Java/JavaVirtualMachines/temurin-17.jdk/Contents/Home \
  ANDROID_HOME=~/Library/Android/sdk ./gradlew --no-daemon :app:assembleRelease :app:bundleRelease
```

Upload cert SHA-256 `b012f32c5d2ab62af0555adac1200407fd0e35f7976b42035e5ad32927d57fab`,
SHA-1 `7a7d2528eb9a9ab21aec87b0fb27d93395dd712e` (the Android OAuth client for
internal testing needs this SHA-1; production needs Play's app-signing SHA-1).

## Play state (2026-10-23)

Signed 1.0.0 (versionCode 1) built from android tree `668da02` (`origin/main`
`8a6a16c`) by package run `shift-android-package-shop-2-1792784441`:
`~/fleet-artifacts/shift-android-package-shop-2-1792784441/dreamcart-1.0.0-vc1.{apk,aab}`.
apksigner, jarsigner, zipalign `-P 16`, ELF 16 KB (8 libs) and the release-hook
scan pass; evidence in `~/fleet-evidence/shift-android-package-shop-2-1792784441/`.

Not uploaded. No Play track for `com.jackwallner.shop` in the fleet track cache;
Play app record, products and the internal track are still to do (Air release
worker or Jack). `rc-webhook` with `:basePlan` stripping must be deployed before
any Play purchase. Steps are in `project-docs/android/play-release-prep.md`.
