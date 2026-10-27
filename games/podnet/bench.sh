#!/bin/bash
# podnet/bench.sh — per-match cost probe.
# Usage: ./bench.sh <server_binary> <client_binary> <N> <duration_s> <tag>
# Starts the server, spawns N clients (each = one simulated player),
# samples server RSS and cumulative CPU-time once per second, counts pos
# lines per client (each printed line == 20 pos packets received —
# see client.k). Everything the run spawns is killed at the end.

set -u
cd "$(dirname "$0")"

SRV_BIN=${1:-./server.bin}
CLI_BIN=${2:-./client.bin}
N=${3:-8}
DUR=${4:-40}
TAG=${5:-run}
WARM=8        # connect/settle window before sampling starts
STAGGER=0.05  # s between client spawns — avoids a connect thundering herd

OUT="bench_out/$TAG"
mkdir -p "$OUT"
rm -f "$OUT"/client_*.log "$OUT"/server.log "$OUT"/samples.txt

echo "== bench: $SRV_BIN + $N x $CLI_BIN for ${DUR}s (tag=$TAG) =="

"$SRV_BIN" > "$OUT/server.log" 2>&1 &
SRV=$!
sleep 1
if ! kill -0 "$SRV" 2>/dev/null; then
    echo "server failed to start:"; cat "$OUT/server.log"; exit 1
fi

CPIDS=()
if [ "$N" -gt 0 ]; then
for i in $(seq 0 $((N - 1))); do
    "$CLI_BIN" > "$OUT/client_$i.log" 2>&1 &
    CPIDS+=($!)
    sleep "$STAGGER"
done
fi

sleep "$WARM"

POS_AT_START=$(cat "$OUT"/client_*.log 2>/dev/null | grep -c '^pos cn')
POS_AT_START=${POS_AT_START:-0}

# Sample server RSS (KiB) and cumulative CPU time (mm:ss.cc) once per
# second for DUR seconds. %CPU is computed as delta(cputime)/delta(wall):
# macOS `ps -o pcpu` is a lifetime average and reads 0.0 on this workload.
: > "$OUT/samples.txt"
for s in $(seq 1 "$DUR"); do
    LINE=$(ps -o rss=,time= -p "$SRV" 2>/dev/null) || break
    [ -z "$LINE" ] && break
    NOW=$(python3 -c 'import time; print(time.time())')
    echo "$LINE $NOW" >> "$OUT/samples.txt"
    sleep 1
done

POS_AT_END=$(cat "$OUT"/client_*.log 2>/dev/null | grep -c '^pos cn')
POS_AT_END=${POS_AT_END:-0}

ALIVE=0
if [ "${#CPIDS[@]}" -gt 0 ]; then
    for p in "${CPIDS[@]}"; do kill -0 "$p" 2>/dev/null && ALIVE=$((ALIVE + 1)); done
    kill "$SRV" "${CPIDS[@]}" 2>/dev/null
else
    kill "$SRV" 2>/dev/null
fi
wait 2>/dev/null

# --- report (all reduction in one python pass) ---
python3 - "$OUT" "$WARM" "$DUR" "$N" "$TAG" "$POS_AT_START" "$POS_AT_END" <<'PY'
import sys, os, re, glob

out, warm, dur, n, tag = sys.argv[1], int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), sys.argv[5]
pos_start, pos_end = int(sys.argv[6]), int(sys.argv[7])

def cpu_to_s(t):
    # macOS ps time: "[dd-]hh:mm:ss" or "mm:ss.cc"
    t = t.strip()
    m = re.match(r'(?:(\d+)-)?(?:(\d+):)?(\d+):(\d+)(?:\.(\d+))?', t)
    if not m: return None
    d, h, mm, ss, cc = m.groups()
    d = int(d or 0); h = int(h or 0); mm = int(mm); ss = int(ss)
    frac = float('0.' + cc) if cc else 0.0
    return d*86400 + h*3600 + mm*60 + ss + frac

rows = []
for line in open(os.path.join(out, 'samples.txt')):
    p = line.split()
    if len(p) < 3: continue
    rows.append((int(p[0]), cpu_to_s(p[1]), float(p[2])))

ns = len(rows)
avg_rss = sum(r[0] for r in rows)/ns if ns else 0
max_rss = max((r[0] for r in rows), default=0)

cpus = []
for a, b in zip(rows, rows[1:]):
    if a[1] is None or b[1] is None: continue
    dt = b[2]-a[2]; dc = b[1]-a[1]
    if dt > 0: cpus.append(100.0*dc/dt)
total_cpu = None
if ns >= 2 and rows[0][1] is not None and rows[-1][1] is not None:
    w = rows[-1][2]-rows[0][2]
    if w > 0: total_cpu = 100.0*(rows[-1][1]-rows[0][1])/w
avg_cpu = sum(cpus)/len(cpus) if cpus else (total_cpu or 0)
max_cpu = max(cpus, default=0)

clog = glob.glob(os.path.join(out, 'client_*.log'))
def count(pat, files):
    c = 0
    for f in files:
        for l in open(f, errors='replace'):
            if l.startswith(pat): c += 1
    return c

connected = sum(1 for f in clog if any(l.startswith('connected as cn') for l in open(f, errors='replace')))
dones = sum(1 for f in clog if any(l.startswith('client done') for l in open(f, errors='replace')))
pos_lines = count('pos cn', clog)
per_client = sorted(sum(1 for l in open(f, errors='replace') if l.startswith('pos cn')) for f in clog)

slog = os.path.join(out, 'server.log')
joins = busy = leaves = 0
if os.path.exists(slog):
    for l in open(slog, errors='replace'):
        if l.startswith('join cn'): joins += 1
        if 'slot busy' in l: busy += 1
        if l.startswith('leave cn'): leaves += 1

pos_pkts_win = (pos_end - pos_start)*20   # exact measured window
pos_rate = pos_pkts_win/dur if dur else 0
print(f"-- tag={tag} N={n} dur={dur}s warm={warm}s")
print(f"server RSS: avg {avg_rss/1024:.2f} MB  max {max_rss/1024:.2f} MB  (samples: {ns})")
print(f"server CPU: avg {avg_cpu:.1f}%  max {max_cpu:.1f}%  (window-total: {('%.1f'%total_cpu) if total_cpu is not None else 'n/a'}%)")
print(f"clients: {connected} connected, {len(clog)} spawned, {dones} exited early ('client done')")
print(f"server log: {joins} joins ({busy} 'slot busy'), {leaves} leaves")
print(f"pos lines in window: {pos_end-pos_start} (total {pos_lines})  -> ~{pos_pkts_win} pos pkts  -> ~{pos_rate:.1f} pos-pkts/s delivered")
if per_client:
    print(f"per-client pos lines: min={per_client[0]} max={per_client[-1]} mean={sum(per_client)/len(per_client):.0f}")
PY
