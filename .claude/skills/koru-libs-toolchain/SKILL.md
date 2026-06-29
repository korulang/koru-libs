---
name: koru-libs-toolchain
description: Orientation map for the koru-libs project — what it is, how it builds/tests, where the source of truth and the canonical standard live, and the misconceptions that will bite an agent. Read this FIRST in any /arbiters walk, Scout, or Contestant run here. It is the EXISTING-scene instrument (fast clock, where you are); SCENE.md is the ideal scene (slow clock, where you're going). Points to tools; never duplicates them.
---

# koru-libs — orientation map

The **existing-scene** instrument for this repo. Terse by design: it *points*, it
does not duplicate. Pair it with `SCENE.md` at the repo root (the ideal scene) and
the ADD methodology in `.claude/ARBITER_DRIVEN_DEVELOPMENT.md`.

## What this project is

The official **ecosystem packages for the Koru language** — proven C/Zig libraries
wrapped behind Koru's type system (phantom obligations, compile-time validation).
Philosophy (from `ECOSYSTEM.md`): *don't reinvent — wrap excellent libraries and
expose them through Koru's types.* Packages publish to npm under `@korulang/*`.

Each package is a top-level dir: `ai`, `commander`, `curl`, `docker`, `gzip`, `pq`
(postgres/libpq), `sqlite3`, `vaxis` (TUI). `koru/` is a sandboxed interpreter tool,
not a wrapper lib. `examples/` exercises the libs.

A package = `index.kz` (the public API entry) + `tests/*.kz` + `package.json`
(`@korulang/<name>`, `koru.entry`) + `README.md`.

## The cross-repo links (the adjacency that matters)

- **`/Users/larsde/src/koru`** — the Koru **compiler + language + test suite**. This
  is the toolchain that *builds* koru-libs and the **source of truth for the
  language**. The link is hard and literal: lib `build_backend.zig` files hardcode
  `const REL_TO_ROOT = "/Users/larsde/src/koru"` and import its `src/*.zig`
  (`ast`, `type_registry`, `tap_registry`, `runtime_registry`, …). Move that repo
  and koru-libs stops building.
- **`/Users/larsde/src/korulang_org`** — the **website**, publishes the
  implementation status at <https://korulang.org/status>. Read-side consumer of
  koru's state, not a build input here.
- `prose whisper` / `wm` treat `koru` + `korulang_org` as the same neighborhood —
  orient across all three when walking.

## How it builds / tests

- The Koru compiler (built from the `koru` sibling) compiles a lib's `.kz` through
  to Zig, then `zig build`. The per-lib `build.zig`, `build_backend.zig`,
  `compiler_env.zig`, `program_ast.zig` are **generated artifacts** — see the
  untracked-files note below.
- `koru` is **not on PATH** in this environment — build it from
  `/Users/larsde/src/koru` first. **The exact `koru` invocation to build/test a lib
  is NOT yet verified in this skill** — confirm it in the `koru` repo (its CLI /
  `run_tests.sh` / regression harness) before quoting a command. Don't guess it.
- `npm publish --access public` from inside a package dir ships it (`files:` is just
  `index.kz` + `README.md`).

## The canonical standard (what's *legal* here)

koru-libs has **no CLAUDE.md / AGENTS.md of its own** — that is itself a finding.
The standard is inherited and documentary:

1. **The Koru test suite is law** (`/Users/larsde/src/koru/CLAUDE.md`: *"Ground
   truth is the tests, not this doc … the compiler wins and the doc is the bug"*).
   Never synthesize Koru syntax from analogy — read a passing `.kz` test or label
   it a guess.
2. **`ECOSYSTEM.md`** (repo root) — the package roadmap, priorities, and the
   wrap-don't-reinvent + phantom-type conventions every new package follows.
   (Dated 2025-01-16 — treat priorities as possibly stale; the code is truer.)
3. **Greenfield, zero users** — backward-compat is debt, not virtue; when the
   language moves, old forms should fail loudly. (Same posture as `koru`.)

Every Scout / Contestant must read #1 and #2 before judging a seam's premise.

## Things that will bite you

- **Untracked `*.zig` build files are generated, not abandoned.** `build.zig`,
  `build_backend.zig`, `compiler_env.zig`, `program_ast.zig`, `output_emitted`
  showing as `??` in `git status` are compiler output. Do **not** "clean them up"
  or commit them blindly — regenerate via the koru build. Check `.gitignore`
  before assuming.
- **The `/Users/larsde/src/koru` path is hardcoded**, not discovered. A different
  checkout location breaks the build until `REL_TO_ROOT` is repointed.
- **`koru` not on PATH** — there is no global koru binary here; it comes from the
  sibling repo's build output.
- **Two "koru"s:** the `koru/` *subdir* (an interpreter tool inside koru-libs) is
  not the `koru` *sibling repo* (the compiler). Don't conflate them.

## The ADD surface here

Seeded skills (project-owned, will diverge — garden them in-repo): `arbiters`
(the walk spine), `arbiters-challenge`, `arbiters-worldmodel`, `membrane` (the
git-log memory corpus the walk tends). `flash` is the pre-existing project-memory
skill. `SCENE.md` is **not yet planted** — author it on the first real walk.

**Membrane corpus = ONE shared family store** (decided 2026-06-29; wired same day).
The store is the **`koru-membrane`** sibling repo (github.com/korulang/koru-membrane)
— `concepts/` OKF files + the `commit-msg` enforcement hook live there. This repo
points at it via **`.claude/membrane.json`** → `{ "store": "../koru-membrane" }`;
so do `koru` and `korulang_org`. The pointer convention is documented in the
`membrane` skill (§"Where the store lives"). The hook lives only in the store repo,
not here. To tend memory: write `concepts/frag-<id>.md` in `koru-membrane` and
commit there with the lineage trailers. (koru/korulang_org carry the pointer but
need the `membrane` skill installed to actually tend it.)
