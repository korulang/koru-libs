# Walk the garden — Phase 0 (always first)

This is where every run begins, and it is the one rigidity in an otherwise loose
method: **the walk happens first, every time.** Not as a procedure to march
through — as a conversation. You and the human walk the garden together, glance
at where you've been, name what kind of day it is, and hold the day against the
scene before a single subagent is spawned. ARBITERS is plural on purpose: it is
the two of you walking and judging together. Scouts and contestants are whistled
up *from* this walk and report *back* to it — they serve the walk, they never
replace it. That is the whole reason the method returns here between every phase
and refuses to run headless: the conversation is mandatory, and a cold subagent,
blind to it and grounded in present code, structurally cannot do what these four
moves do.

The walk has four moves. Read them as a single continuous exchange, not a
checklist. Keep it light; the point is to agree *what kind of day this is* before
you spend a single subagent.

**Before you take a step: the walk is conversational, one move at a time.** This
is where the spine's top rule ("Conversational, first and foremost") bites
hardest, because the walk is the most tempting place to break it. The failure is
**author-and-present**: you read `prose` and the scene, then emit a finished
read-back — a full state-of-the-garden, a ranked menu of directions, a drafted
scene — and ask the human to ratify it. That is not a walk; it is you handing them
a document. A walk is you saying *one* thing and listening, then the next thing.
The human's words drive; you build on what they actually said. If you are about to
emit a wall — even a well-made wall of options — STOP and say the single next
thing instead.

## 1 · Orient — glance at the past (`prose`) and the world (`wm`)

`prose` is the orientation instrument — the past axis, the existing-scene
read-back at session scale. Look for the last baton in **ONE pass**. The direct
read is `prose baton` — it returns this project's latest handoff straight from the
vault, durable across `/clear` and free of the self-collision below (it reads the
structured store, not transcript text). `prose snap` then gives the tail of the
previous session for the surrounding texture (a real baton is its final lines);
one `prose grep "↪ HANDOFF"` is the last-ditch backup.

Depth-dial by how long it's been: `prose snap` (today) → `prose gossip` →
`prose standup` (gone a week). Reach further only as you're more lost; don't open
with the heavy instrument on a session you left an hour ago.

A **real baton** has filled-in content — a concrete position, a real `next:` —
and **no `<…>` placeholders**. Skill text and design-discussion are NOT batons
(the `↪ HANDOFF` marker self-collides because this very skill documents it; a
grep hit inside skill prose is noise, not a position).

**Finding no baton is normal** — first run, or only noise. Say "no prior baton —
fresh start," glance at repo state, and walk on. Hunting for a baton that doesn't
exist is itself the drift: it pulls you into archaeology when the honest move is
to start fresh.

`wm` is the second orientation instrument — the world axis, the
where-do-the-models-stand read-back at instrument scale. Where `prose` reads the
journals (where the *conversation* left off), `wm` reads the run records (where
the *instruments* left off): both are pure readers, instant, and safe at session
start precisely because neither runs anything. One pass: `wm top` prints a ranked
board, one line per governed repo, worst first. Stand in a repo for that repo's
line; `wm top ~/src` for the whole ecosystem; drill into any repo with `wm tree`
to see which instruments are green, red, or **dark** (they exist but have never
run).

Read the board the way you read the baton — a glance, not an audit. A line that
is `green` and fresh is a world you can stop thinking about; `red`, `dark`, or
`stale` is the world asking for attention, and a board carrying a lot of it is
itself the signal that **today may be a World-model day** (move 2). A mostly-dark
or stale board is **normal early** — instruments get authored faster than they
get run; it reads "we haven't looked," not "something broke." Let it color the
day you're about to name; don't act on it here. The walk never runs anything (you
are the live session, so `wm run` would refuse anyway) — running instruments is
the World-model door's work, not the walk's.

## 2 · Name the day — the five doors

One short exchange with the human: *what kind of day is this?* The answer routes
the rest of the run. There are **five doors**, and they sit on one axis — the
breath, from hard inhale to hard exhale (the cauldron; see
`ARBITER_DRIVEN_DEVELOPMENT.md`). Two are the rare, effortful **rims**; three are
the common, daily **basin**:

- **Muse** *(inhale rim — rare, hard)* — you're (re)deriving *what you're even
  building*, the product or a stretch of its journey. → **dream first: route to
  `muse.md`, then ground.** A Scout fanned out on a vision day faithfully reports
  the repo as it *is* and quietly drags you back to whatever was built last — the
  wrong instrument for an open question.
- **Tactical** *(basin — common)* — you roughly know the terrain and want the best
  next *move* in it. → ground first: route to `scout.md`, then commission and
  contest.
- **Generative** *(basin — common)* — replay a standing challenge; the catalog
  grows. → route to `challenge.md`. The work is already decided and re-grounds
  itself; a session is productive in one move, no derivation needed. This loop can
  spin many times — the basin ripple.
- **World-model** *(basin — common)* — tend or extend the instrument regime:
  replay a chain stage (hunt / float / rules), build one named instrument, or
  run the tending loop on data that arrived since last time. → route to the
  `arbiters-worldmodel` skill. Like Generative, the work re-grounds itself —
  the catalogs, the calendar, and the move-1 `wm top` board decide what's due
  (red, dark, or stale is the world asking to be tended); a session is
  productive in one move.
- **Gardener** *(exhale rim — rare, hard)* — drowning in red, far from releasable,
  time to consolidate. The *whole* session is tending: prune, tighten, promote,
  pay down debt — **no building today.** → route to `gardener.md`.

Two routing notes:

- **`/arbiters <focus>` named a concrete task** → you already have the path; a
  quick Scout to ground the focus is fine, then commission. A pivot is still
  allowed.
- **A `↪ HANDOFF` names an obvious continuation** → offer a *one-line* choice:
  "continue *<that thread>*, or walk somewhere new?" Don't assume the
  continuation; the human may have woken up wanting a different bed.

**Either rim, gauge-routed — and the Gardener door is the guardrail.** You climb
whichever rim the day calls for: vision gone stale → Muse; exhale overdue →
Gardener. The method leans inhale — Muse, Scout, and Challenge all *make more* —
so the exhale is the one that never gets invoked, and that is the whole source of
the polish/release headache. The fix is structural and cheap: **the Gardener door
is simply present on this menu, read every walk.** Naming it here, every time, is
the nudge — over-exhaling is impossible, but over-*inhaling* becomes a *choice you
saw*, not an accident you backed into. It invites, it never gates (you can always
drop back into the basin). Later a live exhale-debt gauge will make this door
*glow* when you've held your breath too long; for now its mere presence on the
menu is the keystone.

The canonical phrasing still holds: *you dream before you ground.* A bare
`/arbiters` on an open day is **not** "fan out now" — it is Muse before Scout. The
on-ramp's #1 failure mode is sprinting straight to Scout; the fork is the gate
that stops it.

## 3 · Hold the scene — open `SCENE.md` (repo root)

Open `SCENE.md` at the repo root and check the day against it. **This replaces the thin
old "north star pointer."** SCENE.md is not a doc *about* the garden — reading it
*is* stepping into the garden: the felt, hand-walkable ideal scene, with whatever
it has **grown to hold** — perhaps a north star, ideal user(s), the feeling, loose
directions, refusals. Those are growths, never fields: a scene is co-derived one
line at a time, a thin honest seed is a complete scene, and grilling the human to
fill in a "missing" part is the template-reading failure (`scene.md`). One garden,
many beds — a session picks which bed it's walking; name that bed out loud now.

Holding the scene is the **Orient hat** doing its real work. Momentum — almost
always *whatever was built last* — pulls every run toward the repo's center of
gravity. Saying the scene aloud and checking the named day against it is how you
catch that pull before it becomes the run. A subagent, blind to the conversation
and grounded in present code, structurally cannot do this; only you and the human
can.

A cherry blossom falls and the falling is part of the beauty — red is
appreciated, nothing in the existing scene is precious, and a day that abandons
the old form is the job working, not a loss.

Read-many, write-rarely: you read SCENE.md on every walk; you almost never edit
it here. Mutating the scene is the Gardener's slow-clock act (`gardener.md`), not a
move you make mid-walk. And SCENE.md never leaves the walk — scouts are handed the
**ideal user**, never this file. If a project has only a thin honest stub ("no
north star yet — here is the seed"), that is fine to walk against; it beats a
faked-complete scene, and it tells you the day might be a Muse day to grow it.

## 4 · The pull-feedback valve — test external signal against the scene

Before you route onward, pull the external signal waiting at session start:
website feedback, stakeholder resonance, Discord. Each item is a **candidate, not
a command** (tenet 7) — it enters here, gets tested, and is arbitrated by the two
of you on the walk. It may *argue* for mutating the scene; it never silently
*becomes* it.

The test is **scene-relative, not codebase-relative**, and the distinction is the
entire point of the valve:

- "Does this fit the codebase?" says yes to almost anything, because the codebase
  is permissive.
- "Does this pull toward the ideal scene?" catches the well-meaning item that
  fits the code but fights the scene — a `Result` type, a happy-path branch:
  implementable, reasonable, and a direct contradiction of "branches are equal,
  no happy path." Those are exactly the items to surface and arbitrate, usually
  to reject.

When the stakes warrant, send a scout to test each item scene-relative (served
the ideal user, never SCENE.md) and report which items fit the code but fight the
scene. The scout flags; the two arbiters decide. A scout cannot catch a bad
commission and it cannot make this call either — surfacing is its job, picking is
yours.

Discord and stakeholders are **not just an audience** — stakeholder resonance is
a real slow-clock loop-closer. But it is a **weak, lagging, gameable** signal:
read it in aggregate over time, never as a per-post verdict. One enthusiastic
reaction hardening into "evidence the direction is right" is broadcast-volume
sneaking back in. The valve admits the signal; the scene is what it's measured
against.

## End of the walk — route onward

The walk's last act is to route, based on the door you named:

- **Muse / vision day** (or any time you want to widen before narrowing) →
  `muse.md`. Dream, then come back and ground.
- **Tactical day** (or a `/arbiters <focus>` you've grounded enough to scout) →
  `scout.md`.
- **Generative day** — replay a standing challenge → `challenge.md`.
- **World-model day** — tend or extend the instrument regime → the
  `arbiters-worldmodel` skill.
- **Gardener day** — a whole session of tending, no building → `gardener.md`.

Whichever door you take, you return *here*, to the walk, between phases — every
minion reports back to the two of you, and the conversation stays the spine. That
return is not optional politeness; it is the method.
