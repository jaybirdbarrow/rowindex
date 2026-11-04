#!/bin/sh
# Renders the series intro (intro.html) to an MP4, frame by frame, so nothing
# needs screen recording. Needs Google Chrome and Xcode's command line tools.
#
#   ./video/render-intro.sh        feature the newest seat
#   ./video/render-intro.sh 8      feature seat 08
#
# Writes video/row-index-intro-<team>.mp4. Takes about 3 minutes.
set -e
DIR="$(cd "$(dirname "$0")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
FPS=60; FRAMES=360; JOBS=8

# seats come from base.html; seat number and team name from the synced list
python3 "$DIR/sync-seats.py"
SEAT="${1:-$(grep -oE '^ "[0-9]+"' "$DIR/seats.js" | grep -oE '[0-9]+' | sort -n | tail -1)}"
NAME=$(grep -A1 -E "^ \"$SEAT\": \{" "$DIR/seats.js" | sed -nE 's/.*"n": "([^"]+)".*/\1/p')
[ -n "$NAME" ] || { echo "No seat $SEAT with a badge in base.html"; exit 1; }
SLUG=$(echo "$NAME" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-|-$//g')
OUT="$DIR/row-index-intro-$SLUG.mp4"

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
mkdir "$TMP/frames"
echo "Rendering seat $SEAT ($NAME), $FRAMES frames..."

frame() {
  i=$1; t=$(awk "BEGIN{print $i/$FPS}")
  "$CHROME" --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 \
    --window-size=1080,1920 --virtual-time-budget=4000 --allow-file-access-from-files \
    --user-data-dir="$TMP/prof$((i % JOBS))" \
    --screenshot="$TMP/frames/f$(printf %04d "$i").png" \
    "file://$DIR/intro.html?seat=$SEAT&t=$t" >/dev/null 2>&1
}
i=0
while [ $i -lt $FRAMES ]; do
  frame $i &
  i=$((i + 1))
  [ $((i % JOBS)) -eq 0 ] && wait
done
wait

n=$(ls "$TMP/frames" | wc -l | tr -d ' ')
[ "$n" -eq $FRAMES ] || { echo "Only $n of $FRAMES frames rendered"; exit 1; }
echo "Encoding..."
swift "$DIR/render-intro-encode.swift" "$TMP/frames" "$OUT" 2>/dev/null
echo "Done: $OUT"
