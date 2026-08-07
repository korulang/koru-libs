#!/usr/bin/env bash
# check-lifts.sh — does every shipped lift still hold?
#
# Eleven Unikraft lifts each booted once, on their author's machine, and the
# proof is a console log pasted into a README. Nothing re-ran them. A compiler
# change could break all eleven and the first anyone would know is the next
# time somebody opened one — which is exactly how the plb and osprey corpora
# went dark on the `event` -> `tor` rename without a single red line anywhere.
#
# This is the standing check that replaces reading. It asserts the two things
# that can be asserted without QEMU and without inventing golden files:
#
#   1. every boot_*.kz still BUILDS — all the way through emission, not just
#      `--check`, because shape-checking does not walk the obligation flow and
#      passes programs the full build rejects;
#   2. every negative_*.kz still FAILS to build — a wall that stops biting is
#      a silent regression, and silence is what makes it dangerous.
#
# Deliberately NOT here: booting under QEMU. That needs kraft, a network fetch
# and minutes per lift, and there are no committed expected-output files to
# compare against — the console logs live in prose. Writing goldens from
# whatever the code does today would be a self-certifying check, which is
# worse than no check. Boot verification is a separate, honest job.
#
# Exit 0 if every assertion holds, 1 otherwise. No output is not success —
# the summary always prints.

set -uo pipefail

KORUC="${KORUC:-/Users/larsde/src/koru/zig-out/bin/koruc}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [ ! -x "$KORUC" ]; then
    echo "✗ koruc not found at $KORUC — set KORUC=/path/to/koruc" >&2
    exit 1
fi

# A live regression suite makes every build here compile against a tree that
# may be half-written, and the reds it produces name your own edits. Refuse
# rather than produce a board nobody can trust.
if pgrep -f run_regression >/dev/null 2>&1; then
    echo "✗ a koru regression suite is live — timing out rather than compiling" >&2
    echo "  (each build here compiles emitted Zig against the live src tree)" >&2
    exit 1
fi

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0; unverified=0
declare -a failures=()
declare -a unverifieds=()

# build_expecting <file> <want: ok|error> <label>
build_expecting() {
    local src="$1" want="$2" label="$3"
    # BUILD IN PLACE. Copying the test to a temp dir breaks the lift's own
    # import alias — every entry file resolves `unikraft` relative to its own
    # location (`{{ ENTRY }}/../..`), so a copied test reports
    # `KORU002: module not found` and looks like thirteen broken lifts when
    # nothing is broken at all. Build artifacts here are gitignored, and
    # building beside the source is what each author did.
    local dir; dir="$(dirname "$src")"
    local out rc
    out="$(cd "$dir" && "$KORUC" build "$(basename "$src")" 2>&1)"; rc=$?

    if [ "$want" = "ok" ]; then
        # A boot program calls into Unikraft's C, whose symbols exist only
        # inside a unikernel image — so it CANNOT link as a host binary and a
        # nonzero exit here is expected and meaningless. The real assertion is
        # that the Koru half still compiles all the way through emission.
        # Anything that fails BEFORE emission (a parse error, a refused
        # spelling, a broken obligation) is a genuine regression; a linker
        # complaining about `_uk_mbox_recv_to` is the host correctly lacking a
        # kernel.
        if echo "$out" | grep -q 'Generated output_emitted.zig'; then
            printf '  ok    %s (emits; links only inside a unikernel)\n' "$label"; pass=$((pass+1))
        else
            printf '  EMIT  %s\n' "$label"
            printf '        %s\n' "$(echo "$out" | grep -m1 -E 'error\[[A-Z0-9]+\]' || echo 'failed before emission, no Koru diagnostic')"
            fail=$((fail+1)); failures+=("$label — should emit, does not")
        fi
    else
        # "It failed" is NOT the assertion. A negative test that fails for the
        # WRONG reason — a typo, a renamed module, a missing tilde — scores as
        # a working wall, and the check then stays green straight through a
        # mass rename that broke every test. Measured: replacing a negative
        # test with a trivially-valid program still read as "refused".
        #
        # So match the diagnostic the test itself declares, using this repo's
        # existing `//~` directive convention:
        #     //~ compile_fail(backend)
        #     //~ error[KORU030]: Phantom state mismatch
        local want_code want_text
        want_code="$(grep -m1 -o 'error\[[A-Z0-9]\+\]' "$src" 2>/dev/null | tr -d '[]' | sed 's/error//')"
        # Only require message text when the directive actually supplies some.
        # `//~ error[KORU030]` with nothing after it pins the CODE and nothing
        # else, and that is a legitimate, weaker pin — treating the bare line as
        # required text made a correct test look like drift.
        want_text="$(grep -m1 '^//~ error\[[A-Z0-9]*\]: ' "$src" 2>/dev/null | sed 's/^.*\]: *//')"

        if [ $rc -eq 0 ]; then
            printf '  WALL  %s — THE WALL STOPPED BITING (compiles clean)\n' "$label"
            fail=$((fail+1)); failures+=("$label — must be refused, now compiles clean")
        elif [ -z "$want_code" ]; then
            printf '  ????  %s — refused, but the test declares no expected diagnostic\n' "$label"
            unverified=$((unverified+1)); unverifieds+=("$label — add a //~ error[...] directive")
        elif ! echo "$out" | grep -q "$want_code"; then
            printf '  WRONG %s — refused, but not for its own reason\n' "$label"
            printf '        wants %s, got: %s\n' "$want_code" \
                "$(echo "$out" | grep -m1 -oE 'error\[[A-Z0-9]+\][^\n]{0,70}' || echo '(no Koru diagnostic at all)')"
            fail=$((fail+1)); failures+=("$label — refused with the wrong diagnostic, wants $want_code")
        elif [ -n "$want_text" ] && ! echo "$out" | grep -qF "$want_text"; then
            printf '  DRIFT %s — right code, but the wording it pins is gone\n' "$label"
            printf '        pinned: %s\n' "$want_text"
            fail=$((fail+1)); failures+=("$label — $want_code fires but its pinned wording changed")
        else
            printf '  ok    %s (%s, as it must)\n' "$label" "$want_code"; pass=$((pass+1))
        fi
    fi
}

echo "Checking shipped lifts against $($KORUC --version 2>/dev/null | head -1 || echo koruc)"
echo

for d in unikraft/*/; do
    lift="$(basename "$d")"
    [ -d "$d/tests" ] || continue
    echo "$lift"
    shopt -s nullglob
    for t in "$d"tests/boot_*.kz;     do build_expecting "$t" ok    "$lift/$(basename "$t")"; done
    for t in "$d"tests/negative_*.kz; do build_expecting "$t" error "$lift/$(basename "$t")"; done
    for t in "$d"tests/negative/*.kz; do build_expecting "$t" error "$lift/$(basename "$t")"; done
    shopt -u nullglob
    echo
done

echo "────────────────────────────────────"
echo "$pass held, $fail broken, $unverified unverifiable"
if [ $unverified -gt 0 ]; then
    echo
    for u in "${unverifieds[@]}"; do echo "  ? $u"; done
fi
if [ $fail -gt 0 ]; then
    echo
    for f in "${failures[@]}"; do echo "  $f"; done
    exit 1
fi
exit 0
