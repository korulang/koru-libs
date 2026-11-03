#!/usr/bin/env bash
# static-route fastpath A/B probe — byte-diffs every case across the two
# dispatch paths: a.out.lite (handler-lite admission ON, the default) vs
# a.out.full (ORISHA_NO_LITE=1, every arm on the full Request path).
# Both binaries are the same source; only dispatch differs, so any
# response divergence is a fastpath correctness bug.
set -u
cd "$(dirname "$0")"
PORT=48206
CASES=/tmp/w1c-p5a/koru-libs/web/goldens/mixed-router
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"; kill %1 2>/dev/null' EXIT

run_cases() { # $1=outdir
    mkdir -p "$1"
    for cdir in "$CASES"/*/; do
        c=$(basename "$cdir")
        mapfile -t spec < <(grep -v '^$' "$cdir/case.txt")
        method=${spec[0]%% *}; url=${spec[0]#* }
        args=(-s -D "$1/$c.head" -o "$1/$c.body" -X "$method")
        for h in "${spec[@]:1}"; do
            [[ $h == multipart-field:* ]] && continue
            args+=(-H "$h")
        done
        [[ -f $cdir/req-body.bin ]] && args+=(--data-binary "@$cdir/req-body.bin")
        curl "${args[@]}" "http://127.0.0.1:$PORT$url"
    done
}

./a.out.lite >/dev/null 2>&1 &
sleep 0.6; run_cases "$TMP/lite"; kill %1 2>/dev/null; wait 2>/dev/null
./a.out.full >/dev/null 2>&1 &
sleep 0.6; run_cases "$TMP/full"; kill %1 2>/dev/null; wait 2>/dev/null

fail=0
for f in "$TMP"/lite/*; do
    n=$(basename "$f")
    # date is volatile — blank it on both sides, like the closer.
    sed 's/^date:.*/date: <D>/I' "$TMP/lite/$n" > "$TMP/lite.$n"
    sed 's/^date:.*/date: <D>/I' "$TMP/full/$n" > "$TMP/full.$n"
    if ! diff -q "$TMP/lite.$n" "$TMP/full.$n" >/dev/null; then
        echo "DIFF $n"; diff "$TMP/lite.$n" "$TMP/full.$n" | head -10; fail=1
    fi
done
if [ $fail -eq 0 ]; then
    echo "A/B identical: $(ls "$TMP/lite" | wc -l | tr -d ' ') response files, 0 diffs"
else
    echo "A/B DIVERGED"
fi
exit $fail
