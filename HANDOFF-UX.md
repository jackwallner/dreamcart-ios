# DreamCart UX Backlog Handoff

Simulator UDID: `FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8`

## Checklist

- [x] 1. Empty cart Browse shop CTA
- [x] 2. Dismissible catalog error banner on Today and Shop
- [ ] 3. Profile real display name
- [ ] 4. Compact claimed Daily Drop card
- [ ] 5. Upright spin labels and reset hint
- [ ] 6. Category chip icons
- [ ] 7. Outfit compositing loading treatment
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
- Files: `DreamCart/Components/LoadErrorBanner.swift`, `DreamCart/Views/TodayView.swift`, `DreamCart/Views/ShopView.swift`, `DreamCart.xcodeproj/project.pbxproj`, `HANDOFF-UX.md`
- Screenshot: Not required for this item
- Tests: `xcodebuild test -project DreamCart.xcodeproj -scheme DreamCart -destination "id=FE2C9DEF-4EA2-4472-8F7F-72A8F7EF28F8"`, 6 passed, 0 failed
- Notes: `refreshAll()` already clears `loadError` before each load. Successful refresh leaves it cleared.
- Punts: None
