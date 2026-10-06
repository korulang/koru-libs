---
type: belief
id: frag-the-replay-spec-is-the-source-of-truth-not-the-capture
provenance: web gauntlet, 2026-10-05 — post-files golden captured a malformed
  multipart request (server reported "received 0 bytes"); the canonical
  case.txt spec, replayed through the closer, regenerated the true golden
ts: 2026-10-06
---

# The replay spec is the source of truth, not the capture (belief)

A golden recorded by hand is an artifact of *how it was asked*, and the asking
can be wrong. In the web gauntlet every case is a `case.txt` (request line +
headers + body spec) *plus* the captured response — so the response is
regenerable, not sacred.

First proof the same day it was designed: `post-files` was captured with a
`curl -F` upload topcoat couldn't parse — the golden body read "received 0
bytes across all fields." The closer, replaying the canonical fixed-boundary
spec, got "received 18 bytes." The spec was right; the capture was wrong; the
golden was re-captured *from the spec*, not edited.

The discipline survived protocol shape: the websocket fixture (2026-10-06)
applies it to bidirectional exchanges — `send.txt` is the authored spec,
`frames.txt` the captured oracle — and the same closer replays spec →
oracle against any claimant. Nothing about the belief required
request/response; it required an authored ask and a recorded answer.

Rule of operation: when spec and capture disagree, regenerate from the spec.
A golden that can only have been produced one way, once, by a possibly-broken
command line, is a drift oracle with no ground truth beneath it.
