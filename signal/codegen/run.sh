#!/usr/bin/env bash
# codegen weld: emit models from .koru.kz, check oracle + cross parity.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
GEN="$ROOT/zig-out/generated"
WMFX_MODEL="$GEN/breath_wmfx_model.zig"
KORU_MODEL="$GEN/breath_koru_model.zig"
KORU_KZ_MODEL="$GEN/breath_koru_kz_model.zig"
WMFX="$ROOT/../../../koru/models/breath/model.wmfx"
BREATH_KZ="$ROOT/../models/breath.koru.kz"
FLOOR_KZ="$ROOT/../models/floor.koru.kz"

mkdir -p "$GEN"

echo "== build emitters =="
(cd "$ROOT" && rm -rf .zig-cache && zig build)

echo "== emit WMFX reference path =="
"$ROOT/zig-out/bin/signal-emit" "$WMFX_MODEL" "$WMFX"

echo "== emit Koru .koru.eel path =="
"$ROOT/zig-out/bin/signal-koru-emit" "$KORU_MODEL" "$ROOT/../models/breath.koru.eel"

echo "== emit Koru .koru.kz path (D2) =="
"$ROOT/zig-out/bin/signal-model-emit" "$KORU_KZ_MODEL" "$BREATH_KZ"
"$ROOT/zig-out/bin/signal-model-emit" "$GEN/floor_model.zig" "$FLOOR_KZ"

echo "== reference oracle harness =="
zig build-exe -ODebug \
  --dep model --dep oracle \
  -Mroot="$ROOT/breath_harness.zig" \
  -Mmodel="$WMFX_MODEL" \
  -Moracle="$ROOT/oracle.zig" \
  -femit-bin="$ROOT/zig-out/breath-harness"

"$ROOT/zig-out/breath-harness"

echo "== Koru≡reference parity =="
zig build-exe -ODebug \
  --dep wmfx_model --dep koru_model --dep oracle \
  -Mroot="$ROOT/breath_parity.zig" \
  -Mwmfx_model="$WMFX_MODEL" \
  -Mkoru_model="$KORU_KZ_MODEL" \
  -Moracle="$ROOT/oracle.zig" \
  -femit-bin="$ROOT/zig-out/breath-parity"

"$ROOT/zig-out/breath-parity"

echo "== Breath reference @unit labels (models/breath.koru.eel) =="
UNIT_REF="$ROOT/../models/breath.koru.eel"
for pair in \
  "pass_rate:percent" \
  "peak:percent" \
  "drawdown:percent" \
  "depth_floor:percent" \
  "dip_ticks:1" \
  "dur_threshold:1" \
  "alarm:1" \
  "surprise:1"; do
  name="${pair%%:*}"
  dim="${pair#*:}"
  grep -E "@unit[[:space:]]+${name}[[:space:]]+${dim}" "$UNIT_REF" >/dev/null || {
    echo "FAIL: missing @unit $name $dim in $UNIT_REF"
    exit 1
  }
done
echo "PASS: Breath reference unit labels present in breath.koru.eel"

echo "== Breath reference authoring spine (models/breath.koru.kz) =="
SPINE_REF="$ROOT/../models/breath.koru.kz"
for needle in \
  "koru/signal:shape(Breath)" \
  "pass_rate[percent]" \
  "const {" \
  "depth_floor: 8" \
  "dur_threshold: 18" \
  "koru/signal:init(Breath)" \
  "peak: 0" \
  "block {" \
  "peak[percent]" \
  "dip_ticks[1]"; do
  grep -Fq "$needle" "$SPINE_REF" || {
    echo "FAIL: missing spine fragment '$needle' in $SPINE_REF"
    exit 1
  }
done
echo "PASS: Breath reference authoring spine present in breath.koru.kz"

echo "== install models =="
cp "$WMFX_MODEL" "$ROOT/../models/breath.zig"
cp "$GEN/floor_model.zig" "$ROOT/../models/floor.zig"
echo "Wrote $ROOT/../models/breath.zig"
echo "Wrote $ROOT/../models/floor.zig"
