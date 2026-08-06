---
type: belief
id: frag-a-migration-that-greps-code-leaves-the-teaching-surface-lying
provenance: the 2026-08-03 syntax migration fixed every .kz in koru-libs and left both LIFT exemplar READMEs teaching three retired spellings; third instance of the same shape in one session
ts: 2026-08-05
---

# A syntax migration greps the code and leaves the prose lying — and a generator's cited exemplars are inputs, so the lie gets replayed (belief)

A language migration is scoped by file extension. Someone greps `*.kz`, fixes
every hit, runs the suite green, and lands it. The prose is `*.md`, so it is not
in the sweep, and nothing goes red — **documentation has no build**. The code is
now correct and the teaching surface still teaches the dead spelling.

Measured 2026-08-05, three instances in one session, all from migrations that
landed weeks apart:

- `koru-os/FINDINGS.md` and `tests/.../embedded_blinky/results.md` both recorded
  cross-compilation as a real toolchain gap. It was not: the probes wrote
  `std.build:config` with the dot namespace retired by `5f41236f`. Two months of
  a "compiler blocker" that was a stale spelling copied out of a stale note.
- `koru-libs` migrated every `.kz` on 2026-08-03. On 2026-08-05, `sqlite3/README.md`
  still opened with `~std.package:requires.npm`, `~import "$koru/sqlite"` (dot
  namespace, `$`-prefix import, **and the wrong package name**), and
  `~koru.sqlite:open(...)`.

## Why the generator makes this worse than ordinary rot

Stale prose that a human reads is a nuisance. Stale prose that a **generator
cites as an exemplar is an input**, and inputs are replayed.

`LIFT_CHALLENGE.md` tells every contestant, in its non-negotiables, *"never write
syntax you haven't read in a passing test"* — and then its toolkit table points at
`sqlite3/index.kz` as "the exemplar's house style." A contestant who reads the
neighbouring README instead, which is the natural thing to do first, copies three
retired spellings into a new package. The brief is a standing generator, so that
is not one bad artifact; it is every future one until someone notices.

The same README also documented a **row-iteration flow that does not pass** —
`tests/query_parameterized.kz` is red and says so in its own header. So the
exemplar was teaching both dead syntax and an unproven shape.

## The catalog counted claims, not artifacts

A second face of the same disease. `LIFT_CHALLENGE.md`'s frontmatter read
`catalog: '*/package.json'`, and the registry counts catalog entries as replay
depth. `commander/` had a `package.json` declaring `"koru": {"entry": "index.kz"}`,
a README documenting an API, a `tests/` holding two build artifacts and no test
sources — and **no `index.kz` at all**. A manifest and a README for code that was
never committed, counted as a shipped lift.

A manifest is a *claim*. The entry file is the *artifact*. Key the catalog on the
artifact and the ghost stops counting. (Changed to `*/index.kz`; `commander/`
removed.)

## What follows

- **Migrate prose in the same commit as code, or the migration is half-done.**
  The sweep is `*.kz` *and* `*.md`. There is no build to catch the second half,
  which is exactly why it needs to be in the same act rather than queued.
- **A generator's cited exemplars are part of the generator.** Anything a brief
  names in its toolkit — an exemplar file, a README, a triage shelf — is an input
  that gets replayed. Those files earn a gate the way the code does; a doc-lint
  over cited exemplars would have caught all of this.
- **Key a catalog on the artifact, never the manifest.**
- **Check ownership before migrating a name.** `koru/README.md` shows
  `~println(text: "Hello!")` and reads exactly like rot — `println` was removed
  from `std/io` and subsumed by `print.ln`. It is *correct*: `koru/koru.kz:34`
  defines the package's **own** `~pub tor println`, registered into the
  interpreter's capability scope at `:44`. A blanket regex fix would have broken a
  working example while "cleaning up." The grep finds spellings; only the source
  says who owns the name.

## Open

- Nothing enforces this. A `scripts/` check that greps `*.md` for retired
  spellings — dot namespaces, `$`-prefix imports, `~event`, bare `println`
  outside packages that define it — would turn the whole belief into a wall. It
  needs the ownership exception above, which is why it is not a two-line grep.
- How much of the *fleet's* prose is in this state? Only koru-libs was swept here.

## Sharpened same day: it is not prose that rots, it is prose about what you did not change

Cutting the stale passages surfaced a clean discriminator between notes that age
well and notes that turn into lies, and it is not length or age.

`docker/LIFT_NOTES.md` and `curl/LIFT_NOTES.md` both discuss the KORU110 host-tag
migration and both read fine years later, because they describe **what that pass
changed**: *"Fixed by tagging all four with `|zig`."* Past tense, about its own
work, closed. Nothing another session does can falsify it.

`gzip/LIFT_NOTES.md` discussed the same migration and had rotted into three
falsehoods, because it described **the state of things it did not touch**:

- *"The whole worktree predates the migration… Every package here uses bare
  `~proc name { … }`… `koruc run sqlite3/tests/basic.kz` does **not** produce
  `Opened and closed!`."* Run 2026-08-05: it prints `Opened and closed!`.
- *"README not rewritten. `README.md` still shows the pre-migration import
  form… a full README refresh is a separate documentation pass."* The README was
  rewritten in the same session that found this note.
- A paragraph cataloguing README drift that had since been fixed.

Every one was **true when written**. Each became false when someone else did the
work it was describing — and none of them had any way to notice.

So the rule is not "delete old notes." It is:

- **A writeup may describe what it changed. It may not describe what it left
  alone.** The first is a closed record; the second is an uncheckable assertion
  about a moving repo, and it will be wrong before anyone reads it.
- **A deferred TODO in prose is the worst case of this**, because it is a claim
  about the future state of work someone else will do. "X is still broken, a
  separate pass" is false the moment that pass lands, and the person who lands it
  has no reason to grep notes files.
- **"Preserving the record" is not a reason to keep it.** Git holds the record,
  losslessly, and the working tree is a *context surface* that agents and humans
  read as current. Prose kept for history in a live file is not history; it is
  a lie with a timestamp, and it costs more than it preserves. (Lars, 2026-08-05,
  overruling exactly this instinct: *"falsifying the record is not a problem
  compared to poison context, git remembers."*)
