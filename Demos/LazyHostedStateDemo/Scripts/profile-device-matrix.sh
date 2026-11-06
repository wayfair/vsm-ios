#!/bin/bash
# Device matrix. Usage: Scripts/profile-device-matrix.sh <udid> <patched.app> <unpatched.app>
# Instruments runs (Animation Hitches, Time Profiler, SwiftUI) are for traces; the "none" runs
# (3 repetitions, no Instruments attached) provide the in-app frame-pacing and fetch counters.
set -uo pipefail
UDID=$1; PATCHED=$2; UNPATCHED=$3
HERE=$(cd "$(dirname "$0")" && pwd)
run() { "$HERE/profile-device-run.sh" "$@" || echo "RUN FAILED: ${*:3}"; }

for cfg in "baseline 0" "baseline 1" "hosted 0" "hosted 1"; do
  set -- $cfg; MODE=$1; PURGE=$2
  LABEL="${MODE}_purge${PURGE}_patched"
  for i in 1 2 3; do run "$UDID" "$PATCHED" "${LABEL}_rep$i" "$MODE" "$PURGE" none; done
  for T in "Animation Hitches" "Time Profiler" "SwiftUI"; do run "$UDID" "$PATCHED" "$LABEL" "$MODE" "$PURGE" "$T"; done
done
for PURGE in 0 1; do
  for i in 1 2 3; do run "$UDID" "$UNPATCHED" "baseline_purge${PURGE}_unpatched_rep$i" baseline "$PURGE" none; done
done
echo MATRIX_COMPLETE
