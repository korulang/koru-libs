---
type: belief
id: frag-a-named-escape-buys-a-diagnostic-not-just-a-grep
provenance: ruling merged three `ukalloc` lifts; strict `free` + named escape was argued purely on greppability, then measured to change what the compiler reports for a forgotten resource
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
- **State the two claims separately.** "Forgetting to free is a compile error" is
  true for one state and false for the other in the same module. A README that
  merges them is claiming a guarantee it does not have for the common case.
- **Argue containment, then go measure.** The containment argument was sufficient
  to decide the ruling and it did not predict the mechanical consequence. A design
  argument that is right for its stated reason may still be understating itself;
  running the thing is how you find out which.
