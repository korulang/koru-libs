#!/bin/bash
# test.sh — the asteroids-net integration probe, self-contained.
#
# Builds server/driver/watcher fresh (stale binaries lie), spawns its own
# server on :7777, runs the pair against it on real datagrams, asserts
# both oracles, cleans up. ~8s wall-clock. Exit 0 = both green.
#
#   watcher — joins, keepalives every 30 ticks, learns its pid off
#             snap.you, asserts ITS ship stayed parked while a driven
#             ship moved (cross-owner input leak → FAIL).
#   driver  — thrusts 360 ticks, withholds sends at t∈[140,145) — a real
#             5-packet seq gap — asserts snap.indrop == 5 (server counted
#             exactly the injected loss).
#
# The port is fixed (wire const): if :7777 is held by a foreign process
# the spawned server dies on bind and the test fails loud — it does not
# share or hijack a stranger's socket.

set -u
cd "$(dirname "$0")"
LOG=/tmp/asteroids-net-test
mkdir -p "$LOG"

for f in server driver watcher; do
    printf "%-10s build... " "$f"
    if koruc build "$f.k" > "$LOG/$f.build.log" 2>&1 && mv a.out "$f.bin"; then
        echo ok
    else
        echo FAIL
        tail -8 "$LOG/$f.build.log"
        exit 1
    fi
done

./server.bin > "$LOG/server.log" 2>&1 &
SRV=$!
trap 'kill $SRV 2>/dev/null' EXIT
sleep 1
if ! kill -0 $SRV 2>/dev/null; then
    echo "FAIL: server died on startup — :7777 held by something else?"
    cat "$LOG/server.log"
    exit 1
fi

./driver.bin > "$LOG/driver.log" 2>&1 &
DRV=$!
sleep 1                       # driver's stream must be live before the
./watcher.bin > "$LOG/watcher.log" 2>&1   # watcher joins (~6s foreground)
wait $DRV

echo
cat "$LOG/watcher.log"
cat "$LOG/driver.log"
echo

PASS=0
grep -q "ISOLATION: PASS" "$LOG/watcher.log" && { echo "watcher oracle: PASS"; } || { echo "watcher oracle: FAIL"; PASS=1; }
grep -q "LOSS-ORACLE: PASS" "$LOG/driver.log" && { echo "driver oracle:  PASS"; } || { echo "driver oracle:  FAIL"; PASS=1; }
exit $PASS
