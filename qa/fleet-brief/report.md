# Release gate: shop-ship 5bf1d6c8c947

Verdict: **BLOCK** (2026-11-01T08:19:24+00:00)

Every finding blocks except legacy backlog. `qa-gate fix <repo>` fixes them. Motion candidates need a judgement in the ledger: `qa-gate ledger <repo> accept` for an intended change, or `add` a P1 when it is a real glitch.

## Blocking (3)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P0 | journey-broken | duo | test2TabsPlusOfferAndReturn /  | XCTAssertTrue failed | `journey-broken|test2TabsPlusOfferAndReturn` |
| P1 | fleetqa-stale |  |  /  | vendored FleetQA.swift differs from ~/ios/qa; rerun after install | `fleetqa-stale` |
| P1 | core-journey-missing |  |  /  | no testCoreLoop journey proves the core feature still works; write one (/Users/jackwallner/ios/qa/core-journey-brief.md) | `core-journey-missing` |

## Needs a judgement (0)

None.

## Legacy backlog, warns until fixed (220)

| Sev | Oracle | Persona | Journey / checkpoint | Detail | Fingerprint |
|---|---|---|---|---|---|
| P2 | a11y-hit-region |  | checkpoint(_:button:in:) / welcome | Hit area is too small: "Page 1 of 3" | `a11y-hit-region|checkpoint(_:button:in:)|welcome|page # of #` |
| P2 | a11y-contrast |  | checkpoint(_:button:in:) / welcome | Contrast nearly passed: "Next" | `a11y-contrast|checkpoint(_:button:in:)|welcome|next` |
| P2 | a11y-hit-region |  | checkpoint(_:button:in:) / welcome-coins | Hit area is too small: "Page 1 of 3" | `a11y-hit-region|checkpoint(_:button:in:)|welcome-coins|page # of #` |
| P2 | a11y-contrast |  | checkpoint(_:button:in:) / welcome-coins | Contrast nearly passed: "Next" | `a11y-contrast|checkpoint(_:button:in:)|welcome-coins|next` |
| P2 | a11y-hit-region |  | checkpoint(_:button:in:) / welcome-closet | Hit area is too small: "Page 1 of 3" | `a11y-hit-region|checkpoint(_:button:in:)|welcome-closet|page # of #` |
| P2 | a11y-contrast |  | checkpoint(_:button:in:) / welcome-closet | Contrast nearly passed: "Get started" | `a11y-contrast|checkpoint(_:button:in:)|welcome-closet|get started` |
| P2 | a11y-hit-region |  | checkpoint(_:button:in:) / sign-in | Hit area is too small: "Privacy Policy" | `a11y-hit-region|checkpoint(_:button:in:)|sign-in|privacy policy` |
| P2 | a11y-hit-region |  | checkpoint(_:button:in:) / sign-in | Hit area is too small: "Terms" | `a11y-hit-region|checkpoint(_:button:in:)|sign-in|terms` |
| P2 | a11y-hit-region |  | checkpoint(_:button:in:) / sign-in | Hit area is too small: "Continue as tester" | `a11y-hit-region|checkpoint(_:button:in:)|sign-in|continue as tester` |
| P2 | a11y-hit-region |  | today(_:in:) / first-today | Hit area is too small: "Shop all" | `a11y-hit-region|today(_:in:)|first-today|shop all` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast nearly passed: "Today" | `a11y-contrast|today(_:in:)|first-today|today` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "For You" | `a11y-contrast|today(_:in:)|first-today|for you` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Cart" | `a11y-contrast|today(_:in:)|first-today|cart` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "You" | `a11y-contrast|today(_:in:)|first-today|you` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Daily Drop" | `a11y-contrast|today(_:in:)|first-today|daily drop` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Browse as long as you like. Sign in when you want to claim daily coins, spin the wheel and keep what you buy." | `a11y-contrast|today(_:in:)|first-today|browse as long as you like. sign in when you want to claim d` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Sign in" | `a11y-contrast|today(_:in:)|first-today|sign in` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Halcyon" | `a11y-contrast|today(_:in:)|first-today|halcyon` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "See all" | `a11y-contrast|today(_:in:)|first-today|see all` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Quiet luxury, loud calm." | `a11y-contrast|today(_:in:)|first-today|quiet luxury, loud calm.` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast nearly passed: "RARE" | `a11y-contrast|today(_:in:)|first-today|rare` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast nearly passed: "NEW" | `a11y-contrast|today(_:in:)|first-today|new` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Nova Deep Plum Puffer Jacket" | `a11y-contrast|today(_:in:)|first-today|nova deep plum puffer jacket` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Atelier Clay Tailored Shorts" | `a11y-contrast|today(_:in:)|first-today|atelier clay tailored shorts` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "District Sage Pearl Choker" | `a11y-contrast|today(_:in:)|first-today|district sage pearl choker` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "730" | `a11y-contrast|today(_:in:)|first-today|#` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "$" | `a11y-contrast|today(_:in:)|first-today|$` |
| P3 | never-idle |  | today(_:in:) / first-today | screen still drawing a second after it settled: 18.7% of pixels changed in x 16 to 374, y 481 to 664 | `never-idle|today(_:in:)|first-today|` |
| P2 | a11y-hit-region |  | today(_:in:) / today | Hit area is too small: "Shop all" | `a11y-hit-region|today(_:in:)|today|shop all` |
| P2 | a11y-hit-region |  | today(_:in:) / today | Hit area is too small: "See all" | `a11y-hit-region|today(_:in:)|today|see all` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast nearly passed: "Today" | `a11y-contrast|today(_:in:)|today|today` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "For You" | `a11y-contrast|today(_:in:)|today|for you` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast nearly passed: "4" | `a11y-contrast|today(_:in:)|today|#` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "You" | `a11y-contrast|today(_:in:)|today|you` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "$" | `a11y-contrast|today(_:in:)|today|$` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast nearly passed: "Daily claimed" | `a11y-contrast|today(_:in:)|today|daily claimed` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "Halcyon" | `a11y-contrast|today(_:in:)|today|halcyon` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "See all" | `a11y-contrast|today(_:in:)|today|see all` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "Quiet luxury, loud calm." | `a11y-contrast|today(_:in:)|today|quiet luxury, loud calm.` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "SPIN" | `a11y-contrast|today(_:in:)|today|spin` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "Your free spin is ready" | `a11y-contrast|today(_:in:)|today|your free spin is ready` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast nearly passed: "RARE" | `a11y-contrast|today(_:in:)|today|rare` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast nearly passed: "NEW" | `a11y-contrast|today(_:in:)|today|new` |
| P2 | layout-shift |  | test2TabsPlusOfferAndReturn / for-you | late layout shift 0.092 (web CLS scale, 0.1 is poor): image "" resized 44pt at +1.4s after the step settled; 23 element(s) moved | `layout-shift|test2TabsPlusOfferAndReturn|for-you|` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast nearly passed: "For You" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|for you` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast nearly passed: "4" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|#` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast failed: "You" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|you` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast failed: "$" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|$` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast failed: "ADD" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|add` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast failed: "PASS" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|pass` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast failed: "HALCYON" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|halcyon` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast failed: "Muse Slate Combat Boots" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|muse slate combat boots` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast failed: "#workwear  #quiet-luxury  #shoes" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|#workwear #quiet-luxury #shoes` |
| P2 | a11y-hit-region |  | test2TabsPlusOfferAndReturn / cart | Hit area is too small: "990 coins" | `a11y-hit-region|test2TabsPlusOfferAndReturn|cart|# coins` |
| P3 | a11y-element-description |  | test2TabsPlusOfferAndReturn / cart | Element has no description | `a11y-element-description|test2TabsPlusOfferAndReturn|cart|` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast nearly passed: "4" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|#` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "For You" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|for you` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "You" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|you` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "$" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|$` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast nearly passed: "Check out" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|check out` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "Echo Peach Loafers" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|echo peach loafers` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "Cascade Ruby Strappy Heels" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|cascade ruby strappy heels` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "Nova Deep Plum Puffer Jacket" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|nova deep plum puffer jacket` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "Spin the wheel" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|spin the wheel` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "SPIN" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|spin` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "RARE" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|rare` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "NEW" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|new` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "MERIDIAN & CO." | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|meridian & co.` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "IRONWOOD SUPPLY" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|ironwood supply` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "Atelier Clay Tailored Shorts" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|atelier clay tailored shorts` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / cart | Contrast failed: "District Sage Pearl Choker" | `a11y-contrast|test2TabsPlusOfferAndReturn|cart|district sage pearl choker` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "For You" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|for you` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast nearly passed: "4" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|#` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast nearly passed: "Closet" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|closet` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "You" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|you` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "$" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|$` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "12 pieces owned" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|# pieces owned` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "All" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|all` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast nearly passed: "Marfa Hot Pink Halter Knit" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|marfa hot pink halter knit` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast nearly passed: "RARE" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|rare` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "Halo Butter Leather Moto Jacket" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|halo butter leather moto jacket` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "MERIDIAN & CO." | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|meridian & co.` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "Nova Deep Plum Puffer Jacket" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|nova deep plum puffer jacket` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast nearly passed: "IRONWOOD SUPPLY" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|ironwood supply` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast nearly passed: "Atelier Clay Tailored Shorts" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|atelier clay tailored shorts` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "SUNBLEACH" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|sunbleach` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "District Sage Pearl Choker" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|district sage pearl choker` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "For You" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|for you` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast nearly passed: "4" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|#` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast nearly passed: "You" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|you` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "$" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|$` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "DreamCart+" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|dreamcart+` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "Active · manage or cancel in the App Store" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|active · manage or cancel in the app store` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "Get more coins" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|get more coins` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "More" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|more` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "Marfa Hot Pink Halter Knit" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|marfa hot pink halter knit` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "RARE" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|rare` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "Quartz Bone Boxy Tee" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|quartz bone boxy tee` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "Halo Butter Leather Moto Jacket" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|halo butter leather moto jacket` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "NEW" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|new` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "MERIDIAN & CO." | `a11y-contrast|test2TabsPlusOfferAndReturn|you|meridian & co.` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "Nova Deep Plum Puffer Jacket" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|nova deep plum puffer jacket` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "IRONWOOD SUPPLY" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|ironwood supply` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "Atelier Clay Tailored Shorts" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|atelier clay tailored shorts` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "SUNBLEACH" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|sunbleach` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "District Sage Pearl Choker" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|district sage pearl choker` |
| P2 | paywall-restore |  | test2TabsPlusOfferAndReturn / coin-shop | no Restore Purchases control on the paywall (3.1.1) | `paywall-restore|test2TabsPlusOfferAndReturn|coin-shop|` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast failed: "Done" | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|done` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast failed: "Your balance" | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|your balance` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast failed: "Coins are for use inside DreamCart only and have no cash value. All items and delivery are virtual." | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|coins are for use inside dreamcart only and have no cash val` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast failed: "$" | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|$` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast failed: "$1.99" | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|$#` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast nearly passed: "POPULAR" | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|popular` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast nearly passed: "BEST VALUE" | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|best value` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast failed: "Never run dry" | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|never run dry` |
| P2 | a11y-hit-region |  | today(_:in:) / today-after-offer | Hit area is too small: "Shop all" | `a11y-hit-region|today(_:in:)|today-after-offer|shop all` |
| P2 | a11y-hit-region |  | today(_:in:) / today-after-offer | Hit area is too small: "See all" | `a11y-hit-region|today(_:in:)|today-after-offer|see all` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast nearly passed: "Today" | `a11y-contrast|today(_:in:)|today-after-offer|today` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "For You" | `a11y-contrast|today(_:in:)|today-after-offer|for you` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast nearly passed: "4" | `a11y-contrast|today(_:in:)|today-after-offer|#` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "You" | `a11y-contrast|today(_:in:)|today-after-offer|you` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "$" | `a11y-contrast|today(_:in:)|today-after-offer|$` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast nearly passed: "Daily claimed" | `a11y-contrast|today(_:in:)|today-after-offer|daily claimed` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Halcyon" | `a11y-contrast|today(_:in:)|today-after-offer|halcyon` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "See all" | `a11y-contrast|today(_:in:)|today-after-offer|see all` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Quiet luxury, loud calm." | `a11y-contrast|today(_:in:)|today-after-offer|quiet luxury, loud calm.` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "SPIN" | `a11y-contrast|today(_:in:)|today-after-offer|spin` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Your free spin is ready" | `a11y-contrast|today(_:in:)|today-after-offer|your free spin is ready` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "DreamCart+" | `a11y-contrast|today(_:in:)|today-after-offer|dreamcart+` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Active · manage or cancel in the App Store" | `a11y-contrast|today(_:in:)|today-after-offer|active · manage or cancel in the app store` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Get more coins" | `a11y-contrast|today(_:in:)|today-after-offer|get more coins` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "More" | `a11y-contrast|today(_:in:)|today-after-offer|more` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "RARE" | `a11y-contrast|today(_:in:)|today-after-offer|rare` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Halo Butter Leather Moto Jacket" | `a11y-contrast|today(_:in:)|today-after-offer|halo butter leather moto jacket` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast nearly passed: "NEW" | `a11y-contrast|today(_:in:)|today-after-offer|new` |
| P2 | a11y-hit-region |  | today(_:in:) / today-after-background | Hit area is too small: "Shop all" | `a11y-hit-region|today(_:in:)|today-after-background|shop all` |
| P2 | a11y-hit-region |  | today(_:in:) / today-after-background | Hit area is too small: "See all" | `a11y-hit-region|today(_:in:)|today-after-background|see all` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast nearly passed: "Today" | `a11y-contrast|today(_:in:)|today-after-background|today` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "For You" | `a11y-contrast|today(_:in:)|today-after-background|for you` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast nearly passed: "4" | `a11y-contrast|today(_:in:)|today-after-background|#` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "You" | `a11y-contrast|today(_:in:)|today-after-background|you` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "$" | `a11y-contrast|today(_:in:)|today-after-background|$` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast nearly passed: "Daily claimed" | `a11y-contrast|today(_:in:)|today-after-background|daily claimed` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Halcyon" | `a11y-contrast|today(_:in:)|today-after-background|halcyon` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "See all" | `a11y-contrast|today(_:in:)|today-after-background|see all` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Quiet luxury, loud calm." | `a11y-contrast|today(_:in:)|today-after-background|quiet luxury, loud calm.` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "SPIN" | `a11y-contrast|today(_:in:)|today-after-background|spin` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Your free spin is ready" | `a11y-contrast|today(_:in:)|today-after-background|your free spin is ready` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "DreamCart+" | `a11y-contrast|today(_:in:)|today-after-background|dreamcart+` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Active · manage or cancel in the App Store" | `a11y-contrast|today(_:in:)|today-after-background|active · manage or cancel in the app store` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Get more coins" | `a11y-contrast|today(_:in:)|today-after-background|get more coins` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "More" | `a11y-contrast|today(_:in:)|today-after-background|more` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "RARE" | `a11y-contrast|today(_:in:)|today-after-background|rare` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Halo Butter Leather Moto Jacket" | `a11y-contrast|today(_:in:)|today-after-background|halo butter leather moto jacket` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast nearly passed: "NEW" | `a11y-contrast|today(_:in:)|today-after-background|new` |
| P2 | a11y-hit-region |  | today(_:in:) / today-after-relaunch | Hit area is too small: "Shop all" | `a11y-hit-region|today(_:in:)|today-after-relaunch|shop all` |
| P2 | a11y-hit-region |  | today(_:in:) / today-after-relaunch | Hit area is too small: "See all" | `a11y-hit-region|today(_:in:)|today-after-relaunch|see all` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast nearly passed: "Today" | `a11y-contrast|today(_:in:)|today-after-relaunch|today` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "For You" | `a11y-contrast|today(_:in:)|today-after-relaunch|for you` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast nearly passed: "4" | `a11y-contrast|today(_:in:)|today-after-relaunch|#` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "You" | `a11y-contrast|today(_:in:)|today-after-relaunch|you` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "$" | `a11y-contrast|today(_:in:)|today-after-relaunch|$` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast nearly passed: "Daily claimed" | `a11y-contrast|today(_:in:)|today-after-relaunch|daily claimed` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "Halcyon" | `a11y-contrast|today(_:in:)|today-after-relaunch|halcyon` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "See all" | `a11y-contrast|today(_:in:)|today-after-relaunch|see all` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "Quiet luxury, loud calm." | `a11y-contrast|today(_:in:)|today-after-relaunch|quiet luxury, loud calm.` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "SPIN" | `a11y-contrast|today(_:in:)|today-after-relaunch|spin` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "Your free spin is ready" | `a11y-contrast|today(_:in:)|today-after-relaunch|your free spin is ready` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast nearly passed: "RARE" | `a11y-contrast|today(_:in:)|today-after-relaunch|rare` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast nearly passed: "NEW" | `a11y-contrast|today(_:in:)|today-after-relaunch|new` |
| P2 | a11y-contrast |  | checkpoint(_:button:in:) / welcome | Contrast failed: "Original fashion, dream looks, zero dollars. Fill your cart with everything you'd never actually buy." | `a11y-contrast|checkpoint(_:button:in:)|welcome|original fashion, dream looks, zero dollars. fill your cart ` |
| P2 | a11y-contrast |  | checkpoint(_:button:in:) / welcome-coins | Contrast failed: "Claim a daily drop, spin the wheel, and keep your streak alive. The more you show up, the more you get." | `a11y-contrast|checkpoint(_:button:in:)|welcome-coins|claim a daily drop, spin the wheel, and keep your streak ali` |
| P2 | a11y-contrast |  | today(_:in:) / first-today | Contrast failed: "Just dropped" | `a11y-contrast|today(_:in:)|first-today|just dropped` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "Just dropped" | `a11y-contrast|today(_:in:)|today|just dropped` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "Fresh today" | `a11y-contrast|today(_:in:)|today|fresh today` |
| P2 | a11y-contrast |  | today(_:in:) / today | Contrast failed: "Spin the wheel" | `a11y-contrast|today(_:in:)|today|spin the wheel` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / for-you | text drawn as "To..." but reads "Fresh today" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|for-you|fresh today` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / for-you | text drawn as "obsessi..." but reads "Your next obsession" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|for-you|your next obsession` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / for-you | text drawn as "Slate Co..." but reads "Muse Slate Combat Boots" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|for-you|muse slate combat boots` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / for-you | button drawn as "To..." but reads "Today" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|for-you|today` |
| P2 | overlap |  | test2TabsPlusOfferAndReturn / for-you | text "ADD" overlaps "PASS" by 71% (AX3 text only) | `overlap|test2TabsPlusOfferAndReturn|for-you|add / pass` |
| P2 | overlap |  | test2TabsPlusOfferAndReturn / for-you | text "ADD" overlaps "Muse Slate Combat Boots" by 47% (AX3 text only) | `overlap|test2TabsPlusOfferAndReturn|for-you|add / muse slate combat boots` |
| P2 | overlap |  | test2TabsPlusOfferAndReturn / for-you | text "PASS" overlaps "Muse Slate Combat Boots" by 42% (AX3 text only) | `overlap|test2TabsPlusOfferAndReturn|for-you|muse slate combat boots / pass` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / for-you | Contrast failed: "#workwear" | `a11y-contrast|test2TabsPlusOfferAndReturn|for-you|#workwear` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / cart | text drawn as "To..." but reads "Fresh today" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|cart|fresh today` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / cart | text drawn as "Forest..." but reads "Après Forest Oversized Blazer" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|cart|après forest oversized blazer` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / cart | text drawn as "Peach..." but reads "Echo Peach Loafers" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|cart|echo peach loafers` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / cart | button drawn as "To..." but reads "Today" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|cart|today` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / cart | button drawn as "FO..." but reads "For You" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|cart|for you` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / cart | button drawn as "Cl..." but reads "Closet" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|cart|closet` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / closet | text drawn as "To..." but reads "Fresh today" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|closet|fresh today` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / closet | button drawn as "To..." but reads "Today" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|closet|today` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / closet | Contrast failed: "NEW" | `a11y-contrast|test2TabsPlusOfferAndReturn|closet|new` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / you | text drawn as "To..." but reads "Fresh today" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|you|fresh today` |
| P2 | truncated |  | test2TabsPlusOfferAndReturn / you | button drawn as "To..." but reads "Today" (AX3 text only) | `truncated|test2TabsPlusOfferAndReturn|you|today` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / you | Contrast failed: "New drop reminders" | `a11y-contrast|test2TabsPlusOfferAndReturn|you|new drop reminders` |
| P2 | a11y-contrast |  | test2TabsPlusOfferAndReturn / coin-shop | Contrast failed: "1,000 coins" | `a11y-contrast|test2TabsPlusOfferAndReturn|coin-shop|# coins` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Just dropped" | `a11y-contrast|today(_:in:)|today-after-offer|just dropped` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Fresh today" | `a11y-contrast|today(_:in:)|today-after-offer|fresh today` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Coins" | `a11y-contrast|today(_:in:)|today-after-offer|coins` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Best" | `a11y-contrast|today(_:in:)|today-after-offer|best` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Appearance" | `a11y-contrast|today(_:in:)|today-after-offer|appearance` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "New drop reminders" | `a11y-contrast|today(_:in:)|today-after-offer|new drop reminders` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Spin the wheel" | `a11y-contrast|today(_:in:)|today-after-offer|spin the wheel` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-offer | Contrast failed: "Marfa Hot Pink Halter Knit" | `a11y-contrast|today(_:in:)|today-after-offer|marfa hot pink halter knit` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Just dropped" | `a11y-contrast|today(_:in:)|today-after-background|just dropped` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Fresh today" | `a11y-contrast|today(_:in:)|today-after-background|fresh today` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Coins" | `a11y-contrast|today(_:in:)|today-after-background|coins` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Best" | `a11y-contrast|today(_:in:)|today-after-background|best` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Appearance" | `a11y-contrast|today(_:in:)|today-after-background|appearance` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "New drop reminders" | `a11y-contrast|today(_:in:)|today-after-background|new drop reminders` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Spin the wheel" | `a11y-contrast|today(_:in:)|today-after-background|spin the wheel` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-background | Contrast failed: "Marfa Hot Pink Halter Knit" | `a11y-contrast|today(_:in:)|today-after-background|marfa hot pink halter knit` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "Just dropped" | `a11y-contrast|today(_:in:)|today-after-relaunch|just dropped` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "Fresh today" | `a11y-contrast|today(_:in:)|today-after-relaunch|fresh today` |
| P2 | a11y-contrast |  | today(_:in:) / today-after-relaunch | Contrast failed: "Spin the wheel" | `a11y-contrast|today(_:in:)|today-after-relaunch|spin the wheel` |
| P2 | a11y-hit-region |  | today(_:in:) / today | Hit area is too small: "990 coins" | `a11y-hit-region|today(_:in:)|today|# coins` |
| P3 | a11y-element-description |  | today(_:in:) / today | Element has no description | `a11y-element-description|today(_:in:)|today|` |
| P2 | a11y-hit-region |  | test2TabsPlusOfferAndReturn / for-you | Hit area is too small: "990 coins" | `a11y-hit-region|test2TabsPlusOfferAndReturn|for-you|# coins` |
| P3 | a11y-element-description |  | test2TabsPlusOfferAndReturn / for-you | Element has no description | `a11y-element-description|test2TabsPlusOfferAndReturn|for-you|` |

## Journeys

| Persona | Journey | Result | Seconds |
|---|---|---|---|
| newcomer | test1FirstRunToBrowsing | Passed | 53.04764795303345 |
| newcomer | test2TabsPlusOfferAndReturn | Passed | 270.9432669878006 |
| accessibility | test1FirstRunToBrowsing | Passed | 42.332327008247375 |
| accessibility | test2TabsPlusOfferAndReturn | Passed | 303.0654889345169 |
| reduce-motion | test1FirstRunToBrowsing | Passed | 53.69351100921631 |
| reduce-motion | test2TabsPlusOfferAndReturn | Passed | 268.2771739959717 |
| duo | test1FirstRunToBrowsing | Passed | 42.594200015068054 |
| duo | test2TabsPlusOfferAndReturn | Failed | 48.068790912628174 |

## Motion

| Persona | Motion s | Windows | Candidates | Gaps > 25 ms | 60 fps |
|---|---|---|---|---|---|
| newcomer | 28.155 | 31 | 20 | 145 | True |
| accessibility | 17.846 | 29 | 21 | 58 | True |
| reduce-motion | 16.983 | 29 | 13 | 78 | True |

## Launch entrances to look at

Each launch's frames after the springboard zoom, left to right then down, 4 frames per
row at the recorded rate. A blank stretch, text that reflows, or content that arrives and
pushes the layout is a finding: `qa-gate ledger <repo> add`.

- [entrance-01-test1firstruntobrowsing.png](/Users/jackwallner/shop-ship/build/qa/5bf1d6c8c947/newcomer/entrance-01-test1firstruntobrowsing.png)
- [entrance-07-test2tabsplusofferandreturn.png](/Users/jackwallner/shop-ship/build/qa/5bf1d6c8c947/newcomer/entrance-07-test2tabsplusofferandreturn.png)
- [entrance-01-test1firstruntobrowsing.png](/Users/jackwallner/shop-ship/build/qa/5bf1d6c8c947/accessibility/entrance-01-test1firstruntobrowsing.png)
- [entrance-07-test2tabsplusofferandreturn.png](/Users/jackwallner/shop-ship/build/qa/5bf1d6c8c947/accessibility/entrance-07-test2tabsplusofferandreturn.png)
- [entrance-17-test2tabsplusofferandreturn.png](/Users/jackwallner/shop-ship/build/qa/5bf1d6c8c947/accessibility/entrance-17-test2tabsplusofferandreturn.png)
- [entrance-01-test1firstruntobrowsing.png](/Users/jackwallner/shop-ship/build/qa/5bf1d6c8c947/reduce-motion/entrance-01-test1firstruntobrowsing.png)
- [entrance-14-today-in.png](/Users/jackwallner/shop-ship/build/qa/5bf1d6c8c947/reduce-motion/entrance-14-today-in.png)

Skipped personas: german (app not localized).
