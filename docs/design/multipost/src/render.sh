#!/bin/sh
# Render the Multipost concept HTML to PNG with headless Edge at 2x.
cd "$(dirname "$0")" || exit 1
python build.py || exit 1
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
HTML="$(pwd -W 2>/dev/null || pwd)/html"
OUTDIR="$(pwd -W)/.."
shot() { # name width height
  "$EDGE" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
    --virtual-time-budget=4000 --window-size="$2,$3" \
    --screenshot="$OUTDIR/$1.png" "file:///$HTML/$1.html" >/dev/null 2>&1
  echo "rendered $1"
}
for d in a-impression b-caption; do
  for s in brand library composer results; do shot "$d-$s" 390 844; done
  shot "$d-board" 1816 "${BOARD_H:-1430}"
done
