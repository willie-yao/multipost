#!/bin/sh
# Render Caption's remaining screens with headless Edge at 2x.
cd "$(dirname "$0")" || exit 1
python build.py && python build_more.py || exit 1
EDGE="/c/Program Files (x86)/Microsoft/Edge/Application/msedge.exe"
HTML="$(pwd -W)/html"
OUT="$(cd .. && pwd -W)/caption"
mkdir -p ../caption
shot() { "$EDGE" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=2 \
  --virtual-time-budget=4000 --window-size="$2,$3" --screenshot="$OUT/$1.png" "file:///$HTML/$1.html" >/dev/null 2>&1; echo "rendered $1"; }
for s in choose version review first-run library accounts review-blocked review-offline unknown returned confirm marked; do
  shot "caption-$s" 390 844
done
shot caption-flow-board 1776 1250
for b in library states-publishing states-instagram; do shot "caption-$b-board" 1346 1250; done
