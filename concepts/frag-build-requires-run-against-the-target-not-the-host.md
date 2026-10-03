---
type: belief
id: frag-build-requires-run-against-the-target-not-the-host
provenance: orisha twobox re-run, 2026-10-03 — korulang-site could not cross-compile
  for x86_64-linux-musl because openssl's requires block emitted this Mac's
  Homebrew prefix into a target that has no Homebrew
ts: 2026-10-03
---

# Build requires run against the target, not the host (belief)

A `~std/build:requires` block is spliced into the consumer's emitted
`build_output.zig` and executes with the *target* in scope — but nothing stops
it from being written as if the build host's filesystem were the target's.
`koru/openssl` shipped exactly that: an unconditional Homebrew prefix plus
`linkSystemLibrary("ssl"/"crypto")`, correct for native macOS and fatal for
every cross-compile, because it is applied on import, not on use.

The trap is that the failure surfaces far from its cause. The consumer that
broke (`orisha`'s pump, via an unconditional `~import koru/openssl`) never
calls into the package for a plain HTTP site — TLS config is what pulls the
symbols in. Zig's lazy analysis already makes "imported but unused" free at
the *code* level; the requires block re-charged it at the *link* level.

The condition that makes both honest is target-gating on both sides:

- the package emits link/include requirements only where the target can
  actually provide them (`target.result.os.tag`, `abi`), and
- the consumer wraps every use of the package in the same comptime condition,
  so a target with no openssl analyzes zero TLS code and a user who asks for
  `tls_port` there gets a named error instead of a linker message about the
  wrong architecture.

Two subtleties measured on the way through: the gate's dead branch still
counts for `pointless discard` (`_ =` on a param used in the live branch
errors even when the discard sits in the dead one — a real reference like
`doNotOptimizeAway` is required), and a `.kz` `~proc` body splices into its
caller, so the gate must be spelled `$mod.HAS_OPENSSL` there.

Open question: `pq`, `curl`, `pcre2`, `gzip`, `evp` carry the same
host-assuming pattern (pq gates include paths on host `builtin.os.tag`, which
answers the wrong question for cross-builds). They are unfixed — the pattern
is proven on openssl, not yet propagated.
