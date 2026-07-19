# koru-libs — read this before you touch anything

**These packages are NOT the product. The koru compiler is the product.**

Every package here — `vaxis`, `sqlite3`, `raylib`, `pq`, `curl`, `gzip`,
`docker`, `ai`, … — exists for ONE reason: to **exercise the koru toolchain and
surface its gaps**. The package is an instrument. The instrument-maker (the koru
compiler at `/Users/larsde/src/koru`) is what we ship. When a package hits a
wall, **the wall is a compiler gap, and that gap is the deliverable — not the
package building.**

## The priority, non-negotiable (this is the recurring failure)

Sessions here keep losing this and it has to stop. When you're building or fixing
a package and you hit a compiler / codegen error:

- **Fix the koru toolchain. NEVER route around it in the library.** Renaming a
  package's internal binding, adding a wrapper, a scope hack, a qualified import,
  a rebinding, "just avoid that name" — **any change to the *package* to dodge a
  compiler limitation is the banned route-around, even when it compiles.** A
  precedent elsewhere in the corpus using the same hack does NOT sanction it.

- **Nobody cares about a package's internal details.** A vaxis binding name, a
  local variable, an import alias — these are *nothing*. A good toolchain is
  *everything*. If the clean, obvious library code is correct and the compiler
  rejects it, **the compiler is the bug** — go fix it in `/Users/larsde/src/koru`.

- **"Unblock the library" is never a goal — and OFFERING it is the same
  failure.** Do not propose a library-side workaround to get a package green
  "for now / tonight / to unblock." There is no unblock-the-library branch. Even
  presenting it as one option in a menu is the priority inversion. The only move
  is: fix the compiler.

- **The milestone is an instrument, never the destination.** "Get vaxis green" is
  not a goal; it goes green on its own the day the compiler can express it. Nobody
  works ON the package — you work on the toolchain gap the package surfaced, in
  the toolchain's own terms (the missing language feature, diagnostic, or
  guarantee). If a plan reads "change the library so it builds," the frame is
  already inverted.

- **A green build earned by dodging the gap is a lie** about the toolchain the
  work existed to test — worth less than the honest red was.

## Where the truth lives

- Toolchain orientation + how to build/test: `.claude/skills/koru-libs-toolchain`.
- Language ground truth is the koru test suite
  (`/Users/larsde/src/koru/tests/regression`) — never synthesize koru syntax from
  analogy; read a passing test or label it a guess.
- Toolchain bug discipline: when you believe you've found a compiler gap, assume
  ~50% chance it's your own misunderstanding — **float it, don't route around it
  and don't solo-fix it.** Surface → decide together → fix in koru.
