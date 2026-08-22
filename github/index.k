// koru/github — the GitHub-side release surface for a Koru site.
//
// Pure Koru, front and center. This file is the contract: it declares the
// commands a site gets by importing this module, and the `github:repo` config
// tor a site fills in. Nothing here is Zig, and nothing here shells out.
//
// Companion `index.kz` holds the implementations (command procs that walk the
// AST and call `gh`/`npm`). This is the same split `koru/vercel` uses: `.k` is
// the contract, `.kz` is the plumbing.
//
// What a site gets by `import github`:
//
//     koruc site.k release      # tag + push a release, from the repo config
//     koruc site.k publish-npm  # ship the package declared in the site
//     koruc site.k ci           # run the declared build/test step graph
//
// The commands read their configuration from the AST — the source is the source
// of truth. Nothing needs to be passed on the command line for the common case.

import std/compiler
import std/build

// ============================================================================
// COMMANDS — floated by this import: `koruc <site> release | publish-npm | ci`.
// The Zig implementations live in the companion index.kz.
// ============================================================================

std/compiler:command.declare {
  "name": "release",
  "alias": "rel",
  "description": "Tag and push a GitHub release from the declared repo config"
}

[comptime|command]pub tor release {
    program: *const Program,
    allocator: std.mem.Allocator,
    argv: []string,
}

std/compiler:command.declare {
  "name": "publish-npm",
  "alias": "publish",
  "description": "Publish the npm package declared in the site"
}

[comptime|command]pub tor publish-npm {
    program: *const Program,
    allocator: std.mem.Allocator,
    argv: []string,
}

// ============================================================================
// REPO — declare the GitHub surface. Read by the `release` / `publish-npm`
// commands, so a site's release config lives in its own Koru, not a sidecar.
// ============================================================================
// - owner:      the repo owner (user or org), e.g. "korulang"
// - repo:       the repo name, e.g. "korulang_org"
// - package:    the npm package path, read by publish-npm (default: repo root)
// - tag_prefix: prefix for release tags (default: "v"); publish-npm reads
//               version from the package.json beneath `package`
// - npm_scope:  optional npm scope ("@scope") used by publish-npm
[comptime|norun] pub tor repo {
    owner: string,
    repo: string,
    package: ?string = null,
    tag_prefix: ?string = null,
    npm_scope: ?string = null,
}

// ============================================================================
// THE SHARED VOCABULARY — std/build:step + depends_on.
// ============================================================================
// `ci` is a built-in frontend verb, NOT a library command. It collects every
// std/build:step the program declares (across all imported modules — koru/github
// AND koru/vercel compose their steps here) and runs them in depends_on order.
// A site that wants to release declares its steps; ordering is the source of
// truth — declarations + depends_on, never CLI flags:
//
//     std/build:step(name: "build") {
//       ~koruc build
//     }
//     [depends_on(build)]std/build:step(name: "release") {
//       ~koruc publish-npm
//     }
//
//     koruc site.k ci    # build → release, topological order

