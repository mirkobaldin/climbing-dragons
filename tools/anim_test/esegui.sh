#!/usr/bin/env bash
# Esegue un test Luau dei moduli puri delle animazioni procedurali fuori da Roblox.
#   bash tools/anim_test/esegui.sh test_scheletro.luau
# Unisce in un file solo: Vector3 finto (vector3.luau), i moduli puri di src/shared, gli
# scheletri veri (scheletri.txt) e il test. Serve il Luau da riga di comando (luau-lang/luau).
set -euo pipefail
DIR="$(cd "$(dirname "$0")" && pwd)"
REPO="$(cd "$DIR/../.." && pwd)"
LUAU="${LUAU:-$(command -v luau || echo /opt/luau/luau)}"
OUT="$(mktemp --suffix=.luau)"
{
  echo "Vector3 = (function()"; cat "$DIR/vector3.luau"; echo "end)()"
  for m in DragonSkeleton DragonGait; do
    [ -f "$REPO/src/shared/$m.luau" ] && { echo "local $m = (function()"; grep -v '^--!strict' "$REPO/src/shared/$m.luau"; echo "end)()"; }
  done
  if grep -q "^--@client" "$DIR/$1"; then
    # test del modulo client: CFrame finto, mondo finto, poi DragonProcedural
    echo "CFrame = (function()"; cat "$DIR/cframe.luau"; echo "end)()"
    cat "$DIR/mondo_finto.luau"
    echo "local DragonProcedural = (function()"; grep -v '^--!strict' "$REPO/src/client/DragonProcedural.luau"; echo "end)()"
  fi
  echo "local SCHELETRI = {"
  awk -F'|' '/^#/ {next} /^D\|/ {if (open) print "}},"; printf "{nome=\"%s\", ossa={\n", $2; open=1; next}
             NF==3 {split($3,p,","); printf "{parent=%s, pos=Vector3.new(%s,%s,%s)},\n", $2, p[1], p[2], p[3]}
             END {if (open) print "}},"}' "$DIR/scheletri.txt"
  echo "}"
  cat "$DIR/$1"
} > "$OUT"
"$LUAU" "$OUT"
