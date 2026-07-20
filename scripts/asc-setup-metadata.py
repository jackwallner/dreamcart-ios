#!/usr/bin/env python3
"""Set DreamCart categories and age rating, then apply canonical locale copy.

Usage: source ~/.baseball_credentials && python3 scripts/asc-setup-metadata.py
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import asc_lib

BUNDLE = "com.jackwallner.shop"

BASE_URL = "https://jackwallner.github.io/dreamcart"
SUPPORT_URL = f"{BASE_URL}/support.html"
MARKETING_URL = f"{BASE_URL}/"
PRIVACY_URL = f"{BASE_URL}/privacy-policy.html"


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


    subprocess.run([sys.executable, str(Path(__file__).with_name("asc-localize-metadata.py"))], check=True)
    print("done")


if __name__ == "__main__":
    main()
