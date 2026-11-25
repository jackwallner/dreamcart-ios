# State machine fixes, 2026-11-24

Follows `state-machines-2026-11-24.md`. **Counts: 1 claim proved and fixed, 0 held, 0 skipped; 2 code paths not counted (C1 ended by Rollout A's message lifecycle, C2 left as is).**

Evidence on the audited commit `134b8be` plus the repro suite: `gh-sim test --scheme DreamCart --only DreamCartTests/StateMachineAuditRepro`, run `shop@20261125-123648-9ee9-claude-mbpro390a1-1125-124229-16458` (GitHub Actions 45697539594, Xcode 27.1, iPhone 17, iOS 27.2): 2 tests, 1 failed (the claim: "the reminder toggle the shopper turned on must be on again once iOS allows it"), 1 passed (the control).

After the fix, full suite: run `shop@20261125-123648-9ee9-claude-mbpro390a1-1125-131258-20861` (GitHub Actions 45702267782): 129 passed, 0 failed.

| Claim | Result | Commit subject | Regression test |
|---|---|---|---|
| B1, reminders lost after a trip through iOS notification settings | fixed | `fix(notifications): keep the reminder wish when iOS permission is off and restore it when allowed again` | `LocalNotificationCoordinatorTests.testRemindersComeBackWhenPermissionIsAllowedAgain` (the repro claim, which failed on `134b8be`), `testAMissingReminderIsRestoredWhenPermissionReturnsAfterALaunch`, upgrade `testAStoredOnSettingFromAnEarlierBuildStillSchedules`, control `testRemindersTurnedOffInTheAppStayOffAcrossPermissionChanges`; the existing `testReconcileLeavesNoReminderWhenPermissionWasRevoked` still passes |
| C1, error line follows the shopper to the other purchase screen (code path) | not counted; ended by Rollout A | `feat(purchase): show Ask to Buy as waiting for approval instead of an error` | `PurchaseIssueTests.testClosingThePurchaseScreenClearsTheNoticeAndTheError` |
| C2, "You weren't charged" on a late-settling coin purchase (code path) | not counted, not fixed | none | none |

Fix for B1: `notifications.enabled` now holds only the shopper's wish (same key, so stored settings carry over). The toggle reads the wish and iOS permission together, `refreshStatus()` no longer writes the wish, and when it sees permission come back with the wish on it reconciles, which reschedules the reminder. Nothing is scheduled while iOS says no. The shopper's own Off (toggle, or denying the primer's system prompt) still clears the wish.

## Held for Jack

None from the audit. Rollout items are in `rollout-2026-11-24.md`.

## Skipped

- C2: not proved (no seam for a delayed RevenueCat purchase) and no coins are lost (the pending delivery is persisted and recovered on the next foreground). Changing the stale-spinner guard without a repro risks bringing back the stuck spinner it exists to clear.
