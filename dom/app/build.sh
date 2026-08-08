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
