# The ladder — every framework on one machine, in one window

Four sessions of this work compared Koru against numbers **published from other
people's machines**, and called the result "the same class as Solid and Svelte".
That was not a comparison. It was a hedge with a table in it.

The reason was never principle. Hand-written vanilla JavaScript is plain source
and runs straight out of the benchmark checkout; every real framework needs
installing and building first. So the one reference that required no work was
the only one ever timed, and a caveat got written around the gap instead of the
gap being closed. Closing it took twenty minutes.

These are the raw results of doing that: six builds, nine operations, one window,
one quieted machine. Read them with `node ../ladder.mjs --results .` — it takes
the fast cluster rather than the median, for the reason spelled out in
`../read-timings.mjs`, and it flags any row whose baseline kept almost no
samples instead of printing it plain.

Versions are in the filenames and the table derives its labels from them, so a
stale version label cannot survive a re-run.

## ⚠ Read this before quoting the Koru column

**`korukeyed` is a build the compiler no longer produces.** It was compiled
before the `?!` fix landed in koru (`00341d7c`), which installs a guard around a
declined failure branch — including on this app's row-removal path. Rebuilding
today's app source with today's compiler emits that guard; the measured build
ran without it. So the Koru column here is a real measurement of a real program,
and that program is one commit behind the toolchain.

Removing a row is the operation affected, and it is also the Koru column's best
result. Re-measure with a current build before this table is quoted anywhere
public.

## Also honest

- Clearing a thousand rows kept **1 of 15** samples after the interference
  filter. That row is a busy moment, not a program; the reader says so.
- Selecting a row is 3.5 ms absolute. Ratios there (Svelte 2.0, React 3.8) are
  real but grainy — three decimals flatter them.
- 15 iterations. A 25-iteration run on the official harness supersedes this.
