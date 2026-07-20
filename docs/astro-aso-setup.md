# Astro ASO setup: DreamCart

Last validated: July 19, 2026

## App

| Field | Value |
|---|---|
| App Store ID | `6787820106` |
| Bundle ID | `com.jackwallner.shop` |
| Astro app ID | `118` (temporary until version 1.0 is searchable) |
| Primary store | `us` |
| ASC version | `1.0` |

## Popularity rule

Astro popularity **5 is the measurement floor and is treated as effectively zero**. A low difficulty score does not rescue a popularity-5 term. These phrases may remain in human-facing positioning when they explain the product, but they do not earn primary indexed space solely as acquisition keywords.

Examples at the floor: `dopamine shopping`, `virtual shopping`, `virtual mall`, `fashion haul`, `outfit game`, and `stylist game`.

## Validated US demand

| Keyword | Popularity | Difficulty | Use |
|---|---:|---:|---|
| shopping | 64 | 91 | Broad category signal, too competitive alone |
| outfit maker | 50 | 56 | Primary subtitle phrase |
| outfit planner | 45 | 56 | Keyword field |
| outfit creator | 37 | 52 | Keyword-field combination |
| fashion shopping | 33 | 86 | Name positioning |
| clothes game | 31 | 70 | Keyword field |
| shop game | 29 | 81 | Supporting combination |
| dress up games for adults | 27 | 69 | Relevant long-tail tracking |
| dressup | 25 | 68 | Keyword field |
| retail therapy | 23 | 37 | Strong efficient keyword-field term |
| closet app | 19 | 58 | Supporting keyword-field term |
| shopping simulator | 16 | 68 | Track, use where space permits |
| shopping game | 12 | 71 | Keyword field |
| dress up game | 12 | 77 | Subtitle phrase |
| wardrobe planner | 10 | 51 | Track and localize selectively |

## US indexed-field strategy

- Name: `DreamCart: Dopamine Shopping`
- Subtitle: `Outfit Maker & Dress Up Game`
- Keywords: `fashion,retail,therapy,stylist,planner,creator,clothes,closet,app,wardrobe,shopaholic,simulator,glam`

`Dopamine Shopping` is the brand-canonical name. The keyword field holds single comma-separated words (never glued compounds and never spaces): Apple recombines individual words across name + subtitle + keywords into search phrases, so `planner` pairs with `outfit` from the subtitle, `clothes` with `game`, etc. Words already supplied by the name/subtitle (`shopping`, `outfit`, `maker`, `dress`, `up`, `game`) are excluded to avoid wasting characters. `fashion` lives in the keyword field because the name no longer carries it.

## Files and commands

- Astro config: `scripts/.astro-app.json`
- Saved metrics: `scripts/astro-keyword-metrics-us.json`
- Refresh metrics: `python3 scripts/astro-fetch-metrics.py`
- Canonical ASC copy: `scripts/asc-localize-metadata.py`
- Validate all locales: `python3 scripts/asc-localize-metadata.py --validate-only`

After version 1.0 becomes searchable, replace temporary Astro app `118` with the real App Store app, then re-run metrics after 7 to 14 days. Review ranking movement before changing indexed fields again.
