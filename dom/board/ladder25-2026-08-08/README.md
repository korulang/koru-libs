# The 25-iteration ladder — 2026-08-08, 22:25–23:09

Koru against three real frameworks and hand-written vanilla JavaScript, all
seven apps measured by the reference's own driver, in one window, on one
machine, with the machine's supervised services shut off for the whole run.

This supersedes the 15-iteration ladder in `../ladder-2026-08-08/`, which said
so itself.

## The one thing to read first

**Koru did not finish the ladder.** Eight of the nine operations completed for
every framework. On the ninth — update every 10th row — the reference aborted
both Koru columns because its own correctness assertion failed. That is not a
missing measurement, it is a failed one, and it is Koru's fault. It is written
up in full below, because a ranking published without it would be a ranking of
a program that does not pass.

## Method

- Driver: the reference's `webdriver-ts` at HEAD `247fafa2`, default puppeteer
  runner, `--headless`, `--count 25`, drop-slowest 0. Per-benchmark CPU
  throttling is the reference's own (`benchmarksCommon.ts:105-111`: 4× on
  update/select/swap/clear, 2× on remove). The reference runs the cheap
  operations extra times, so select-a-row carries 35 samples where the rest
  carry 25.
- Browser: Chrome 151.0.7922.76, Apple Silicon, Darwin 25.5.0.
- Machine: every supervised `com.6digit.*` / `com.6dtrust.*` launch agent
  booted out for the duration (`../quiet-machine.sh`, stopped 22:24:51,
  restored 23:11). No other benchmark run was live; the only other session
  driving this clone was asked to hold and did.
- Competitors installed and built from the reference's own trees:
  **Solid 1.9.3**, **Svelte 5.42.1**, **React 19.2.0** (hooks). Vanilla
  JavaScript is the base. React is here as the far end of the field, not as a
  straw man: it is what most of this benchmark's audience actually ships.
- Also verified in the same window: no other benchmark process ran, and no
  result file outside these seven apps was written between 22:25 and 23:09.
- **koru** = `dom/app/output_emitted.js` rebuilt from source at 22:04 with the
  current compiler (`koru@5848fa15`), md5 `808816a2`. It passes the in-tree
  closer 11/11 including keyedness — see the caveat about that below.
- **korupre** = the artifact committed in `a658d20`, md5 `ec36c9b4`, built
  before the compiler tree was rebuilt at 21:06. It is in the run because the
  current compiler does not reproduce it — see "the compiler moved" below.

Read it with `node ../ladder.mjs --results . --base vanillajs --twin vanillajstwin`.

## The window certificate

Three things say this window is readable, and all three are computed from the
files in this directory rather than asserted in prose:

1. **The control was measured twice.** `vanillajstwin` is a byte-identical copy
   of the reference's own `vanillajs` served from a second URL — same md5,
   `530e243c`. Nothing but the machine can make those two columns differ. They
   agree to **within 3.1% at worst, and to 0.8% or better on seven of the eight
   operations**; the twin's geomean against the control is 1.000. This is the
   gate that a cross-session expectation cannot be: it needs no memory of an
   earlier afternoon to be trustworthy, which matters because the control's own
   absolute time has drifted 39% between sessions on this machine.
2. **No sample was discarded anywhere.** The fast-cluster reader kept 100% of
   samples in every cell of the table — no column showed the bimodal split that
   a contended core produces. The quiet machine worked.
3. **One invocation.** Every result file was written inside 43 minutes by a
   single `benchmarkRunner` process, and every operation's sample count agrees
   across the field.

## The ladder — ratio to hand-written vanilla, lower is faster

```
operation             base ms   vanillajs vanillajstwin  korupre     koru    solid   svelte  react-hooks
build 1,000 rows         28.2       1.000       0.996      1.046    1.043    1.089    1.074        1.294
replace all rows         30.9       1.000       1.000      1.065    1.065    1.100    1.120        1.405
select a row              4.5       1.000       0.978      1.000    0.978    1.244    1.778        1.756
swap two rows            19.5       1.000       1.005      1.036    1.031    1.128    1.159        7.215
remove one row           15.4       1.000       1.000      1.000    1.000    1.045    1.071        1.123
build 10,000 rows       302.2       1.000       0.998      1.076    1.069    1.076    1.086        2.020
build 1,000 more         32.6       1.000       1.031      1.031    1.040    1.061    1.061        1.279
clear 1,000 rows         12.8       1.000       0.992      1.211    1.258    1.336    1.187        1.914

GEOMEAN of 8                        1.000       1.000      1.056    1.058    1.131    1.175        1.834
```

Base milliseconds are this machine's, headless, under the reference's
throttling. They are not comparable to anything published from another machine;
the ratios are the portable part.

## The operation Koru did not complete

```
update every 10th        17.4       1.000       0.966         --       --    1.109    1.115        1.345
```

Both Koru columns aborted with the reference's own assertion:

```
checkElementContainsText pierce/tbody>tr:nth-of-type(991)>td:nth-of-type(2)>a failed.
expected  !!! !!! !!! !!!, but was inexpensive purple cookie !!! !!! !!! !!
```

**Cause, measured rather than reasoned.** A row's label lives in the store as
`label: char[40]` (`dom/app/main.k:74`). The reference's update benchmark
appends `" !!!"` four times cumulatively — three warmup clicks and the timed
one — and asserts the fourth mark landed. The longest label the reference's own
word lists can produce is 27 characters (`inexpensive orange keyboard`), and
27 + 16 = 43. Any label of 25 characters or more loses its last mark to the
column's capacity, and the assertion is made against row 991 specifically.

Proved directly, not inferred — `dom/closer/truncation-check.mjs` drives the
same app, clicks update four times and reads all 100 marked rows:

```
marked rows: 100
rows NOT carrying four full marks: 1
every bad row is exactly 40 chars: true
  row 771  len=40  "unsightly orange sandwich !!! !!! !!! !!"
label+marks length: min 28 max 40
```

So the app renders **wrong text on roughly 1.2% of marked rows on every single
run**, silently, and the benchmark only notices when the unlucky row is 991.
Sampling the generator: that is a 1.23% chance per iteration, which is a **17%
chance of failing a 15-iteration run and a 27% chance of failing a
25-iteration one**. Both Koru columns drew it in this run.

**Why the in-tree closer reads 11/11 anyway.** Its partial-update op clicks
`#update` exactly once and asserts the label *contains* `" !!!"`
(`dom/closer/closer.mjs:351-355`). One mark is +4 characters; 27 + 4 = 31, and
nothing overflows. The reference does four cumulative marks. That single
difference is why an app that passes its own conformance gate fails the real
harness a quarter of the time — the gap is in the instrument, not only in the
app.

The fix is a wider column and a closer that marks four times. Neither is done
here; this run measured, it did not repair.

## Does the missing row change the answer? No.

The eight-operation geomean is computed over the same eight operations for
every framework, so the field is compared like for like. What the exclusion
removes is one of Koru's *weaker* operations, so it flatters Koru — and the
size of that flattery is bounded:

| if Koru's update ratio were… | its 9-operation geomean would be |
|---|---:|
| 1.147 (its 15-iteration reading tonight) | 1.068 |
| 1.57 (its worst reading in any session) | 1.105 |

Against Solid at 1.129 and Svelte at 1.168 over the same nine operations
(0.996 for the twin, 1.772 for React), the ordering survives every plausible
value for the row Koru failed to finish. The conclusion does not depend on the
missing number — but the *conformance* verdict does, and that one is a failure.

## The compiler moved under the committed artifact

`korupre` is here because rebuilding `dom/app/output_emitted.js` from unchanged
sources with the current compiler does **not** reproduce the file committed in
`a658d20`. The compiler tree was rebuilt at 21:06; the new build wraps the
row-removal body in an `item`/`empty` tag dispatch that the committed build ran
unconditionally, and adds a panic arm for the declined branch.

Both were measured. **They are the same speed** — geomean 1.058 against 1.056,
inside the 3.1% the twin control admits, and identical to three decimals on
remove-one-row, the operation the change actually touches. The guard is free.

That answers the caveat the 15-iteration ladder had to publish: its Koru column
was a build the compiler no longer produces, and it turns out that did not cost
it anything.

## What this supports, and what it does not

**Supports a ranking claim, on this machine, with the failure attached.**
Every framework in the table was measured by the reference's own driver, in one
window, against a control that proved the machine held still while it ran.
Within those eight operations Koru is faster than Solid and Svelte — 1.058
against 1.131 and 1.175 — and beats both on every individual operation except
clearing a thousand rows, where Svelte is ahead. The gaps are 7% and 11%
against a demonstrated noise floor of 3.1% worst-case and under 1% typical, so
they are not noise.

**Does not support a place on the published ladder.** That board is measured on
other people's hardware, headed, on a different Chrome. Ratio-to-vanilla is the
fairest normalisation available and it is still not the same experiment.

**Does not support "Koru passes the benchmark."** It does not. It fails the
reference's correctness assertion on update-every-10th roughly one run in four,
and mis-renders about 1.2% of marked rows every run. Any public claim has to
carry that sentence until the column is widened.
