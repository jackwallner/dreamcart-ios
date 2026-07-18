import Foundation

/// Frequency-caps the *proactive* coin upsell (e.g. after a spin when the
/// balance is low) so it shows at most once per app session. This does not
/// gate the "can't afford this" upsell — that one is user-initiated (they
/// tapped "get more coins" themselves) and is allowed to show every time.
///
/// Session-scoped by construction: it's a plain `@State` owned by
/// `DreamCartApp`, so it's recreated (and the cap resets) on every fresh
/// process launch, never persisted to disk.
@MainActor
@Observable
final class UpsellCoordinator {
    private(set) var hasShownNonBlockingThisSession = false

    /// Whether a proactive, non-blocking upsell nudge is allowed to show
    /// right now.
    func canShowNonBlocking() -> Bool {
        !hasShownNonBlockingThisSession
    }

    /// Call once a proactive upsell is actually presented, so later attempts
    /// this session are suppressed.
    func markNonBlockingShown() {
        hasShownNonBlockingThisSession = true
    }
}
