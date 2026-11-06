#!/bin/bash
set -euo pipefail

TOOLS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KIT="$(cd "$TOOLS/.." && pwd)"
ROOT="$(cd "$KIT/../../.." && pwd)"
PY="$KIT/.venv/bin/python"
APP_JSON="$KIT/app.json"

if [[ ! -x "$PY" ]]; then
    python3 -m venv "$KIT/.venv"
fi
if ! "$PY" -c 'import numpy; from PIL import Image' 2>/dev/null; then
    "$PY" -m pip install --quiet pillow numpy
fi
"$TOOLS/build.sh"
"$PY" "$TOOLS/fetch_live.py"

declare -a LOCALES=(en-US)
if (($#)); then
    for locale in "$@"; do
        [[ "$locale" == en-US ]] && continue
        spec="$(python3 - "$APP_JSON" "$locale" <<'PY'
import json, sys
targets = json.load(open(sys.argv[1], encoding='utf-8'))['targets']
target = next((item for item in targets if item['store_locale'] == sys.argv[2]), None)
if target is None:
    raise SystemExit(f"unknown target locale: {sys.argv[2]}")
print(target['store_locale'])
PY
)"
        [[ " ${LOCALES[*]} " == *" $spec "* ]] || LOCALES+=("$spec")
    done
else
    while IFS= read -r locale; do
        [[ -n "$locale" ]] && LOCALES+=("$locale")
    done < <(python3 - "$APP_JSON" <<'PY'
import json, sys
for item in json.load(open(sys.argv[1], encoding='utf-8'))['targets']:
    print(item['store_locale'])
PY
)
fi

declare -a SCENES=(today spin foryou spin-result closet)
declare -a SCREEN_ARGS=()
for locale in "${LOCALES[@]}"; do
    if [[ "$locale" == en-US ]]; then
        apple_languages='(en)'
        apple_locale=en_US
    else
        IFS=$'\t' read -r apple_languages apple_locale < <(python3 - "$APP_JSON" "$locale" <<'PY'
import json, sys
target = next(item for item in json.load(open(sys.argv[1], encoding='utf-8'))['targets']
              if item['store_locale'] == sys.argv[2])
print(target['apple_languages'], target['apple_locale'], sep='\t')
PY
)
    fi
    for scene in "${SCENES[@]}"; do
        route="$scene"
        result_arg=
        if [[ "$scene" == spin-result ]]; then
            route=spin
            result_arg='-DuoSpinResult'
        fi
        screen="-AppleLanguages $apple_languages -AppleLocale $apple_locale -DuoTour -DuoRoutes $route -DuoTourFirst 3 -DuoTourStep 30"
        [[ -z "$result_arg" ]] || screen+=" $result_arg"
        SCREEN_ARGS+=(--screen "$screen")
    done
done

id_file="$(mktemp)"
trap 'rm -f "$id_file"' EXIT
gh-sim launch --device "iPhone 17 Pro Max" --wait 14 --record-seconds 1 --args "-DuoSeed" --id-file "$id_file" "${SCREEN_ARGS[@]}"
run_id="$(cat "$id_file")"
result_root="${GH_SIM_HOME:-$HOME/.gh-sim}/results/$run_id"

"$PY" - "$result_root/shots" "$KIT/raw" "${LOCALES[@]}" <<'PY'
from pathlib import Path
import re
import shutil
import sys

shots_dir, raw_root = map(Path, sys.argv[1:3])
locales = sys.argv[3:]
scenes = ['today', 'spin', 'foryou', 'spin-result', 'closet']
shots = {}
for path in shots_dir.glob('screen*.png'):
    match = re.match(r'^screen(\d+)-.*\.png$', path.name)
    if match:
        shots[int(match.group(1))] = path
expected = len(locales) * len(scenes)
if sorted(shots) != list(range(1, expected + 1)):
    raise SystemExit(f"expected screen1 through screen{expected}, found {sorted(shots)}")
for index, (locale, scene) in enumerate(((loc, item) for loc in locales for item in scenes), 1):
    target = raw_root / locale / 'phone' / f'{scene}.png'
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(shots[index], target)
    print(f'{locale}/phone/{scene}.png')
PY

for locale in "${LOCALES[@]}"; do
    [[ "$locale" == en-US ]] && continue
    lang="$(python3 - "$APP_JSON" "$locale" <<'PY'
import json, sys
target = next(item for item in json.load(open(sys.argv[1], encoding='utf-8'))['targets']
              if item['store_locale'] == sys.argv[2])
print(target['lang'])
PY
)"
    "$PY" "$TOOLS/reskin.py" --config "$KIT/frames.json" --raw-root "$KIT/raw" \
        --headers "$KIT/copy/headers.json" --locale "$locale" --out "$KIT/out"
    "$PY" "$TOOLS/gate.py" --config "$KIT/frames.json" --raw-root "$KIT/raw" \
        --headers "$KIT/copy/headers.json" --out-root "$KIT/out" --locale "$locale" \
        --catalog "$ROOT/Shared/Localizable.xcstrings" --lang "$lang"
    "$PY" "$TOOLS/sheet.py" --config "$KIT/frames.json" --locale "$locale" \
        --out-root "$KIT/out" --base-label en
    cp "$KIT/out/sheets/$locale-phone.jpg" "$KIT/sheets/"

    destination="$ROOT/fastlane/screenshots/$locale"
    mkdir -p "$destination"
    find "$destination" -maxdepth 1 -type f -name '*.png' -delete
    for frame in "$KIT/out/$locale/phone"/*.png; do
        cp "$frame" "$destination/"
    done
done
