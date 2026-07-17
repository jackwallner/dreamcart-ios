# Analytics data collection — ASC privacy questionnaire mapping

DreamCart collects first-party product analytics via `Shared/Services/Analytics.swift`,
written to the `analytics_events` table (`supabase/migrations/20260717000000_analytics_events.sql`).
This doc maps what's collected to how the App Store Connect "App Privacy" (data
nutrition label) questionnaire should be answered. Update the ASC listing to
match before shipping this build.

## What is NOT collected

- No IDFA / advertising identifier, no cross-app or cross-site tracking, no
  ATT prompt is shown or needed.
- No device fingerprinting (no device model/OS beyond what locale/app-version
  strings imply).
- No contacts, photos, location, camera/microphone, or health data.
- No third-party analytics SDK — events go straight from the app to our own
  Supabase project (`jtest0979`) over HTTPS.

## What IS collected, and how to answer ASC

Every event row carries: `user_id` (nullable — the Supabase Sign in with
Apple user id, once signed in), `session_id` (random per app launch, not
persisted across launches), `name`, `props` (event-specific fields, listed
below), `client_timestamp`, `app_version`, `locale`. See the event taxonomy
below for what's in `props` per event.

| ASC data category         | What we collect it from                                                                 | Linked to identity? | Used for tracking? | Purpose            |
|----------------------------|-------------------------------------------------------------------------------------------|----------------------|---------------------|---------------------|
| **Identifiers → User ID**  | `user_id` on every event (Sign in with Apple / Supabase auth id)                          | Yes                  | No                  | Analytics, App Functionality |
| **Purchase History**       | `checkout_started/completed` (item_count, coin_total), `coin_pack_purchase_started/completed` (product_id, coins) | Yes                  | No                  | Analytics, App Functionality |
| **Product Interaction**    | `product_viewed`, `product_dwell`, `swipe_like`/`swipe_discard`, `add_to_cart`, `remove_from_cart`, `wheel_spin_start/result`, `coin_shop_viewed` | Yes                  | No                  | Analytics, App Functionality |
| **Other Usage Data**       | `session_start/end`, `tab_switch`, `onboarding_step/completed`, `shipping_address_saved` (event fires only — no address contents are sent) | Yes                  | No                  | Analytics, App Functionality |

Recommended ASC answers for each category above:
- **Is this data linked to the user's identity?** Yes (joined on `user_id`
  once signed in; pre-auth events carry a null `user_id` and are not later
  linked retroactively).
- **Is this data used to track the user across apps/websites owned by other
  companies?** No.
- **Purpose(s):** Analytics, App Functionality. (Not: Third-Party
  Advertising, Developer's Advertising or Marketing, Other Purposes.)

## Event taxonomy (for reference)

| Event | Fired from | Key props |
|---|---|---|
| `session_start` | App launch | — |
| `session_end` | App → background | — |
| `onboarding_step` | Welcome slides | `step` |
| `onboarding_completed` | "Get started" tap | — |
| `tab_switch` | Main tab bar | `from`, `to` |
| `product_viewed` | Product detail appears | `product_id`, `category`, `price`, `rarity` |
| `product_dwell` | Product detail disappears | `product_id`, `dwell_seconds` |
| `swipe_like` / `swipe_discard` | For You deck swipe | `product_id`, `direction`, `position` |
| `add_to_cart` | Cart add (any entry point) | `product_id`, `recommendation` |
| `remove_from_cart` | Cart remove | `product_id` |
| `checkout_started` / `checkout_completed` | Place order | `item_count`, `coin_total` |
| `wheel_spin_start` / `wheel_spin_result` | Daily spin | `ok`, `prize`, `slice` |
| `coin_shop_viewed` | Coin shop sheet opens | — |
| `coin_pack_purchase_started` / `coin_pack_purchase_completed` | Coin pack buy | `product_id`, `coins` / `coins_granted` |
| `shipping_address_saved` | Shipping address form save | — |

## Access & retention

- Row Level Security on `analytics_events` allows client **inserts only**
  (anon + authenticated); there is no client-facing select/update/delete
  policy, so the app itself can never read this table back. Any dashboard or
  export use goes through the Supabase service role key (`.env.shop`,
  server-side only).
- No client-side retry/requeue on failed sends — dropped events are simply
  lost, never retried, so a flaky connection can't accumulate a backlog.
