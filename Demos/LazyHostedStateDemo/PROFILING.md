# Profiling: `@ViewState` vs `@HostedViewState` in a lazy feed

Goal: measure what happens to per-row state machines when SwiftUI discards the `@State` of rows in a
`LazyVStack` (expected to be more aggressive in iOS 27), and whether `ViewStateStore` plus
`@HostedViewState` avoids the resets, and what the `[weak self]` patch to `AsyncStateContainer` changes.

> **Scope and honesty notes**
>
> - Device runs: one iPhone SE (2nd generation), iOS **26.7.2**, Release build. **No iOS 27 runtime was
>   used for any measurement.** "Simulate purge" (`.id(generation)` bumped every 3 s) stands in for the
>   expected iOS 27 behavior.
> - Each configuration was measured **3 times** (n=3) with a 27 s scroll script, so differences of a few
>   ms/s are within run-to-run noise.
> - The simulator matrix was **stopped early** (Baseline configurations only, Instruments hitch and SwiftUI
>   templates are unsupported on the simulator). No simulator numbers are used in the table below.
> - **No Leaks or Allocations trace was recorded on the device.** Leak status is therefore not established
>   for Hosted mode; see "What this does not tell us".

## How to reproduce

Run from `Demos/LazyHostedStateDemo`. The signing team must be set on the app target (a local edit to the
project is enough; it is not committed).

```sh
UDID=<device udid from: xcrun devicectl list devices>

# Release builds: with the patch (this branch) and without it (a worktree with the patch reverted).
xcodebuild build -project LazyHostedStateDemo.xcodeproj -scheme LazyHostedStateDemo -configuration Release \
  -destination "id=$UDID" -derivedDataPath /tmp/dd-device -allowProvisioningUpdates

git worktree add --detach /tmp/wt-unpatched HEAD
(cd /tmp/wt-unpatched && git apply -R ~/Downloads/AsyncStateContainer-weak-self.patch)
# copy your signing-team edit of project.pbxproj into the worktree, then build it the same way with
# -derivedDataPath /tmp/dd-device-unpatched

# Whole matrix (about 45 min): 3 plain repetitions per configuration, plus Animation Hitches,
# Time Profiler and SwiftUI traces, plus the unpatched Baseline repetitions.
Scripts/profile-device-matrix.sh "$UDID" \
  /tmp/dd-device/Build/Products/Release-iphoneos/LazyHostedStateDemo.app \
  /tmp/dd-device-unpatched/Build/Products/Release-iphoneos/LazyHostedStateDemo.app

# One run: <udid> <app> <label> <baseline|hosted> <purge 0|1> <template|none>
CYCLES=3 Scripts/profile-device-run.sh "$UDID" <app> hosted_purge1 hosted 1 "Animation Hitches"
```

Output goes to `Profiling/device/` (gitignored): `*.trace`, and `*.metrics.json` written by the app.
`none` runs launch without Instruments, so their numbers carry no recording overhead. The app takes
`-mode baseline|hosted -purge 0|1 -purgeInterval <s> -autoscroll 1 -cycles <n> -runID <id>`. The runID is echoed
into the report so a script never reads a stale file.

Hitch summaries from a trace:

```sh
xcrun xctrace export --input Profiling/device/hosted_purge1_patched_Animation-Hitches.trace \
  --xpath '/trace-toc/run/data/table[@schema="hitches"]' --output hitches.xml
```

Simulator (no hitch or SwiftUI templates): `Scripts/profile-run.sh` and `Scripts/profile-matrix.sh`.

## Results (iPhone SE 2nd gen, iOS 26.7.2, Release, patched library unless noted)

Mean of 3 runs. 320 products in the feed. "Frame" figures come from the app's own `CADisplayLink` monitor over
the 27 s scroll script. A hitch frame is a frame longer than 1.5x the frame budget, and a hang is a gap over
250 ms. The monitor is cruder than Instruments, so compare configurations with each other, not with Apple's
thresholds.

| Configuration | Live containers at idle | Detail fetches started | Cancelled | Completed | Hitch frames | Hitch ms/s | Hangs |
|---|---|---|---|---|---|---|---|
| Baseline, purge off | not counted on device (see note) | 1420 | 544 | 876 | 3.3 | 2.0 | 0 |
| Baseline, purge on | not counted on device | 1582 | 644 | 934 | 8.7 | 5.8 | 0 |
| Hosted, purge off | 317 (store count; 320 rows) | 317 | 0 | 317 | 8.7 | 5.0 | 0 |
| Hosted, purge on | 317 (store count; 320 rows) | 317 | 0 | 317 | 12.0 | 9.3 | 0 |

Raw per-run values:

| Configuration | Hitch frames | Hitch ms/s | Max frame gap (ms) |
|---|---|---|---|
| Baseline, purge off | 5, 2, 3 | 2.7, 1.1, 2.2 | 34, 33, 44 |
| Baseline, purge on | 10, 7, 9 | 7.0, 4.9, 5.6 | 53, 53, 42 |
| Hosted, purge off | 9, 8, 9 | 5.3, 4.5, 5.3 | 40, 37, 39 |
| Hosted, purge on | 13, 8, 15 | 10.6, 6.7, 10.6 | 69, 69, 65 |

Notes:

- **Live containers.** Hosted mode's count is `ViewStateStore.count` at the end of the run (idle for 6 s).
  Baseline containers live in SwiftUI `@State`, so the app has no count for them and I did not take a `heap` snapshot
  on the device. The only simulator `heap` snapshot that captured card containers (Baseline, purge off, one run)
  showed 87 live `AsyncStateContainer<ProductCardViewState>`; the other snapshots did not capture the type, so
  treat that as a single data point.
- **Leaks found.** None established. The `leaks` CLI refused simulator processes ("not debuggable", even for
  Debug builds), so its "0 leaks" output is not evidence. Leaks-template traces for Baseline exist in `Profiling/`
  (simulator) but I did not analyze them. Nothing was recorded for Hosted mode.
- **Instruments hitches.** The four Animation Hitches traces each contain **one** app hitch (Baseline 67 ms in both
  purge settings, Hosted 17 ms in both, all flagged "Potentially expensive app update"). Instruments therefore
  sees almost no system-level hitching in any configuration, which is much quieter than the in-app monitor
  suggests. I did not analyze the Time Profiler or SwiftUI traces.
- **Fetch counts depend on timing.** Under Instruments on the simulator, Baseline started 1223 fetches with 348
  cancelled in one run and 948 with 0 cancelled in another. The device numbers above come from the plain
  (no Instruments) runs and were identical across repetitions for "started".

## Does the weak-self patch alone help? (Baseline mode, same scroll script)

| | Started | Cancelled | Completed |
|---|---|---|---|
| Purge off, **with** patch | 1420 | 544 | 876 |
| Purge off, **without** patch | 1420 | 0 | 1420 |
| Purge on, **with** patch | 1582 | 644 | 934 |
| Purge on, **without** patch | 1582 | 0 | 1579 |

- The patch does not change how many fetches start. It cancels the ones whose container was released, so
  **38% fewer fetches run to completion with purge off and 41% fewer with purge on** (a completed fetch whose
  container is already gone is wasted work).
- Without the patch no fetch is ever cancelled, which matches the lifetime tests: released containers keep running.
- Frame pacing was indistinguishable with and without the patch (hitch ms/s 2.0 vs 1.7 purge off, 5.8 vs 5.6 purge
  on, inside the noise).
- This shows fewer wasted fetches. It does **not** show fewer orphaned containers alive at idle, since I did not
  count Baseline containers on the device. The unit tests do show that released containers deallocate.

## What the numbers say

- **Hosted removes the refetching.** 317 fetches for 320 rows, never cancelled, identical with purge on and off.
  Baseline started 4.5x (purge off) to 5x (purge on) as many.
- **Hosted costs memory and, in this measurement, some frame pacing.** The store retains a container per product
  ever seen (317 of 320 after one pass). In-app hitch ms/s was higher for Hosted than Baseline in both purge
  settings (5.0 vs 2.0, 9.3 vs 5.8), though still small in absolute terms, with a maximum frame gap of 69 ms.
  Instruments recorded one hitch either way.

## Surprises

1. **Baseline refetches heavily even with purge off** (1420 fetches for 320 products on iOS 26.7.2). Each
   product is scrolled into view several times by the script, so this is consistent with rows' `@State`
   already being discarded after scrolling off-screen on this OS, or with the script's `scrollTo` jumps. I did
   not isolate which. If it is the OS, "simulate purge" understates how much Baseline already refetches today.
2. **Hosted had the higher in-app hitch numbers.** I do not know why. Candidates: all Hosted cards stay in their
   heavier loaded layout while Baseline cards are often still a cheap spinner; store lookups on every row body pass;
   the cost of rebuilding 320 retained cards under purge. None of these was tested.
3. **Instruments and the in-app monitor disagree** about how many hitches there were (about one vs about 3 to 12).
4. **The simulator cannot run Animation Hitches or the SwiftUI template** ("Hitches is not supported on this
   platform"), and `leaks` rejects simulator apps, so useful hitch data needs the device.

## Open questions for iOS 27

- Does real iOS 27 purging match "simulate purge" (`.id(generation)` rebuilds everything every 3 s, which is
  harsher than purging only off-screen rows)? Run the same matrix with purge off on an iOS 27 device. An iOS 27.0 and 27.2
  simulator runtime is installed, but it was not used.
- Is the Baseline refetching at purge off a real OS behavior? Compare iOS 26.7.2 with iOS 27 and with a
  `LazyVStack` that does not use `scrollTo`.
- Should `ViewStateStore` cap its size (LRU) instead of holding every product? Measure memory with the Allocations
  template on the device.
- Why is Hosted's in-app hitch rate higher, and does it reproduce with more repetitions (n>3) and a longer script?
- Verify no leaks in Hosted mode with Leaks and Allocations on the device. That was not recorded.

## What this does not tell us

One device, one OS version (not iOS 27), 3 repetitions per configuration, a scripted scroll rather than a finger.
Leaks, memory and the Time Profiler and SwiftUI traces are not analyzed here. Treat the table as directional.
