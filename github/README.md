# koru/github

The GitHub-side release surface for a Koru site. Importing `github` floats
release commands onto the **compiler**, so a site's release path is `koruc`
commands — not a sidecar CLI — and the configuration lives in the site's own
Koru, as the source of truth:

```koru
import github

github:repo {
    owner: "korulang",
    repo: "korulang_org",
    tag_prefix: "v",
}
```

```bash
koruc site.k release           # tag + push a GitHub release, from github:repo
koruc site.k release 1.2.0     # ... with an explicit tag on argv (convenience, not the spine)
koruc site.k publish-npm       # publish the package declared in the site
koruc site.k ci                # run the declared build/test/release step graph
```

The whole design inherits `koru/vercel`'s shape: the contract is `.k` (pure
Koru, the declarations), the implementation is `.kz` (the plumbing that walks
the AST and shells to `gh`/`npm`). You author the config; the reader walks the
AST. Nothing is CLI-passed for the common case.

## The shared vocabulary: `std/build:step` + `depends_on`

The ordering unit — shared with `koru/vercel` — is `std/build:step` plus a
`depends_on(...)` annotation. The compiler collects steps program-wide (every
imported module contributes), builds a dependency graph, and topologically sorts
it (cycles refused). So a library **declares** a step and the toolchain
**organizes** it.

`ci` is the shared verb that runs the graph. It is a built-in frontend verb,
NOT a `koru/github` command — so a site that imports both `koru/github` and
`koru/vercel` composes their steps with the same `depends_on(...)` edges and
runs the whole unit with one line.

```koru
import github
import std/build

github:repo {
    owner: "korulang",
    repo: "korulang_org",
}

// the ordering is declared, not scripted:
std/build:step(name: "build") {
    ~koruc build
}
[depends_on(build)]std/build:step(name: "release") {
    ~koruc publish-npm
}
```

```bash
koruc site.k ci    # build → release, topological order
```

## Layout

```
github/
  index.k    # the pure-Koru contract: commands + github:repo config tor
  index.kz   # the implementation: read config from AST, shell to gh/npm
  examples/
```

## Discovery

The commands need the Koru compiler and the standard library. Override with
env vars if they aren't at the default locations:

| var | default |
|---|---|
| `KORU_REPO` | `~/src/koru` |
| `KORUC` | `$KORU_REPO/zig-out/bin/koruc` |
| `KORU_STDLIB` | `$KORU_REPO/koru_std` |

## Status

- **`release` / `publish-npm`** — green end-to-end. They read `github:repo` from
  the AST and shell to `gh`/`npm`.
- **`ci` drives the step graph** — landed in the compiler (`koru` `main.zig`).
  A declared `[comptime|command]` used to hijack the whole build and return
  before the command dispatcher ran; `ci` is now special-cased so it drives the
  graph. A kebab-named command (`publish-npm`) also emits a valid Zig handler
  symbol (the emitter mangles, the dispatcher must too; the fix pins
  `310_124`).
