#!/usr/bin/env python3
"""Push DreamCart's US App Store metadata + categories + age rating.
Idempotent; safe to rerun. Localize other regions later.

Usage: source ~/.baseball_credentials && python3 scripts/asc-setup-metadata.py
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.shop"

# --- App-level (appInfoLocalizations): name + subtitle (30 chars each) ---
NAME = "DreamCart: Dopamine Shopping"          # 28
SUBTITLE = "Dress up, style & haul outfits"    # 30

# --- Version-level (appStoreVersionLocalizations) ---
KEYWORDS = "dopamine,fashion stylist,outfit maker,closet,wardrobe,virtual mall,retail therapy,glam,dress up game"

PROMO = ("Free coins every day. Fill your cart with real fashion, spin to win, "
         "and build your dream closet. All the shopping high, none of the bill.")

DESCRIPTION = """Shopping, but make it free.

DreamCart is the shopping game for anyone who loves the thrill of a full cart and none of the buyer's remorse. Browse real-looking fashion from a rotating lineup of brands, pile up the pieces you'd never actually buy, and check out with coins instead of cash. The high hits. The bill never does.

WINDOW SHOP WITHOUT THE GUILT
Add-to-cart, checkout, unbox, repeat. Every purchase lands in your closet with a little celebration and zero regret. It's retail therapy that costs you nothing.

FREE COINS, EVERY SINGLE DAY
Claim your daily drop, keep your streak alive, and spin the wheel for a shot at the jackpot. The more you show up, the more you get to spend.

A STORE THAT NEVER REPEATS
Fresh pieces drop every day across ten distinct brands, from quiet-luxury basics to Y2K streetwear to red-carpet eveningwear. Hunt for rare and legendary drops to flex in your closet.

STYLE YOUR DREAM LOOKS
Own the pieces, then mix and match them into full outfits: tops, bottoms, shoes, jackets, plus jewelry, sunglasses, hats and bags. Save your favorite looks and build a wardrobe that's all you.

BUILT FOR THE DOPAMINE
Big, satisfying, tactile, and fast. Every tap, every unbox, every spin is designed to feel good.

DreamCart is a virtual shopping game. Coins, items, and delivery are all imaginary and have no cash value. Optional coin packs are available if you want to shop more, but you never have to spend a cent to play.
"""

SUPPORT_URL = "https://dreamcart-app.github.io/support"
MARKETING_URL = "https://dreamcart-app.github.io"


def main():
    c = asc_lib.ASCClient(asc_lib.bearer_token(*asc_lib.load_credentials()))
    app_id = asc_lib.find_app(c, BUNDLE)["id"]
    print(f"app {app_id}")

    # --- categories + age rating on the editable appInfo ---
    for info in c.get(f"/apps/{app_id}/appInfos")["data"]:
        state = info["attributes"].get("appStoreState") or info["attributes"].get("state")
        if state not in asc_lib.EDITABLE_STATES:
            continue
        c.patch(f"/appInfos/{info['id']}", {
            "data": {
                "type": "appInfos", "id": info["id"],
                "relationships": {
                    "primaryCategory": {"data": {"type": "appCategories", "id": "LIFESTYLE"}},
                    "secondaryCategory": {"data": {"type": "appCategories", "id": "SHOPPING"}},
                },
            }
        })
        print("categories: Lifestyle / Shopping")

        decl = c.get(f"/appInfos/{info['id']}/ageRatingDeclaration")["data"]
        c.patch(f"/ageRatingDeclarations/{decl['id']}", {
            "data": {
                "type": "ageRatingDeclarations", "id": decl["id"],
                "attributes": {
                    "advertising": False,
                    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
                    "ageAssurance": False,
                    "contests": "NONE",
                    "gambling": False,
                    "gamblingSimulated": "NONE",
                    "gunsOrOtherWeapons": "NONE",
                    "healthOrWellnessTopics": False,
                    "horrorOrFearThemes": "NONE",
                    "lootBox": False,
                    "matureOrSuggestiveThemes": "NONE",
                    "medicalOrTreatmentInformation": "NONE",
                    "messagingAndChat": False,
                    "parentalControls": False,
                    "profanityOrCrudeHumor": "NONE",
                    "sexualContentGraphicAndNudity": "NONE",
                    "sexualContentOrNudity": "NONE",
                    "unrestrictedWebAccess": False,
                    "userGeneratedContent": False,
                    "violenceCartoonOrFantasy": "NONE",
                    "violenceRealistic": "NONE",
                    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
                },
            }
        })
        print("age rating set (all NONE)")

        # name + subtitle
        for loc in c.get(f"/appInfos/{info['id']}/appInfoLocalizations")["data"]:
            if loc["attributes"]["locale"] != "en-US":
                continue
            c.patch(f"/appInfoLocalizations/{loc['id']}", {
                "data": {
                    "type": "appInfoLocalizations", "id": loc["id"],
                    "attributes": {"name": NAME, "subtitle": SUBTITLE},
                }
            })
            print(f"name + subtitle set ({len(NAME)}/{len(SUBTITLE)} chars)")

    # --- version-level copy ---
    for v in asc_lib.list_all(c, f"/apps/{app_id}/appStoreVersions"):
        if v["attributes"]["appStoreState"] not in asc_lib.EDITABLE_STATES:
            continue
        for loc in c.get(f"/appStoreVersions/{v['id']}/appStoreVersionLocalizations")["data"]:
            if loc["attributes"]["locale"] != "en-US":
                continue
            c.patch(f"/appStoreVersionLocalizations/{loc['id']}", {
                "data": {
                    "type": "appStoreVersionLocalizations", "id": loc["id"],
                    "attributes": {
                        "description": DESCRIPTION,
                        "keywords": KEYWORDS,
                        "promotionalText": PROMO,
                        "supportUrl": SUPPORT_URL,
                        "marketingUrl": MARKETING_URL,
                    },
                }
            })
            print(f"description + keywords ({len(KEYWORDS)} chars) + promo set")
        break

    print("done")


if __name__ == "__main__":
    main()
