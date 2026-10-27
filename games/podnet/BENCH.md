# podnet — per-match cost, measured

Tree pinned: koru-libs `2d0eea2` (koru compiler `9f8576850`), Apple M2 Pro
(12-core arm64), macOS, loopback UDP. All numbers from `./bench.sh` runs in
`bench_out/` — raw samples and per-client logs are kept there for audit.

## Headline table

Server: `server_bench.bin` (capacity-64 variant, see "Artifact under test").
Workload: N × `client_bench.bin` sessions on :28801, 8 s warm-up + 30 s
sampled window, RSS/CPU sampled once per second off `ps`.

| N sessions | server RSS avg (peak) | server %CPU avg (1-s max) | pos pkts delivered/s | est. ticks/s |
|-----------:|----------------------:|--------------------------:|---------------------:|-------------:|
| 0 (idle)   | 1.8 MB                | ~0%                       | 0                    | —            |
| 1          | 801 MB (1088)         | 43% (46%)                 | ~21,200              | ~21,000      |
| 8          | 804 MB (923)          | 88% (93%)                 | ~431,700             | ~6,700       |
| 32         | 1009 MB (1271)        | 74% (83%)                 | ~1,402,000           | ~1,370       |
| 64         | 796 MB (916)          | 72% (78%)                 | ~1,388,000           | ~340         |

Delivery verified per client: every spawned session printed `connected as
cn`, and pos-line counts are tightly clustered (N=64: min 41,021 / max
48,295 lines per client — no starved session, broadcast actually flowed).
A bench where nothing flowed would read as zeros; it did not.

## Methodology

- `bench.sh <server> <client> <N> <dur_s> <tag>`: starts the server, spawns
  N clients staggered 50 ms apart, sleeps 8 s warm-up, then samples
  `ps -o rss=,time=` once per second for the window, then counts pos lines
  written during exactly that window, then kills everything it spawned.
- **pos-line accounting is exact, not extrapolated**: `client.k` prints one
  `pos cn …` line per 20 pos packets decoded, so delivered pos-pkts/s =
  (window-end lines − window-start lines) × 20 / 30 s.
- **%CPU is delta(cputime)/delta(wall)**, not `ps -o pcpu` — macOS pcpu is a
  lifetime average and read 0.0 on this workload. "1-s max" is the busiest
  single inter-sample interval.
- est. ticks/s = delivered pos-pkts/s ÷ N clients ÷ N players-per-tick
  (each tick broadcasts every used row's pos to every used row).

## Caveats — read before quoting

1. **Debug build.** koruc emits `a.out (Debug)`; there is no Release path
   exercised here. These are Debug numbers — do not read them as production
   performance.
2. **Loopback is a floor, not a ceiling.** No WAN loss, jitter, or NIC cost.
   A deployed match pays more CPU and delivers fewer pkts/s.
3. **The workload is a self-reinforcing flood.** `service` returns `idle`
   after every drain, and both sides act on every idle: clients send one
   input per service call, the server ticks once per service call. There is
   no tick rate limiter — the loop spins as fast as the CPU allows. The
   "tick rates" above (~21k/s at N=1 down to ~340/s at N=64) are what the
   code actually does, not a configured 20/60 Hz. Measured tick rate falls
   ~O(N²) because `tick` scans MAXP² slots and fans out N² pos sends.
4. **N=64 is contention-dominated.** 64 spinning client processes + the
   server share 12 cores. ~72% CPU for the server is what it got while
   fighting its own clients; on an uncontended box expect nearer 100% of a
   core at that throughput.
5. **RSS is queue backlog, not session state.** Idle RSS is 1.8 MB; the 64
   player rows are ~3 KB total. Under the flood, RSS oscillates ~0.6–1.3 GB
   regardless of N (samples: 634→945→705 MB across one N=8 window). It
   shrinks as well as grows, so it is not a monotonic leak — the probable
   mechanism is the enet inbound-event backlog (clients produce inputs far
   faster than the O(N²)-bound serve loop drains them) plus per-message
   page-grain allocations in `wire:pos`/`wire:input` (`page_allocator.dupe`
   of 21 B costs a 4 KB page). Mechanism is a hypothesis; the ~1 GB resident
   figure under load is measured.
6. **The N≤8 rows are the 64-capacity build.** Its tick scans `for(0..64)`
   twice (4096 slot-checks/tick) where the stock MAXP=8 build scans 64 — so
   stock would be modestly cheaper per tick at these Ns. The stock binary
   was never benchmarkable past warm-up anyway: under the N=8 flood its
   `TICKS: 36000` expired in ~9 s.
7. **The committed `server.k` cannot host these Ns.** Its `players` grid is
   size 8 (`MAXP: 8`) while enet admits 32 peers — measured: the 9th connect
   panics the process (`std/grid: index out of range for grid 'players'
   (size 8)`, Abort trap). Also `TICKS: 36000` counts serve() calls, not
   seconds — under the N=8 flood it expired in ~9 s ("server done" before
   the sample window even opened). The 6-minute figure is the idle rate.

## Artifact under test

| file | diff vs committed source |
|---|---|
| `server_bench.k` | `MAXP 8→64`, `players` grid `8→64`, `peers 32→64`, `TICKS 36000→5_000_000` (iteration-counted lifetime must outlive the window), `PORT 28800→28801` (another session held :28800). Zero logic changes. |
| `client_bench.k` | `for(0..2000)→for(0..2_000_000)` (stock clients print `client done` and exit ~30 s in — mid-window churn), dial port `28800→28801`. Zero logic changes. |

`wire/index.kz` gained an additive `input.map` proc mid-session (sibling
work on live-keyboard client.k, mtime 16:59 vs my builds 17:01); the procs
this bench uses — `input`, `input.decode`, `nmc`, `pos`, `pos.decode` —
are byte-identical. The rebuilt `client.k` (17:22, keyboard-driven) was
never used in any run above.

## Extrapolation

At N=64 a match server costs **~0.7–1.0 of one core + ~0.8–1.3 GB resident**
under this workload → a $4-class droplet (1 shared vCPU, ~0.5–1 GB) hosts
**~one 64-session match, and only barely on memory**. The binding resource
is the ~1 GB queue/alloc floor, not CPU or per-session state — at the
committed design point (8 sessions) CPU is ~0.9 core and footprint is still
~0.9 GB. Density per dollar is gated on bounding the flood (a real tick
rate and drained-queue backpressure), not on faster code.
