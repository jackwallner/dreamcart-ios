---
name: verify
description: Record and inspect DreamCart flows on a leased device from the shared headless agent-sim pool.
---

# DreamCart runtime verification

Lease a device from the shared pool under owner `shop`. Never open Simulator.app.

```bash
xcodegen generate
agent-sim checkout shop
UDID=$(agent-sim udid shop)
agent-sim boot shop
xcodebuild -project DreamCart.xcodeproj -scheme DreamCart -destination "id=$UDID" build
APP=$(find ~/Library/Developer/Xcode/DerivedData/DreamCart-*/Build/Products -maxdepth 2 -name DreamCart.app -path "*iphonesimulator*" | head -1)
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch "$UDID" com.jackwallner.shop
```

Drive controls with `axe tap`, `axe swipe`, and `axe describe-ui`. Prefer `--id`, then an exact unique `--label`; use coordinates only after reading the current AX frame.

Record transitions, not only endpoints:

```bash
axe record-video --udid "$UDID" --fps 15 --quality 85 --output /tmp/dreamcart-qa/flow.mp4
axe screenshot --udid "$UDID" --output /tmp/dreamcart-qa/frame.png
```

Core regression flows:

1. Scroll Today shelves and check card copy never overlaps the next section.
2. Swipe For You left and right, inspect mid-transition frames and cart badge updates.
3. Today > Shop > product. First Add to cart stays on detail and changes to Go to checkout; second tap opens Checkout.
4. Complete checkout with a fictional address. Tap through unboxing, then See in closet must select Closet and show the purchase.
5. Closet > Dressing room > choose an owned item. The on-device composite remains usable if segmentation fails; editorial rendering is optional and cached.
6. Switch tabs and push/pop product detail while recording. Check tab-bar transparency and wallet stability.

Save evidence under a dated `/tmp/dreamcart-qa-YYYYMMDD/` directory. Inspect screenshots and extracted video frames before reporting PASS.

Run `agent-sim checkin shop` when the last capture is done.
