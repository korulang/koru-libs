#!/usr/bin/env bash
# signal package verify — Layer A (suite) + Layer B/C (codegen weld + Breath reference).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SIGNAL="$(cd "$(dirname "$0")" && pwd)"

echo "== koru-libs suite (signal cases) =="
cd "$ROOT"
KORU_HOME="${KORU_HOME:-$HOME/src/koru}" koruc suite.k test

echo "== signal codegen (Breath reference + unit labels) =="
cd "$SIGNAL/codegen"
bash run.sh

echo "PASS: signal verify (suite + codegen)"
