# DreamCart UX Backlog Handoff

Simulator UDID: `FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8`

## Checklist

- [x] 1. Empty cart Browse shop CTA
- [x] 2. Dismissible catalog error banner on Today and Shop
- [x] 3. Profile real display name
- [x] 4. Compact claimed Daily Drop card
- [x] 5. Upright spin labels and reset hint
- [x] 6. Category chip icons
- [x] 7. Outfit compositing loading treatment
- [ ] 8. Delisted closet item navigation
- [ ] 9. Accessibility identifiers and labels

## Item Notes

Update each item with status, files touched, screenshots, test results, and punts.

### 1. Empty cart Browse shop CTA

- Status: Complete
- Files: `DreamCart/Views/MainTabView.swift`, `DreamCart/Views/CartView.swift`, `HANDOFF-UX.md`
- Screenshot: Not required for this item
- Tests: `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"`, 6 passed, 0 failed
- Punts: None

### 2. Dismissible catalog error banner on Today and Shop

- Status: Complete
- Files: `DreamCart/Components/LoadErrorBanner.swift`, `DreamCart/Views/TodayView.swift`, `DreamCart/Views/ShopView.swift`, `HANDOFF-UX.md`
- Screenshot: Not required for this item
- Tests: `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"`, 6 passed, 0 failed
- Notes: `refreshAll()` already clears `loadError` before each load. Successful refresh leaves it cleared.
- Punts: None

### 3. Profile real display name

- Status: Complete
- Files: `DreamCart/Views/ProfileView.swift`, `HANDOFF-UX.md`
- Screenshot: Not required for this item
- Tests: `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"`, 6 passed, 0 failed
- Punts: None

### 4. Compact claimed Daily Drop card

- Status: Complete
- Files: `DreamCart/Views/TodayView.swift`, `sim77-design/ux/04-claimed-daily-chip.png`, `HANDOFF-UX.md`
- Screenshot: `sim77-design/ux/04-claimed-daily-chip.png`, inspected. The live account was claimable, so the image shows the full pre-claim card and verifies surrounding layout only.
- Tests: `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"`, 6 passed, 0 failed
- Punts: Compact branch could not be captured without consuming the live account reward or adding debug-only state.

### 5. Upright spin labels and reset hint

- Status: Complete
- Files: `DreamCart/Views/SpinView.swift`, `sim77-design/ux/05-spin-legibility.png`, `HANDOFF-UX.md`
- Screenshot: `sim77-design/ux/05-spin-legibility.png`, inspected. All slice labels are upright and the midnight reset hint is visible.
- Tests: `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"`, 6 passed, 0 failed
- Notes: The server returns `lastSpinDate` but no reset timestamp, so the required fallback copy is used.
- Punts: None

### 6. Category chip icons

- Status: Complete
- Files: `DreamCart/Components/Common.swift`, `DreamCart/Views/ShopView.swift`, `sim77-design/ux/06-category-icons.png`, `HANDOFF-UX.md`
- Screenshot: `sim77-design/ux/06-category-icons.png`, inspected. Symbols align with category labels and use the compact icon scale.
- Tests: `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"`, 6 passed, 0 failed
- Punts: None

### 7. Outfit compositing loading treatment

- Status: Complete
- Files: `DreamCart/Components/CompositeAvatarView.swift`, `sim77-design/ux/07-cutout-loading.png`, `HANDOFF-UX.md`
- Screenshot: `sim77-design/ux/07-cutout-loading.png`, inspected. The capture reached the neutral failure icon after cache regeneration and confirms the purple placeholder rectangle is removed.
- Tests: `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"`, 6 passed, 0 failed
- Punts: The transient spinner completed before the stable screenshot, but its post-load failure treatment was visually verified.
