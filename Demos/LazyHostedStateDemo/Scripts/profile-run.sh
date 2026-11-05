#!/bin/bash
# Records one Instruments trace of the demo's built-in scroll script on a simulator.
#
# Usage: Scripts/profile-run.sh <simulator-udid> <path-to-built.app> <label> <baseline|hosted> <0|1 purge> <template> [snapshots]
#   label      names the output: Profiling/<label>_<template>.trace
#   snapshots  note: the `leaks` CLI reports "not debuggable" for simulator apps on some hosts, so its result is
#              informational only; use the Leaks template trace for leak detection.
#              pass "snapshots" to also run `heap` and `leaks` on the idle process (skip for hitch runs;
#              they perturb timing)
set -euo pipefail

UDID=$1; APP=$2; LABEL=$3; MODE=$4; PURGE=$5; TEMPLATE=$6; SNAP=${7:-}
BUNDLE=com.demo.ios.LazyHostedStateDemo
CYCLES=${CYCLES:-3}
HERE=$(cd "$(dirname "$0")/.." && pwd)
OUT="$HERE/Profiling"; mkdir -p "$OUT"
SAFE_TEMPLATE=$(echo "$TEMPLATE" | tr ' ' '-')
TRACE="$OUT/${LABEL}_${SAFE_TEMPLATE}.trace"
rm -rf "$TRACE"
sleep 0

xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
xcrun simctl install "$UDID" "$APP"
DATA=$(xcrun simctl get_app_container "$UDID" "$BUNDLE" data)
rm -f "$DATA"/Documents/*.json

ARGS=(-mode "$MODE" -purge "$PURGE" -purgeInterval 3 -autoscroll 1 -cycles "$CYCLES")
if [ "$TEMPLATE" = "none" ]; then
  # No Instruments attached: used for frame-pacing numbers without recording overhead.
  xcrun simctl launch "$UDID" "$BUNDLE" "${ARGS[@]}" > "$OUT/${LABEL}_${SAFE_TEMPLATE}.record.log" 2>&1
  XPID=
else
  xcrun xctrace record --template "$TEMPLATE" --device "$UDID" --launch "$BUNDLE" \
    --output "$TRACE" --time-limit 240s -- "${ARGS[@]}" \
    > "$OUT/${LABEL}_${SAFE_TEMPLATE}.record.log" 2>&1 &
  XPID=$!
fi

# Wait for the app's "settled" report (scroll script done + 6s idle).
for _ in $(seq 1 220); do
  [ -f "$DATA/Documents/metrics-settled.json" ] && break
  # Fail fast if xctrace exited early (for example, a template the simulator does not support).
  if [ -n "$XPID" ] && ! kill -0 $XPID 2>/dev/null; then echo "xctrace exited early: see $OUT/${LABEL}_${SAFE_TEMPLATE}.record.log" >&2; exit 1; fi
  sleep 1
done
[ -f "$DATA/Documents/metrics-settled.json" ] || { echo "timed out waiting for settled report" >&2; [ -n "$XPID" ] && kill -INT $XPID; exit 1; }

if [ "$SNAP" = "snapshots" ]; then
  PID=$(pgrep -f "LazyHostedStateDemo.app/LazyHostedStateDemo" | head -1)
  heap "$PID" > "$OUT/${LABEL}_${SAFE_TEMPLATE}.heap.txt" 2>&1 || true
  leaks "$PID" > "$OUT/${LABEL}_${SAFE_TEMPLATE}.leaks.txt" 2>&1 || true
fi
cp "$DATA/Documents/metrics-settled.json" "$OUT/${LABEL}_${SAFE_TEMPLATE}.metrics.json"

if [ -n "$XPID" ]; then kill -INT $XPID; wait $XPID || true; else xcrun simctl terminate "$UDID" "$BUNDLE" || true; fi
echo "$LABEL/$TEMPLATE done: $(cat "$OUT/${LABEL}_${SAFE_TEMPLATE}.metrics.json")"
