# openssl — the definitive Koru OpenSSL edition (v0: message digests)

**One-line pitch**: OpenSSL's EVP hashing (SHA-256/512/1, MD5) with a phantom obligation that makes a forgotten `EVP_MD_CTX_free` uncompilable.

**Entry type**: new lift

**Author**: Claude (Opus 4.8, lift-challenge contestant, session 0b16745e)

## What the C library does, and what we lift

OpenSSL's `libcrypto` provides the battle-tested cryptographic digest
implementations the whole internet runs on. Its EVP digest API is a four-call
dance — `EVP_MD_CTX_new` → `EVP_DigestInit_ex` → `EVP_DigestUpdate`\* →
`EVP_DigestFinal_ex` → `EVP_MD_CTX_free` — with three classic footguns:

1. **The context leaks.** `EVP_MD_CTX_new()` heap-allocates a context you must
   free with `EVP_MD_CTX_free()`. Miss it on an error path and you leak on every
   hash. This edition attaches a `hashing` **phantom obligation** to the digest
   handle: the compiler will not let a program end while a digest is still open.
2. **Use-after-final is undefined behaviour.** Reading the digest before
   `EVP_DigestFinal_ex`, or calling `update` after it, is UB in C. Here `final`
   *consumes* the handle and never re-grants it, so touching it afterward is a
   build error.
3. **The algorithm is a runtime string.** `EVP_get_digestbyname("sha266")`
   fails at runtime. Here each algorithm is its own event (`sha256.init`,
   `sha512.init`, …) — a misspelled digest doesn't parse.

We wrap; we do not reinvent. Delete `libcrypto` and this package computes
nothing — every byte of hashing is OpenSSL's.

## The quadrifecta self-audit

- **DX**: The 90% case is one line — `~libs/evp:sha256.hex(input: bytes) |
  digest h |> …` — and hands you a ready hex string. The streaming path reads as
  a straight pipeline (`init → update → update → final.hex`); a newcomer never
  sees `EVP_MD_CTX`, never sizes an output buffer (`EVP_MAX_MD_SIZE`), never
  hex-encodes by hand, and never picks an algorithm by string.
- **Performance**: The lift is entirely compile-time — phantom states are erased
  before codegen, so the emitted Zig calls `EVP_DigestUpdate`/`EVP_DigestFinal_ex`
  directly with zero wrapper objects and no runtime obligation bookkeeping. The
  one-shot path emits a single `EVP_Digest` call. The only allocations are the
  `Digest` struct (one `page_allocator.create`) and the result buffer — the same
  allocations hand-written C would make. Cost vs. raw C: **unmeasured** (no
  benchmark harness run this session); the generated calls are 1:1 with the C API.
- **Correctness**: A forgotten finalize does not compile —
  `openssl/tests/negative/forget_finalize.kz` fails with `error[KORU030]:
  Resource 'd2' <hashing!> was not discharged. Call one of: final.bytes,
  final.hex`. Every algorithm is checked against its published NIST/RFC vector in
  `tests/algorithms.kz`, and chunked streaming is proven equal to one-shot in
  `tests/chunked.kz`.
- **Resource safety**: The `hashing` obligation is granted by every `*.init`
  event (`index.kz` — `sha256.init` etc., result `*Digest<hashing!>`), carried
  across `update` (consumes `<!hashing>`, re-grants `<hashing!>` so it survives a
  loop), and discharged **only** by `final.hex` / `final.bytes`
  (`index.kz` `final.hex|zig` / `final.bytes|zig`), which is where — and the only
  where — `EVP_MD_CTX_free` and `destroy(d)` run. The compiler proves the context
  is freed exactly once on every path; the `.init` procs `@panic` loudly on the
  impossible OOM case rather than falling back.

## What it explicitly doesn't do (yet)

- **Digests only.** No HMAC, no ciphers, no PKEY/signing, no random. v0 is the
  hashing slice; the package is named `openssl` because that identity is where it
  will grow (HMAC next — it shares the `hashing`-style obligation).
- **Four algorithms**: SHA-256, SHA-512, SHA-1, MD5. Adding SHA-384/224/SHA-3 is
  one `.init` event each. (SHA-1/MD5 are included because real code still needs
  them for legacy checksums, not as a security recommendation.)
- **No streaming error branch.** `update`/`final` `@panic` if OpenSSL returns
  failure. For built-in digests fed valid buffers this is unreachable; a hardened
  v1 would surface an `| err` variant.
- **Homebrew path is hardcoded.** The build block adds `/opt/homebrew` and
  `/usr/local` include/lib paths because macOS Homebrew's OpenSSL is keg-only. On
  Linux the system paths are already searched and these are harmless. A portable
  v1 should resolve these via `pkg-config`.

## Toolchain findings

1. **The brief's verified exemplar no longer compiles (shelf-wide staleness).**
   `koruc run sqlite3/tests/basic.kz` — cited in the brief as producing
   `Opened and closed!` — now fails:
   `error[KORU110]: event 'open' is called but its ~proc declaration has no
   |variant tag — bare procs are unresolvable`. The language gained a required
   `~proc name|zig` host tag after the brief and packages were written; the
   entire koru-libs shelf (every `~proc` in sqlite3/curl/gzip/… is bare) is red
   against today's compiler. Under koru's greenfield rule this is expected honest
   red (the old form *should* break), but it means the exemplar in the brief is
   stale and every existing package needs a `|zig` migration pass. This new lift
   is written in the current syntax and is unaffected.

2. **Stale `args: [...]` print form leaks a raw Zig error (bad-message defect).**
   The `std/io:print.ln("…{s}", args: […])` form shown in `ECOSYSTEM.md` is no
   longer the idiom (current is `{{ var:s }}` interpolation), but instead of a
   koru-level diagnostic it drips through to a host-level Zig compile error:
   `…/std/Io/Writer.zig:698:13: error: too few arguments` /
   `@compileError("too few arguments")`. Minimal repro (2 lines):
   ```
   ~import std/io
   ~std/io:print.ln("value={s}", args: ["hi"])
   ```
   The koru-level wall isn't built at this boundary — a user on the old idiom
   lands in generated Zig instead of being told "use `{{ value:s }}`."

3. **`@cImport` is load-bearing for koru-libs but exercised by zero passing koru
   regression tests.** `grep -rl '@cImport' tests/` in the compiler repo returns
   nothing. FFI + `linkSystemLibrary` works well (this whole package proves it),
   but nothing in the suite would catch an FFI regression. A coverage gap, not a
   bug.

4. **Praise — the error walls that guided this build.** `PARSE003` (single-field
   payload → "use identity syntax `| ok []const u8`"), `PARSE005` (redundant
   label → "drop the label, write `d` instead of `d: d`"), and especially
   `KORU030` (names the exact discharge events to call) are textbook
   pit-of-success diagnostics. They caught every mistake at the koru level.

## Proof of life

All commands run from the repo root against
`/Users/larsde/src/koru/zig-out/bin/koruc` this session.

**Gate 1 — `--check`:**
```
$ koruc --check openssl/index.kz
✓ Shape checking passed
```

**Gate 2 — every test compiles and runs end-to-end:**
```
$ koruc run openssl/tests/basic.kz
oneshot  sha256(abc) = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
stream   sha256(abc) = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

$ koruc run openssl/tests/algorithms.kz
sha256 = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
sha512 = ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f
sha1   = a9993e364706816aba3e25717850c26c9cd0d89d
md5    = 900150983cd24fb0d6963f7d28e17f72

$ koruc run openssl/tests/chunked.kz
oneshot = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad
chunked = ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad

$ koruc run openssl/examples/checksum.kz
fox     sha256 = d7a8fbb307d7809469ca9abcb0082e4f8d5651e46d3cdb762d02d0bf37c9e592
hello   sha256 = b94d27b9934d3e08a52e52d7da7dabfac484efe37a5380ee9088f7ace2efcde9
hello   sha512 = 309ecc489c12d6eb4cc40f50c902f2b4d0ed77ee511a7c7a9bcd3ca86d4cd86f989dd35bc5ff499670da34255b45b0cfd830e81f605dcf7dc5542e93ae9cd76f
```
All outputs match published SHA/MD5 test vectors.

**Gate 3 — the obligation bites (this MUST fail to compile):**
```
$ koruc run openssl/tests/negative/forget_finalize.kz
error[KORU030]: Resource 'd2' <hashing!> was not discharged. Call one of: final.bytes, final.hex
```
