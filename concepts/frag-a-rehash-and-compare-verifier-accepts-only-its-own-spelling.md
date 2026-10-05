---
type: belief
id: frag-a-rehash-and-compare-verifier-accepts-only-its-own-spelling
provenance: `bcrypt/index.kz` verify — a real bcrypt-ruby `$2a$` digest failed Zig std's `strVerify` on a correct password
ts: 2026-10-05
---

# A verify-by-rehash-and-compare accepts only the format spelling its own hasher emits (belief)

Zig std's `std.crypto.pwhash.bcrypt` verifies a modular-crypt digest by
re-hashing the candidate password and `mem.eql`ing the two **strings** — all 60
chars, header bytes included. `strHashInternal` always renders `"$2b$"`, so
`strVerify` accepts exactly the spelling `strHash` produces and nothing else:
a bcrypt-ruby `"$2a$"` digest of the same password, same salt, same key schedule
compares unequal on byte 2 and returns `PasswordVerificationFailed`.

## The ruling

The `$2a$`/`$2b$` split is a version label, not an algorithm. The only
behavioural difference was a 2011-era crypt_blowfish sign-extension bug on
password bytes >0x7f, fixed in every implementation bcrypt-ruby has shipped for
over a decade — confirmed empirically: the once-campfire golden vectors verify
`pässwörd ☃` (a >0x7f password) under the `$2b$` algorithm. So a thin lift over
std's hasher is still obligated to normalize the version byte (`a` → `b`)
before delegating; the "stdlib already implements bcrypt" premise was true
about the math and false about the parser's strictness.

## Why it generalizes

Any verifier built as *recompute-then-byte-compare* bakes its emitter's
rendering choices into the acceptance set. When the ecosystem the package feeds
(Rails `has_secure_password`, `/etc/shadow`, bcrypt-ruby) writes a different —
but semantically identical — spelling, verify is broken in a way unit
roundtrips can never show: `hash`→`verify` is green by construction against the
same emitter. Only a foreign-produced known-answer exposes it. A lift whose
tests are all self-produced has not tested interop at all.

## Open edges

- `$2x$`/`$2y$` spellings are rejected (return `false`); bcrypt-ruby accepts
  them. Widen the normalization if a caller ever needs it.
- The `$2a$` sign-bug population (pre-2011 crypt_blowfish digests over >0x7f
  passwords) is genuinely unverifiable under the fixed algorithm — accepting
  `a` trades that dead corpus for the live Rails one, deliberately.
