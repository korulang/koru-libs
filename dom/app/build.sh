#!/usr/bin/env bash
# Build the benchmark app for the browser.
#
# The first thing this does is say WHICH COMPILER it is about to use, and stop
# if that is not the one you meant.
#
# The reason is a measured hour. `koruc` does not carry the standard library
# with it — /usr/local/lib/koru/koru_std and .../src are symlinks into one
# shared checkout, so a build here compiles against whatever branch that
# checkout is sitting on, and says nothing about it. On 2026-08-08 that
# checkout was on another session's branch, which predated a fix to how the
# store lowers a text-building write. The app built without a single warning,
# shipped a row whose text was the un-rendered template, and a full timing run
# reported the app 2.5x slower before the wrong output was noticed.
#
# Nothing in that chain was detectable from inside this repo, which is why the
# check is here and not in a habit.
set -euo pipefail

cd "$(dirname "$0")"

# /usr/local/lib/koru holds symlinks, one per piece; follow the stdlib one to
# find the checkout they all point into.
COMPILER_TREE="$(cd -P /usr/local/lib/koru/koru_std && cd .. && pwd)"
EXPECTED_BRANCH="${KORU_EXPECT_BRANCH:-main}"

branch="$(git -C "$COMPILER_TREE" rev-parse --abbrev-ref HEAD)"
head="$(git -C "$COMPILER_TREE" rev-parse --short HEAD)"

echo "compiler: $COMPILER_TREE @ $branch ($head)"

if [ "$branch" != "$EXPECTED_BRANCH" ]; then
    cat >&2 <<EOF

REFUSING TO BUILD — the compiler this machine uses is on '$branch', not '$EXPECTED_BRANCH'.

  $COMPILER_TREE is shared. Its standard library and compiler sources are what
  koruc reads, so a build from here inherits that branch's bugs and fixes with
  no diagnostic of any kind. A build against an unexpected branch is not a
  slower build or a louder build — it is a DIFFERENT PROGRAM that looks fine.

  Another session is probably working in there. Do not switch its HEAD.
  Wait for it, or set KORU_EXPECT_BRANCH=$branch if you meant this one.
EOF
    exit 1
fi

# SECOND HALF OF THE SAME TRAP, and the branch check does not see it: koruc is
# a COMPILED BINARY, and its sources are only half of what a build uses. The
# standard library under koru_std/ is read from disk at compile time, so a
# `git switch` updates it instantly; src/ is compiled INTO koruc and does not
# move until someone runs `zig build`. Land on a tree where those two disagree
# and the emitted backend calls into a compiler that does not have the function
# it is calling — which at least fails loudly, unlike the branch case, but
# fails somewhere that names neither cause.
#
# Measured immediately after the branch gate was built: bringing the checkout
# back to main gave a current koru_std/ against a koruc binary five hours old,
# and the app failed on `CompilerEnv has no member named 'library'` — a symbol
# from work that had landed in between.
KORUC_BIN="$COMPILER_TREE/zig-out/bin/koruc"
if [ -x "$KORUC_BIN" ]; then
    newer="$(find "$COMPILER_TREE/src" "$COMPILER_TREE/koru_std" -type f -newer "$KORUC_BIN" 2>/dev/null | head -3)"
    if [ -n "$newer" ]; then
        cat >&2 <<EOF

REFUSING TO BUILD — koruc is older than the compiler sources it is meant to be.

  $KORUC_BIN was built before these files changed:
$(echo "$newer" | sed 's/^/    /')

  koru_std/ is read from disk at compile time and is already current; src/ is
  compiled into the binary and is not. Run 'zig build' in $COMPILER_TREE first
  — but NOT while a regression suite is live anywhere on this machine
  (pgrep -fl "run_regression|zig build").
EOF
        exit 1
    fi
fi

dirty="$(git -C "$COMPILER_TREE" status --porcelain -- koru_std src | head -20)"
if [ -n "$dirty" ]; then
    echo "note: the compiler tree has uncommitted changes under koru_std/ or src/ —" >&2
    echo "      this build sees them, and they are someone's work in progress:" >&2
    echo "$dirty" | sed 's/^/        /' >&2
fi

koruc main.k build --lang=js

# The store's text-building write must arrive LOWERED. If a `{{ }}` survives
# into the output it becomes the literal text of every row, which is wrong
# quietly — the page renders, the row count is right, and only the label is
# nonsense. Cheaper to catch here than in a fifteen-minute timing run.
if grep -q '{{' <(grep -v '^//' output_emitted.js); then
    echo "" >&2
    echo "REFUSING THE OUTPUT — an un-rendered {{ }} template reached the emitted JS:" >&2
    grep -v '^//' output_emitted.js | grep -n '{{' | head -5 | sed 's/^/  /' >&2
    exit 1
fi

echo "built output_emitted.js ($(wc -c < output_emitted.js) bytes)"
