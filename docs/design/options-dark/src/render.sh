#!/bin/sh
# Render the static concept HTML to PNG with headless Edge at 2x.
cd "$(dirname "$0")" || exit 1
python build.py || exit 1
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
HTML="$(pwd -W 2>/dev/null || pwd)/html"
OUTDIR=".."
shot() { # name width height
  "$EDGE" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --virtual-time-budget=4000 --window-size="$2,$3" \
    --screenshot="$(pwd -W)/$OUTDIR/$1.png" "file:///$HTML/$1.html" >/dev/null 2>&1
  echo "rendered $1"
}
for d in a-caption b-contact c-margin-night; do
  for s in composer results instagram; do shot "$d-$s" 390 844; done
  shot "$d-board" 1346 "${BOARD_H:-1450}"
done
for s in composer results instagram; do shot "compare-$s" 1346 "${COMPARE_H:-1190}"; done
