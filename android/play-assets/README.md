# Google Play store assets

Laid out for `~/docs/android/tools/play_stage.py listing`.

| File | What it is |
|---|---|
| `metadata/android/en-US/title.txt` | App name, the live App Store name (28 / 30) |
| `metadata/android/en-US/short_description.txt` | Short description (78 / 80) |
| `metadata/android/en-US/full_description.txt` | Full description (about 1,390 / 4,000), plain text |
| `release-notes.txt` | First release notes, for `play_stage.py release --notes` |
| `icon-512.png` | 512 x 512 app icon |
| `feature-graphic.svg` | Editable source for the feature graphic |
| `feature-graphic.png` | 1024 x 500 RGB feature graphic, no alpha |
| `screenshots/01-*.png` to `06-*.png` | Six 1080 x 2160 (2:1) RGB phone screenshots |

## How they were made (2026-10-21)

**Metadata.** Moved unchanged from the old `listing/` folder (Play's file
names use underscores). No prices, no em dashes, and coins are described as
having no cash value.

**Icon.** The existing 512 x 512 export of the app icon, kept as is.

**Feature graphic.** `feature-graphic.svg` uses the app icon's art: its violet
(`#7c3aed`) as a flat field, the white bag with the gold, pink and violet
sparkles drawn as vectors, and a pink and coral band from the icon's lower
corner. Text is live (serif wordmark like the app's headings), so edit it in
the SVG. Rendered with headless Chrome at 1024 x 500, then flattened to RGB
with Pillow.

**Screenshots.** Real screens from a debug build (`assembleDebug`, Test Store
key only, no production RevenueCat key) on the `agent-emu-1` AVD (API 36) on
jmbp, signed in as the debug tester account with live catalog data and
product art from Supabase storage:

```sh
adb shell am start -n com.jackwallner.shop/.MainActivity \
  --ez onboarded true --ez tester true --es appearance light
```

`--ez screenshot true` was not used: it swaps product art for placeholder
gradients. The device was set to `wm size 1080x2160` with animator scales 0
and SystemUI demo mode (clock 9:41, full Wi-Fi and battery, no mobile icon, no
notifications). Each screen was reached by tapping through the app:

1. Today tab after the daily claim
2. Today > Shop all, the full catalog grid
3. For You, a pearl choker card
4. Product page for the Cascade Ruby Strappy Heels
5. Cart > Check out with three pieces, after "Skip for now"
6. Closet after placing that order, showing the new haul

Gotchas: the app surface went black right after `wm size 1080x2160`; a
force-stop and relaunch at that size rendered normally. The tester account is
shared with connected tests, so its coin balance, spin state and closet
change between runs.
