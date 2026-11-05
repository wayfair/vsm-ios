#!/bin/bash
# Runs the profiling matrix. Usage: Scripts/profile-matrix.sh <udid> <patched.app> <unpatched.app>
# Animation Hitches is not supported on the simulator, so frame pacing comes from the app's own
# FrameMonitor, captured in "none" runs (no Instruments attached), repeated 3 times.
set -uo pipefail
UDID=$1; PATCHED=$2; UNPATCHED=$3
HERE=$(cd "$(dirname "$0")" && pwd)
run() { "$HERE/profile-run.sh" "$@" || echo "RUN FAILED: $*"; }

for cfg in "baseline 0" "baseline 1" "hosted 0" "hosted 1"; do
  set -- $cfg; MODE=$1; PURGE=$2
  LABEL="${MODE}_purge${PURGE}_patched"
  run "$UDID" "$PATCHED" "$LABEL" "$MODE" "$PURGE" Leaks snapshots
  for T in "Allocations" "Time Profiler" "SwiftUI"; do run "$UDID" "$PATCHED" "$LABEL" "$MODE" "$PURGE" "$T"; done
  for i in 1 2 3; do run "$UDID" "$PATCHED" "${LABEL}_rep$i" "$MODE" "$PURGE" none snapshots; done
done

for PURGE in 0 1; do
  LABEL="baseline_purge${PURGE}_unpatched"
  run "$UDID" "$UNPATCHED" "$LABEL" baseline "$PURGE" Leaks snapshots
  for i in 1 2 3; do run "$UDID" "$UNPATCHED" "${LABEL}_rep$i" baseline "$PURGE" none snapshots; done
done
echo MATRIX_COMPLETE
