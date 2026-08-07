---
type: belief
id: frag-on-a-hot-resource-the-cost-is-states-not-the-obligation
provenance: lifting `uknetdev`, the first Unikraft target with both a rare resource (the device) and a hot one (the packet); the brief's "a failure on a hot resource should probably consume" was read as "do not put an obligation on a hot resource", and measuring the emitted code showed the reading was wrong
ts: 2026-08-07
---

# On a hot resource the ceremony you cannot afford is STATES, not the obligation (belief)

The standing rule is that **obligation-on-failure scales inversely with resource
frequency**: a device is rare and long-lived, so a failed `configure` should hand
back an obligation; a packet is hot and numerous, so a failure there should
probably consume, "or every dropped packet grows ceremony on the per-packet
path."

That rule is right and it is easy to over-apply. Read quickly it says *keep
obligations off hot resources*, and a designer who believes that will refuse to
model the one thing on the hot path that can actually leak.

## What the ceremony actually is

Ceremony is **calls the caller has to write, per item**. An obligation by itself
is not a call: Koru auto-discharges a resource whose obligation has exactly one
disposal, and the emitter inserts the call. A *state* is a call, because every
state on the way from acquisition to disposal is a tor somebody has to name.

So the two things move independently:

- **One obligation, one state, one disposal → the compiler writes the discharge.**
  A received netbuf whose only exit is `packet.drop` cannot leak and cannot be
  forgotten, and a program that omits the drop still compiles — with the
  `uk_netbuf_free` inserted. Measured in the emitted Zig, not reasoned about.
- **Two states → the caller writes two calls, per packet, forever.** A `<read!>`
  state between `<received!>` and the drop is the thing the rule is warning
  about, and it is what a designer adds when "apply pillar 4's asymmetry" is
  applied uniformly.

## The discriminator, and it is not frequency

Ask what the C says about **ownership**, not how often the call happens.

- `uk_netdev_tx_one`'s contract is that the driver frees the netbuf once the
  device is done with it. Ownership transfers *inside one call*, so there is no
  interval for the caller to hold anything: the transmit path takes bytes and has
  no obligation at all. On the one arm where the driver declines the frame and
  leaves it intact, the lift frees it and reports loudly — the rule's "a failure
  on a hot resource should consume", with a reason from the C rather than from
  taste.
- `uk_netdev_rx_one` hands out a netbuf and the caller holds it for as long as it
  is reading the payload. No single call can contain that. The obligation is not
  a design choice; refusing it would just be a leak.

## What follows

- **Count the states, not the obligations, when you are asked whether a hot path
  can afford safety.** The answer for one obligation and one state is: yes, and
  it costs nothing the caller writes.
- **The asymmetry gate belongs where a resource can be acquired and genuinely not
  used.** If the acquiring tor hands back the handle *and* the value in the same
  arm, "acquired but unused" is not a reachable state and a gate on it guards
  nothing while costing a call per item. Put the gate on the rare resource, where
  "brought it up and never touched it" is a real and invisible mistake.
- **A rule phrased about a resource's frequency is really about the shape of its
  ownership transfer.** Frequency is a good proxy — hot things usually transfer
  ownership inside a call and rare things usually do not — but it is the proxy,
  and reading it as the rule produces either a leak or a ceremony tax depending on
  which way you err.
