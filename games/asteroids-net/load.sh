#!/bin/bash
# load.sh [N] — the scale probe: N real client processes streaming
# sequenced input at ~60Hz against one authoritative server, ~12s.
#
# Each loadbot binds its own ephemeral port → a distinct session key —
# and reports snaps/pid/indrop. The server's heartbeat prints aggregate
# pkts-in/snaps-out. At scale the loss is REAL: socket-buffer pressure
# can drop datagrams, and indrop counts them — no injection needed.
#
# PASS = every bot completed its run, heard snapshots, and learned its
# pid — and the server was still alive at the end. indrop is reported as
# data: it is the measurement, not the verdict.

set -u
cd "$(dirname "$0")"
N="${1:-8}"
MODE="${MODE:-debug}"        # MODE=release builds --release=fast
SERVER_BIN="${SERVER_BIN:-}" # SERVER_BIN=./foreign skips the koru server build — same wire, other implementation
LOG=/tmp/asteroids-net-load
rm -rf "$LOG"; mkdir -p "$LOG"

REL=""; [ "$MODE" = release ] && REL="--release=fast"
echo "mode: $MODE ${SERVER_BIN:+server=$SERVER_BIN}"

TARGETS="loadbot"; [ -z "$SERVER_BIN" ] && TARGETS="server loadbot"
for f in $TARGETS; do
    printf "%-10s build... " "$f"
    if koruc build "$f.k" $REL > "$LOG/$f.build.log" 2>&1 && mv a.out "$f.bin"; then
        echo ok
    else
        echo FAIL
        tail -8 "$LOG/$f.build.log"
        exit 1
    fi
done

"${SERVER_BIN:-./server.bin}" > "$LOG/server.log" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT
sleep 1
if ! kill -0 $SRV 2>/dev/null; then
    echo "FAIL: server died on startup — :7777 held by something else?"
    cat "$LOG/server.log"
    exit 1
fi

PIDS=""
for i in $(seq 1 "$N"); do
    ./loadbot.bin > "$LOG/bot$i.log" 2>&1 &
    PIDS="$PIDS $!"
    sleep 0.05
done
wait $PIDS

echo
echo "── per-bot ─────────────────────────────────────────"
FAIL=0
HEARD=0
for i in $(seq 1 "$N"); do
    line=$(grep 'loadbot:' "$LOG/bot$i.log" || true)
    printf "bot %2d  %s\n" "$i" "${line:-CRASHED / no output}"
    case "$line" in *"snaps, pid "*) HEARD=$((HEARD+1));; *) FAIL=1;; esac
done

echo
echo "── server heartbeat ────────────────────────────────"
grep -E 'beat:|player pid' "$LOG/server.log" | tail -$((N+2))

kill -0 $SRV 2>/dev/null || { echo; echo "server died mid-run"; FAIL=1; }

echo
if [ $FAIL -eq 0 ] && [ $HEARD -eq "$N" ]; then
    echo "LOAD: PASS — $N sessions, all heard"
else
    echo "LOAD: FAIL — $HEARD/$N bots completed"
fi
exit $FAIL
