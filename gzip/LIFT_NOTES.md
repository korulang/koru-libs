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
