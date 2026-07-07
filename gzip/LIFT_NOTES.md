# gzip — quality pass notes

**One-line pitch**: migrated `@korulang/gzip` to the current host-tag syntax, gave it its first-ever runnable test coverage, and fixed a real short-input compression bug the tests immediately surfaced.

**Entry type**: quality pass on `gzip`

**Author**: Claude (Sonnet 5), koru-libs lift-challenge contestant run, 2026-07-02

## What changed, and why

`gzip/index.kz` had zero `.kz` callers anywhere in the repo — the package's
claims were unverified. Two things were true before this pass:

1. Its three `~proc` declarations (`compress`, `compress-bytes`,
   `decompress`) were bare — no `|zig` host tag. Per the koru compiler's own
   `MUST_FAIL` test
   (`tests/regression/300_ADVANCED_FEATURES/370_VARIANTS/8211_bare_proc_call_site_fails/`),
   a bare `~proc` compiles fine right up until something actually *calls*
   the event, at which point KORU110 fires. `--check` on `index.kz` alone
   never triggered it (no call site inside the file), which is exactly why
   the break was latent: nothing had ever called this package.
2. There was **no test coverage at all** — the break wouldn't have been
   caught until someone tried to use the package for real.

Writing the first real caller surfaced a second, independent bug: the
output buffer sizing in `compress`/`compress-bytes` used
`c.compressBound(data.len)` alone, which bounds the raw deflate stream but
**not** the 10-byte gzip header + 8-byte trailer that `deflateInit2` adds
for the gzip wrapper (`windowBits = 15+16`). For inputs large enough that
compressBound's own slack absorbs the ~18 extra bytes, this is invisible.
For small inputs it isn't: `compressBound(5) == 18`, but compressing
`"hello"` needs 19+ bytes once the gzip wrapper is included, so `deflate()`
returned `Z_OK` (buffer full, not finished) instead of `Z_STREAM_END` and
`compress()` silently reported `"Compression failed"` for every short
input. Verified independently with a standalone zlib repro
(`avail_out=0`, `deflate_result=0` i.e. `Z_OK`, not `Z_STREAM_END`) before
touching the library, then confirmed the fix (`+ 18` bytes) flips it to
`Z_STREAM_END`.

Both are now fixed:

- `gzip/index.kz:72` — `~proc compress|zig { ... }`
- `gzip/index.kz:141` — `~proc compress-bytes|zig { ... }`
- `gzip/index.kz:194` — `~proc decompress|zig { ... }` (no buffer-sizing bug here — decompress already grows its buffer dynamically)
- `gzip/index.kz:83` and `:143` — `max_output = compressBound(...) + 18`

The README and the file-header usage comment also drifted from reality:
they documented `~import "$koru/gzip"` (the `$`-prefix import form is
explicitly rejected — see
`tests/regression/500_INTEGRATION_TESTING/540_VALIDATION/405_import_rejects_dollar_prefix/`),
dot-path calls (`~koru.gzip:compress`) instead of the working slash form
(`~koru/gzip:compress`), `compress_bytes` (underscore) instead of the
actual declared name `compress-bytes` (hyphen), and `e.msg`/`d.data` field
access on branches that are declared as bare `[]const u8` (`error
[]const u8`, `decompressed []const u8` — no `.msg`/`.data` fields exist).
All fixed to match what actually compiles.

## The quadrifecta self-audit

- **DX**: The happy path is three named branches (`compressed` /
  `decompressed` / `ok` + `error`) with no manual buffer management —
  `allocator.alloc`/`realloc`/`free` and the whole `z_stream` lifecycle are
  hidden inside the proc bodies. A caller never touches zlib's C struct.
- **Performance**: One-shot `deflate`/`inflate` with `Z_FINISH`, no extra
  copies beyond the final `realloc` down to actual size. Unmeasured against
  hand-written zlib C — the wrapper adds no runtime indirection beyond a
  single `@cImport` call, but no benchmark was run this session.
- **Correctness**: The negative-input test
  (`gzip/tests/malformed_input.kz`) proves non-gzip bytes are rejected via
  the `error` branch with a real message, never a silent wrong answer. The
  short-input compression bug found and fixed above is the correctness
  pillar's actual finding for this pass — it was silently *failing* (not
  crashing, not lying) on short inputs before the fix.
- **Resource safety**: See "Toolchain / design findings" below — this is
  the honest gap. There is currently no phantom-obligation surface to
  enforce.

## What it explicitly doesn't do (yet)

- No phantom obligation tracks the allocator-owned buffers `compress`,
  `compress-bytes`, and `decompress` return. See the finding below.
- No streaming API (chunked compress/decompress for large inputs that
  shouldn't be buffered whole) — out of scope for this pass, not attempted.
- Performance is unmeasured against raw zlib usage.

## Toolchain / design findings

**Finding (resource-safety pillar gap, not a compiler bug): gzip's public
API carries zero phantom obligations today.** `compress`, `compress-bytes`,
and `decompress` all allocate their output via the caller's allocator
(`gzip/index.kz` — `allocator.alloc(u8, max_output)` in `compress|zig` and
`compress-bytes|zig`; a growable buffer in `decompress|zig`) and return it
as a bare `[]const u8` in the success branch. There is no `free`/`dispose`
event in the public API, and the returned slice carries no phantom state —
unlike, say, `sqlite3`'s `*Connection<opened!>` / `*Statement<prepared!>`.
So there is nothing for the phantom checker to hold onto: a caller can
compress the same data twice and drop both buffers with zero compiler
complaint, even though both allocations genuinely leak.

This was pinned as `gzip/tests/no_obligation_pin.kz` and run for real — it
compiles and executes clean, which **is** the finding, mirroring the koru
compiler's own pinned gap for `std/io:read-file`
(`tests/regression/300_ADVANCED_FEATURES/335_OBLIGATION_STRESS/335_042_read_file_no_free/`):
a bare `[]const u8` surface is invisible to the phantom checker regardless
of which library produced it. The language *can* express this kind of
obligation — `330_068_phantom_obligation_on_primitive_string` shows a
`[]const u8<tag!>` obligation discharged by a matching `<!tag>` consumer —
gzip's API just doesn't use that mechanism today. Adding it is a real
follow-up (a new `free`/`dispose` event plus tagging the three success
branches), but it is a new API surface, which this pass's brief scoped out
("no new features"). Reporting it honestly per the brief rather than
inventing a negative test to satisfy gate 3.

**No compiler defects found.** Every rejection hit during this pass was a
correct, well-targeted diagnostic:
- KORU110 (bare proc, no `|variant` tag) — worked exactly as documented,
  fixed by adding `|zig`.
- PARSE005 (redundant explicit label when an arg already puns to the param
  name) — caught three separate spots in the first test draft
  (`data: c.data`, `original: original`, `msg: e.msg`) and told me exactly
  what to write instead. Good DX, not a finding.

## Proof of life

```
$ /Users/larsde/src/koru/zig-out/bin/koruc --check gzip/index.kz
✓ Shape checking passed

$ /Users/larsde/src/koru/zig-out/bin/koruc run gzip/tests/roundtrip.kz
...
Round-trip OK: 186 bytes -> 103 bytes compressed -> 186 bytes restored, byte-identical

$ /Users/larsde/src/koru/zig-out/bin/koruc run gzip/tests/levels_and_bytes.kz
...
[fast] round-trip OK: 123 bytes, byte-identical
[best] round-trip OK: 123 bytes, byte-identical
[compress-bytes] round-trip OK: 123 bytes, byte-identical

$ /Users/larsde/src/koru/zig-out/bin/koruc run gzip/tests/malformed_input.kz
...
Correctly rejected non-gzip input via error branch: "Decompression failed"

$ /Users/larsde/src/koru/zig-out/bin/koruc run gzip/tests/no_obligation_pin.kz
...
Both buffers dropped here - no free() exists, no phantom obligation, no compiler complaint.
```

All four commands run from the koru-libs repo root, using
`/Users/larsde/src/koru/zig-out/bin/koruc`.

---

# gzip — quality pass: the streaming lift

**Entry type**: quality pass on `@korulang/gzip`

**Author**: Claude (Opus 4.8, lift-challenge contestant, session 2026-07-03)

**Compiler**: `koruc 0.1.7` (koru @ `20479c55`)

## The pillar gap this pass closes

Before this pass, `gzip` shipped only a **one-shot** API (`compress` /
`decompress` / `compress-bytes`): the whole payload in, the whole payload out.
That API is honest but it exposes **zero** of Koru's type system — the entire
zlib `z_stream` lifecycle (`deflateInit2` … `deflateEnd`) is opened and closed
*atomically inside a single `~proc`*, so there is nothing to thread to the
caller and nothing they can get wrong. Measured against the four pillars, the
package failed two of them outright:

- **Resource safety (pillar 4): absent.** No phantom obligations anywhere in
  `index.kz` (0 obligation markers, vs. 30 in the `sqlite3` exemplar). Nothing
  for the compiler to enforce.
- **"Koru's type system has to do the lifting" (non-negotiable #2): failed.**
  The one-shot wrapper would port unchanged to Python or Go. It is a binding,
  not a lift.

The gap is not "the one-shot API is wrong" — it is that gzip never offered the
one operation where zlib genuinely needs a session type: **streaming**, where
the `z_stream` lives *across* calls and a finished stream must never be touched
again.

## Before / after

**Before** — `deflateInit2 … deflate … deflateEnd` all inside `~proc compress`.
The caller holds no handle; the type system is idle.

**After** — a session-typed streaming Deflater whose lifecycle the compiler
threads:

```
deflate.init    mints  <open!>                       (deflateInit2 ran; live, nothing fed)
deflate.push    needs  <!open|!fed>, mints  <fed!>   (feed a chunk)
deflate.finish  needs  <!fed>,       mints  <done!>  (deflateEnd ran)
deflate.release needs  <!done>                       (frees the Deflater)
```

The barrier is the distinct `fed` state, placed deliberately so that it is
**not** the state `init` produces. Two build errors fall out of that one
placement:

1. **Finish an unfed stream** — `init → finish`, never a single `push` — is a
   build error, because `finish` accepts only `<!fed>` and `init` hands you
   `<open!>`. RAII / Rust's `Drop` guarantees a resource is *cleaned up* but
   cannot force it to be *used*; the phantom obligation forces both, because
   discharge means "reach the state real work produces," not "run cleanup." It
   is the streaming twin of the enforced-lifecycle suite's transaction rule
   (`commit` accepts only `<!active>`, reachable only through `exec`, so an
   empty `BEGIN; COMMIT;` doesn't compile). An empty gzip stays expressible on
   purpose — `push("")` still reaches `<fed!>` — so the barrier rejects the
   *silent* no-op, never the intent.

2. **Push a finished stream** — because `finish` moves the handle to `<done!>`,
   calling `push` (which needs `<!open|!fed>`) afterwards is a build error too:
   a zlib use-after-free that only exists at runtime in C, made uncompilable.

## The quadrifecta self-audit

- **DX**: The happy path is a linear pipeline that reads like the operation it
  performs — `init → push → push → finish → release` — and the compiler names
  the next legal move if you stray. A newcomer never learns `windowBits = 15+16`
  (gzip vs. raw deflate), never sizes an output buffer, never calls
  `deflateEnd`. `deflate.release` hands back caller-owned bytes so the borrow
  from the internal buffer is resolved for you.

- **Performance**: The lifting is entirely compile-time — the phantom states are
  erased before codegen; the runtime is a thin pass over `deflate()` with a 16 KB
  stack scratch buffer draining into one growing `ArrayList`. That is the same
  shape you would hand-write against zlib; there is no per-call allocation of the
  stream and no runtime obligation bookkeeping. **Unmeasured** against a C
  baseline — I did not run a throughput benchmark, so I make no speed claim
  beyond "no runtime tax was added over a hand-written streaming loop."

- **Correctness**: Two misuses are uncompilable. An unfed stream cannot finish:
  `tests/deflate_finish_without_push.kz` fails with
  `error[KORU030]: Phantom state mismatch: expected 'libs.gzip:fed' but got
  'libs.gzip:open!' for argument 'd'` (plus a second line naming the fix:
  `Call: libs.gzip:deflate.push`). A finished stream cannot be reused:
  `tests/deflate_use_after_finish.kz` fails with
  `expected '!libs.gzip:open|!libs.gzip:fed' but got 'libs.gzip:done!'`.
  Round-trip correctness is shown by `tests/stream_roundtrip.kz`
  (streaming-compress → decompress recovers the original text),
  `tests/deflate_empty_via_push.kz` (the `push("")` escape hatch round-trips
  the empty string), and `tests/oneshot_roundtrip.kz`.

- **Resource safety**: The **ordering / use-after-free** dimension is enforced
  by the compiler (the negative test above proves it bites). The **leak on a
  forgotten `finish`/`release`** dimension is *not* statically enforced by the
  current compiler — see Toolchain findings. I state that plainly rather than
  claim a guarantee the toolchain does not yet deliver. The stream is small (one
  `z_stream` + one buffer) and every internal error path calls `deflateEnd` /
  frees before returning, so there is no leak on the *error* paths; the only
  un-caught leak is the caller simply walking away from an `<open!>`/`<done!>`
  handle.

## What it explicitly doesn't do (yet)

- **Streaming *decompress*** (an `Inflater` mirror of the Deflater). This pass
  ships streaming compression only; decompression is still one-shot. The
  `Inflater` is the obvious next quality pass and would reuse this exact
  session-type shape.
- **`gzip.release` does not tighten the `data` borrow.** `finish` returns
  `data` borrowed from the Deflater's buffer, valid until `release`. That borrow
  is not phantom-tracked (the `[]const u8` carries no obligation), so using
  `data` *after* `release` is not a compile error. Tracking slice borrows is a
  language-level feature, out of scope here.
- **README not rewritten.** `README.md` still shows the pre-migration import
  form (`~import "$koru/gzip"`, dotted `~koru.gzip:`). This pass migrated
  `index.kz` procs to the required `|zig` host tag and added the streaming API +
  tests; a full README refresh is a separate documentation pass.

## Toolchain findings

1. **The whole worktree predates the `~proc name|zig` host-tag migration
   (KORU110).** Every package here (`curl`, `docker`, `gzip`, `pq`, `sqlite3`,
   `vaxis`) uses bare `~proc name { … }`, which the current compiler rejects:
   `error[KORU110]: event 'open' is called but its ~proc declaration has no
   |variant tag`. The exemplar's own gate-2 command (`koruc run
   sqlite3/tests/basic.kz`) does **not** produce `Opened and closed!` against
   this compiler for that reason — it errors on KORU110. I migrated `gzip` (my
   target) to `|zig`; the other packages remain on the old form. Repro:
   `koruc run sqlite3/tests/basic.kz`.

2. **"Forgot to discharge" is not caught for the common case — the
   resource-safety pillar is softer than the catalog implies.** The phantom
   checker does *not* reject a top-level flow that mints an obligation and simply
   never discharges it, *when a discharge event exists*. Minimal repro (built
   clean, no error):

   ```koru
   ~event init {} | ok *Stream<open!>
   ~proc init|zig { … return .{ .ok = s }; }
   ~event finish { s: *Stream<!open> }        // a discharge event DOES exist
   ~proc finish|zig { … }
   ~init() | ok s |> std/io:print.ln("forgot finish")   // <open!> dropped — COMPILES
   ```

   It *is* caught only when **no** event anywhere accepts the discharge
   (`KORU030: … was not discharged. No event accepts <!x>`), or via the
   nested-secondary-obligation and loop back-edge paths. This matches the
   red-pin design gaps already in the koru suite
   (`335_040_subflow_drops_obligation_on_input`,
   `900_.../2104_05_commit_without_close`). Consequence for this challenge:
   negative tests should target **use-after-free / wrong-state** (which *is*
   enforced), not "forgot close" (which is not) — otherwise the negative test
   silently compiles and the "obligations bite" claim is hollow. My negative
   test targets use-after-free accordingly.

3. **Error message quality is good where it fires.** The wrong-state rejection
   is a clean, koru-level diagnostic naming the expected/actual phantom state
   and the argument — no raw Zig leaked through. No complaint there.

## Proof of life

```
$ koruc --check gzip/index.kz
✓ Shape checking passed

$ koruc run gzip/tests/stream_roundtrip.kz
The quick brown fox. The quick brown fox.

$ koruc run gzip/tests/oneshot_roundtrip.kz
hello hello hello world world world

$ koruc build gzip/tests/deflate_finish_without_push.kz
error[KORU030]: Phantom state mismatch: expected 'libs.gzip:fed' but got 'libs.gzip:open!' for argument 'd'
error[KORU030]: Resource 'd' carries obligation <open!> was not discharged. Call: libs.gzip:deflate.push
✗ Backend execution failed          # open-but-never-fed — the empty stream is uncompilable

$ koruc build gzip/tests/deflate_use_after_finish.kz
error[KORU030]: Phantom state mismatch: expected '!libs.gzip:open|!libs.gzip:fed' but got 'libs.gzip:done!' for argument 'd'
error[KORU030]: Resource 'd' carries obligation <done!> was not discharged. Call: libs.gzip:deflate.release
✗ Backend execution failed          # no executable built — the use-after-free is uncompilable

$ koruc run gzip/tests/deflate_empty_via_push.kz
                                    # one blank line — empty gzip round-trips via push("")
```
