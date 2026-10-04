#!/bin/bash
# usage: fetch_cg.sh <chatgpt share url> <out.png>
set -e
H=$(mktemp); curl -sS -L -m 30 -A "Mozilla/5.0" -o $H "$1"
grep -o '<title>[^<]*' $H | head -1
for u in $(grep -o 'https://chatgpt.com/backend-api/estuary/public_content/enc/[A-Za-z0-9=_-]*' $H | sort -u); do
  T=$(mktemp); curl -sS -L -m 60 -A "Mozilla/5.0" -o $T "$u"
  if file -b $T | grep -q "PNG image"; then
    S=$(stat -c%s $T); if [ ! -f "$2" ] || [ $S -gt $(stat -c%s "$2") ]; then cp $T "$2"; fi
  fi; rm -f $T
done
file -b "$2"
