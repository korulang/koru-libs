#!/usr/bin/env bash
# Take the machine's supervised background services down for a measurement, and
# put back exactly what was taken down.
#
# WHY A SCRIPT AND NOT `kill`. The heavy background services on this machine are
# launchd user agents declared `KeepAlive true`. Killing one is answered by
# launchd within milliseconds, with a new pid — so an afternoon of "I killed the
# noisy processes, load is still 5" is not a mystery, it is the supervisor doing
# its job. `kill` is the wrong verb no matter how brutally it is applied; the
# only thing that holds is `launchctl bootout`.
#
# Measured 2026-08-08: nine services killed by pid, all back inside three
# seconds, load unchanged.
#
# WHAT IT DOES NOT TOUCH, on purpose: Claude sessions (there were fifteen live,
# with in-flight work in worktrees), the editor, the browsers, the dictation
# stack Lars talks through, and anything Apple. Those are the machine being
# used, not the machine misbehaving.
#
#   ./quiet-machine.sh stop     # bootout the agents, record what was taken
#   ./quiet-machine.sh start    # bootstrap back exactly that list
#   ./quiet-machine.sh status   # what is up right now
set -euo pipefail

STATE="${TMPDIR:-/tmp}/koru-quiet-machine.state"
AGENT_DIR="$HOME/Library/LaunchAgents"
DOMAIN="gui/$(id -u)"

# Prefixes of agent labels this script is allowed to stop. Anything outside this
# list stays up — a benchmark is not a reason to start pulling on the operating
# system.
PREFIXES="com.6digit. com.6dtrust."

labels_up() {
    launchctl list \
        | awk 'NR>1 {print $1"\t"$3}' \
        | while IFS=$'\t' read -r pid label; do
            for p in $PREFIXES; do
                case "$label" in
                    "$p"*) [ "$pid" != "-" ] && echo "$label" ;;
                esac
            done
        done
}

case "${1:-status}" in
    status)
        echo "load: $(uptime | sed 's/.*load average/load average/')"
        echo "supervised services up:"
        labels_up | sed 's/^/  /'
        ;;

    stop)
        : > "$STATE"
        for label in $(labels_up); do
            plist="$AGENT_DIR/$label.plist"
            if [ ! -f "$plist" ]; then
                echo "skip $label — no plist at $plist, cannot restore it, so not stopping it" >&2
                continue
            fi
            echo "stopping $label"
            launchctl bootout "$DOMAIN/$label" 2>/dev/null || true
            echo "$label" >> "$STATE"
        done

        # A bootout that did not take is worse than none: the caller believes
        # the machine is quiet and measures it anyway. Verify, do not assume.
        sleep 2
        still="$(labels_up || true)"
        if [ -n "$still" ]; then
            echo "" >&2
            echo "WARNING — these came back or never went down:" >&2
            echo "$still" | sed 's/^/    /' >&2
            echo "  Do not treat this window as quiet." >&2
            exit 1
        fi
        echo ""
        echo "stopped $(wc -l < "$STATE" | tr -d ' ') services; restore with: $0 start"
        uptime
        ;;

    start)
        if [ ! -f "$STATE" ]; then
            echo "nothing recorded at $STATE — refusing to guess what should be running." >&2
            exit 1
        fi
        while read -r label; do
            [ -z "$label" ] && continue
            plist="$AGENT_DIR/$label.plist"
            echo "starting $label"
            launchctl bootstrap "$DOMAIN" "$plist" 2>/dev/null || true
        done < "$STATE"
        rm -f "$STATE"
        sleep 2
        echo ""
        echo "up again:"
        labels_up | sed 's/^/  /'
        ;;

    *)
        echo "usage: $0 {stop|start|status}" >&2
        exit 2
        ;;
esac
