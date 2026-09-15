#!/usr/bin/env bash
# check.sh — game oracle runner.
#
# Every tests/<name>.k with a sibling <name>.expected.txt is an oracle:
# compile it, run it, diff stdout (minus raylib INFO noise) against the pin.
# The receipts are deterministic by construction — fixed DT, seeded LCG,
# no wall clock — so an exact diff is the contract. A changed receipt is a
# changed game.
#
# Usage: games/check.sh [test-name ...]     (no args = all oracles)
#        KORUC=/path/to/koruc games/check.sh
set -u

KORUC="${KORUC:-/Users/larsde/src/koru/zig-out/bin/koruc}"
GAMES_DIR="$(cd "$(dirname "$0")" && pwd)"
PASS=0; FAIL=0; SKIP=0

run_oracle() {
    local t="$1"
    local dir; dir="$(dirname "$t")"
    local name; name="$(basename "$t" .k)"
    local exp="${t%.k}.expected.txt"
    [ -f "$exp" ] || { SKIP=$((SKIP+1)); return; }

    (cd "$dir" && "$KORUC" "$name.k" > compile.log 2>&1) || {
        echo "FAIL $t — compile"; tail -5 "$dir/compile.log" | sed 's/^/    /'
        FAIL=$((FAIL+1)); return
    }
    (cd "$dir" && timeout 90 ./a.out 2>&1 | grep -v "^INFO:" > actual.txt) || true
    if (cd "$dir" && diff -u "$name.expected.txt" actual.txt > diff.txt); then
        echo "PASS $t"
        PASS=$((PASS+1))
    else
        echo "FAIL $t — receipt drifted:"
        head -15 "$dir/diff.txt" | sed 's/^/    /'
        FAIL=$((FAIL+1))
    fi
}

if [ $# -gt 0 ]; then
    for arg in "$@"; do
        for t in "$GAMES_DIR"/*/tests/"$arg".k; do
            [ -f "$t" ] && run_oracle "$t"
        done
    done
else
    for t in "$GAMES_DIR"/*/tests/*.k; do
        run_oracle "$t"
    done
fi

echo "── $PASS passed, $FAIL failed, $SKIP without oracle"
[ "$FAIL" -eq 0 ]
