#!/usr/bin/env bash
# ccshell.sh — Claude Cowork Shell Command Runner
#
# A file-polling shell bridge for Claude in Cowork mode (and other AI clients
# that can write files but can't run shell commands directly). Polls a
# `queue/` directory for *.sh files, runs them with a per-script timeout,
# captures output to `done/`. The AI drops scripts; the runner executes them
# as you; the AI reads results back. No keystroke injection, ever.
#
# Usage:
#   bash ccshell.sh                       # uses ./.ccshell as the root
#   CCSHELL_DIR=~/.ccshell bash ccshell.sh
#   CCSHELL_TIMEOUT=30 bash ccshell.sh    # 30s per-script timeout
#
# Stop with: rm "$CCSHELL_DIR/.running"   (or Ctrl+C)
#
# Layout created automatically:
#   $CCSHELL_DIR/
#     queue/   — drop *.sh here; the watcher picks them up oldest-first
#     done/    — output (one .out file per script) lands here
#     .pid     — current watcher's pid
#     .running — marker file; remove to stop the watcher
#
# The runner takes no special privileges. It inherits exactly whatever
# shell privileges the user who started it has. Scripts that land in
# queue/ can do anything the user can do. Read the README before exposing
# the queue dir to untrusted writers.
#
# License: MIT
# Project: https://github.com/renshuBTC/claude-cowork-shell-command-runner

set -u

CCSHELL_DIR=${CCSHELL_DIR:-${DROPSHELL_DIR:-./.ccshell}}      # DROPSHELL_DIR kept as alias for back-compat
CCSHELL_TIMEOUT=${CCSHELL_TIMEOUT:-${DROPSHELL_TIMEOUT:-60}}
CCSHELL_VERSION="0.1.1"

ROOT=$(mkdir -p "$CCSHELL_DIR" && cd "$CCSHELL_DIR" && pwd)
mkdir -p "$ROOT/queue" "$ROOT/done"
chmod 700 "$ROOT" 2>/dev/null || true

OLD_PID=$(cat "$ROOT/.pid" 2>/dev/null || true)
if [ -n "$OLD_PID" ] && kill -0 "$OLD_PID" 2>/dev/null; then
    echo "==> killing previous runner pid=$OLD_PID"
    kill -9 "$OLD_PID" 2>/dev/null || true
    pkill -9 -P "$OLD_PID" 2>/dev/null || true
    sleep 1
fi

echo "$$" > "$ROOT/.pid"
echo "running" > "$ROOT/.running"

echo "==> ccshell v$CCSHELL_VERSION (Claude Cowork Shell Command Runner) started"
echo "    pid=$$  root=$ROOT  timeout=${CCSHELL_TIMEOUT}s per script"
echo "    drop scripts at: $ROOT/queue/<name>.sh"
echo "    outputs land at: $ROOT/done/<name>.out"
echo "    stop with: rm '$ROOT/.running'   (or Ctrl+C)"

trap 'echo "==> ccshell exiting"; rm -f "$ROOT/.running" "$ROOT/.pid"' EXIT INT TERM

for f in "$ROOT/queue/"*.sh; do
    [ -f "$f" ] || continue
    base=$(basename "$f" .sh)
    if [ -f "$ROOT/done/$base.out" ]; then
        mv "$f" "$f.skipped"
        echo "==> skipped $base (output exists from previous runner)"
    fi
done

while [ -f "$ROOT/.running" ]; do
    next=$(ls -1tr "$ROOT/queue/"*.sh 2>/dev/null | head -n1 || true)
    if [ -n "$next" ]; then
        base=$(basename "$next" .sh)
        out="$ROOT/done/$base.out"
        echo "==> [$base] running (timeout ${CCSHELL_TIMEOUT}s)..."
        START=$(date +%s)
        {
            timeout --kill-after=5 "$CCSHELL_TIMEOUT" bash "$next" 2>&1
            ec=$?
            END=$(date +%s)
            echo "===EXIT=$ec=== (took $((END-START))s)"
            if [ "$ec" -eq 124 ]; then
                echo "===TIMED OUT after ${CCSHELL_TIMEOUT}s — script killed, runner continues==="
            fi
        } > "$out"
        mv "$next" "$next.done"
        echo "==> [$base] done -> $out"
    fi
    sleep 1
done
