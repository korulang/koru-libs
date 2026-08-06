---
type: belief
id: frag-a-named-escape-buys-a-diagnostic-not-just-a-grep
provenance: ruling merged three `ukalloc` lifts; strict `free` + named escape was argued purely on greppability, then measured to change what the compiler reports for a forgotten resource. Extended by the `ukallocpool` lift, which used the mechanism forward rather than discovering it, and found two more levers that move the same switch.
ts: 2026-08-06
---

# Narrowing a disposal turns auto-discharge into a diagnostic, and that is worth more than the grep it was argued for (belief)

The standard argument for a **strict** finalizer plus a **named escape** —
`free` accepts only `<!live>`, and `untouched` is how you say "I never wrote
here" — is documentary. It makes intent greppable:

```
grep -r "alloc:untouched"   ->   "where do we reserve memory we never write to"
```

That argument is good and it is also the smaller half. The larger half is
mechanical, and it only shows up when you run the compiler.

## The instance

Three contestants lifted Unikraft's `ukalloc`. One shipped a permissive `free`
accepting both `<raw>` and `<live>`, and argued it well: a heap allocation's use
*is* the reservation, early-exit `take`-then-`free` is ubiquitous, and `ukalloc`
has no assertion objecting. Two shipped a strict `free` plus a named escape. The
merge ruled for strict, on containment: a strict design plus a named escape
*contains* the permissive one — every program the permissive `free` accepts, the
strict module accepts with one extra word — while the reverse is not true at any
price.

Then the merged module was measured, and something nobody had argued fell out.

Koru **auto-discharges** a resource whose obligation has exactly one disposal:
the emitter silently inserts the call. Under a permissive `free`, `raw` and
`live` both have that one disposal, so a forgotten block of either kind is
quietly cleaned up and the program compiles. Under the strict gate, `<raw>` has
**no disposal at all**, and the same forgetfulness is a hard error:

```
error[KORU030]: Resource 'b' obligation <raw!> was not discharged. Call: untouched
```

The `<live!>` case still auto-discharges — one unambiguous disposal, so the
emitter inserts the `free`. So one design decision produced two *different*
guarantees where the permissive design had one:

- forgetting a block you never wrote is a **compile error**;
- forgetting a block you did write is a compile-time **insertion**.

## The generalisation — auto-discharge is a THREE-way switch, not a strictness dividend

The `ukallocpool` lift set out to *use* this rather than find it, and in doing so
established that "narrow the accept-set" is one of **three** independent ways to
move the same switch. What auto-discharge actually asks is: **can the emitter
elect exactly one disposal call, and can it construct that call?** Each `no` is a
diagnostic instead of an insertion.

- **Zero disposals for the state** — the original instance. `<raw>` accepts no
  finalizer, so a dropped `raw` block is reported.
- **Two or more disposals for the state.** A pool minted `<owned!>` accepts both
  `free` and `keep`, and dropping it is
  `KORU030: Resource 'op' <owned!> has multiple discharge options: free, keep.
  Discharge explicitly.` This lever is available **without narrowing anything** —
  the escape hatch that was added for the grep is what supplies the second
  disposal, so the documentary argument and the mechanical one turn out to be the
  same act seen from two sides.
- **The disposal takes more than the resource.** `give(pool, obj)` returns an
  object *to its pool*, so its second argument is not derivable from the binding
  being discharged. Auto-discharge can never elect it, and an unreturned object
  is therefore **always** reported — including when the pool is still live and
  nothing else is wrong. This is the strongest of the three and it costs no
  design decision at all: it falls out of the resource genuinely being a
  sub-resource of another one.

The third lever composes with consumption to give an **ordering** rule for free.
If the finalizer of the outer resource consumes it, then any disposal of an inner
resource afterwards is a use-after-discharge on the outer binding. So "every
object must be returned, and returned before the pool ends" needs no counter and
no state on the pool — it is two facts about arity and consumption, meeting.
`ukallocpool` retires a `UK_ASSERT(p->free_obj_count == p->obj_count)` this way.

## What follows

- **A narrowed accept-set does not only forbid; it un-hides.** Every state a
  finalizer stops accepting becomes a state with no disposal, and a state with no
  disposal is one the leak checker can finally speak about. The strictness is not
  paid for by the diagnostic — the diagnostic is a *dividend* of the strictness.
- **Auto-discharge is a silencer, and it is worth knowing where it fires.** A
  single unambiguous disposal means the compiler will paper over the omission
  rather than report it. That is right for memory and wrong for a device; the
  design lever that moves an obligation from one behaviour to the other is how
  many tors accept it, which is not where anyone looks.
- **Count the disposals of every state before you claim a leak guarantee**, and
  count the *arity* of each one. "This cannot leak" means something different for
  a state with zero disposals, one, two, and one that takes a second argument,
  and only the middle case is silent.
- **State the two claims separately.** "Forgetting to free is a compile error" is
  true for one state and false for the other in the same module. A README that
  merges them is claiming a guarantee it does not have for the common case.
- **Argue containment, then go measure.** The containment argument was sufficient
  to decide the ruling and it did not predict the mechanical consequence. A design
  argument that is right for its stated reason may still be understating itself;
  running the thing is how you find out which.
- **Once the mechanism is known, design with it rather than reporting it.**
  `ukallocpool`'s `keep` exists because the pool genuinely outlives the program —
  and it was given the shape it has (accepting both provenances, so `<owned>` ends
  up with two disposals) *because* that is what makes a dropped pool a diagnostic.
  A found mechanism is worth more as a lever than as an anecdote.
