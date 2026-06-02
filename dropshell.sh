#!/usr/bin/env bash
# dropshell.sh — file-polling shell bridge for AI agents in restricted hosts.
#
# Polls a `queue/` directory for *.sh files, runs them with a per-script
# timeout, and captures their output to `done/`. Designed so an AI assistant
# can drop scripts in the queue and read results from done/ without ever
# typing into your terminal.
#
# Usage:
#   bash dropshell.sh                    # uses ./.dropshell as the root
#   DROPSHELL_DIR=~/.dropshell bash dropshell.sh
#   DROPSHELL_TIMEOUT=30 bash dropshell.sh  # 30s per-script timeout
#
# Stop with: rm "$DROPSHELL_DIR/.running"   (or Ctrl+C)
#
# Layout created automatically:
#   $DROPSHELL_DIR/
#     queue/   — drop *.sh here; the watcher picks them up oldest-first
#     done/    — output (one .out file per script) lands here
#     .pid     — current watcher's pid
#     .running — marker file; remove to stop the watcher
#
# The watcher takes no special privileges. It inherits exactly whatever
# shell privileges the user who started it has. Scripts that land in
# queue/ can do anything the user can do. Read the README before exposing
# the queue dir to untrusted writers.
#
# License: MIT. Project: https://github.com/renshuBTC/dropshell

set -u

DROPSHELL_DIR=${DROPSHELL_DIR:-./.dropshell}
DROPSHELL_TIMEOUT=${DROPSHELL_TIMEOUT:-60}
DROPSHELL_VERSION="0.1.0"

ROOT=$(mkdir -p "$DROPSHELL_DIR" && cd "$DROPSHELL_DIR" && pwd)
mkdir -p "$ROOT/queue" "$ROOT/done"
chmod 700 "$ROOT" 2>/dev/null || true

# Kill any previous watcher cleanly
OLD_PID=$(cat "$ROOT/.pid" 2>/dev/null || true)
if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "==> killing previous watcher pid=$OLD_PID"
    kill -9 "$OLD_PID" 2>/dev/null || true
    pkill -9 -P "$OLD_PID" 2>/dev/null || true
    sleep 1
fi

echo "$$" > "$ROOT/.pid"
echo "running" > "$ROOT/.running"

echo "==> dropshell v$DROPSHELL_VERSION started"
echo "    pid=$$  root=$ROOT  timeout=${DROPSHELL_TIMEOUT}s per script"
echo "    drop scripts at: $ROOT/queue/<name>.sh"
echo "    outputs land at: $ROOT/done/<name>.out"
echo "    stop with: rm '$ROOT/.running'   (or Ctrl+C)"

trap 'echo "==> dropshell exiting"; rm -f "$ROOT/.running" "$ROOT/.pid"' EXIT INT TERM

# Auto-skip any script that already has an .out file (partial run from a prior watcher)
for f in "$ROOT/queue/"*.sh; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .sh)
    if [ -f "$ROOT/done/$base.out" ]; then
        mv "$f" "$f.skipped"
        echo "==> skipped $base (output exists from previous watcher)"
    fi
done

while [ -f "$ROOT/.running" ]; do
    next=$(ls -1tr "$ROOT/queue/"*.sh 2>/dev/null | head -n1 || true)
    if [ -n "$next" ]; then
        base=$(basename "$next" .sh)
        out="$ROOT/done/$base.out"
        echo "==> [$base] running (timeout ${DROPSHELL_TIMEOUT}s)..."
        START=$(date +%s)
        {
            timeout --kill-after=5 "$DROPSHELL_TIMEOUT" bash "$next" 2>&1
            ec=$?
            END=$(date +%s)
            echo "===EXIT=$ec=== (took $((END-START))s)"
            if [ "$ec" -eq 124 ]; then
                echo "===TIMED OUT after ${DROPSHELL_TIMEOUT}s — script killed, watcher continues==="
            fi
        } > "$out"
        mv "$next" "$next.done"
        echo "==> [$base] done -> $out"
    fi
    sleep 1
done
