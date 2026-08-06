---
type: belief
id: frag-a-nesting-of-obligations-has-no-terminal-so-nothing-auto-discharges
provenance: `unikraft/ninep` lifted `uk9p`'s device/fid/request nesting by consuming the parent in the child's constructor; every leak at every depth was then reported, and the reason was that no state in the module has a single terminal disposal
ts: 2026-08-06
---

# Nesting by consumption removes every terminal disposal, so leak detection becomes total (belief)

A sub-resource can be modelled two ways.

**Ambient parent.** Every child operation takes both handles; the parent is
never consumed; N children may be live. This is what a header reader designs
first, because it matches the C signatures.

**Consumed parent.** The child's constructor takes the parent and does not give
it back; the child's destructor is the only thing that produces a parent again.
`2104_14_open_tx_commit_close/db.kz` does exactly this for a connection and a
transaction, one level deep.

The choice is normally argued on expressiveness, and the ambient design wins
that argument: it allows sibling children, the consumed design does not.

## What the argument misses

**Only the consumed design can enforce a cross-resource rule, because a phantom
state cannot count.** `uk9p`'s one cross-resource assertion is *every fid must
be clunked before the connection is destroyed* (`9pdev.c:118`), compiled out in
every shipped image. Under an ambient parent, `disconnect` is callable while
children are live and no phantom state knows how many there are — the assertion
stays uncheckable. Under a consumed parent the device handle **does not exist**
while a fid is live, so the misuse is not a state error at all; it is a
use-after-discharge on a binding the constructor consumed. The rule becomes
structural rather than checked, and it costs sibling children.

**And there is a second effect nobody argues for, which shows up only when you
run the compiler.** Koru auto-discharges a resource whose obligation has exactly
one disposal — the emitter silently inserts the call and reports nothing. Stack
the consumption rule and *no state in the module has a terminal disposal at
all*, because **every destructor mints a live obligation on its parent**. There
is nothing for auto-discharge to elect anywhere. A dropped handle at any depth
is reported:

```
error[KORU030]: Resource 'reply' obligation <received!> was not discharged. Call: reply.release
error[KORU030]: Resource 'node'  obligation <walked!>   was not discharged. Call: file.close
```

`unikraft/alloc` cannot make that claim about `free` and says so; `unikraft/lock`
can make it about `read.release` and could not make it about `destroy`. A
nesting built this way can make it **at every level, without arranging for it**.

## What follows

- **State the trade in the module, not just the win.** Sibling children become
  unspellable. For `uk9p` that means two files cannot be open on one tree at
  once, which 9P allows. Naming the alternative and why it was refused is the
  writeup's job, and "a phantom state cannot count live children" is the reason,
  not "the strict version is safer".
- **A nesting is where leak detection is cheapest, not most expensive.** The
  intuition runs the other way — more handles, more to forget — and it is wrong
  for exactly the reason above. Depth is what removes the terminals.
- **Do not reach for the ambient design because the C signatures are ambient.**
  `uk_9p_walk(dev, fid, name)` takes both, and it has to; that is an argument
  about the emitted call, not about the handle the caller holds. The lift's
  handle can carry the parent pointer and hand the parent back later, which is
  what makes the two designs emit identical code.
- **Extends `frag-a-named-escape-buys-a-diagnostic-not-just-a-grep`.** That
  belief found the diagnostic dividend in narrowing ONE finalizer's accept-set.
  This is the same mechanism found in the structure rather than in a single tor:
  nesting narrows every finalizer at once, because a finalizer that returns a
  parent is by construction not a terminal.
