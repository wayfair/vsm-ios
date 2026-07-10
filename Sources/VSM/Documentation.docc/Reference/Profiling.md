# Profiling VSM Apps

Choose an Instruments configuration whose measurements reflect production, not the profiler.

## Overview

VSM drives all of a view's state through a single `@Observable` property on ``AsyncStateContainer``, which SwiftUI observes to re-render. This is the correct, modern choice: `@Observable` provides per-property change tracking and avoids the `objectWillChange` bookkeeping of the older `ObservableObject` pattern, so it is cheaper in a shipping app.

There is one thing to be aware of when profiling, however. The **SwiftUI instrument** — the "SwiftUI" template and the View Body / AttributeGraph tracks it enables — adds measurable overhead to every observable state mutation *while it is recording*. That overhead does not exist in normal builds; it is a profiler observer effect. But it can distort a trace enough to send you chasing a cost that isn't real.

## Why the SwiftUI Instrument Inflates State Changes

When the SwiftUI instrument records, AttributeGraph runs in trace-recording mode and emits a trace event for every observed change. To label each event it resolves the changed property's key path name, which the Swift runtime looks up by symbolicating the key path (`dladdr` against the Mach-O symbol table). That symbolication is not cached, so it repeats on every mutation.

In a trace, the cost appears as time attributed to a stack similar to:

```
AsyncStateContainer.state.setter
 → ObservationRegistrar … withMutation
   → AGGraphAddTraceEvent
     → AnyKeyPath.debugDescription → swift_keyPath_copySymbolName → dladdr
```

This is not specific to VSM — any `@Observable` type mutated frequently under the SwiftUI instrument pays it. VSM simply concentrates it: because every transition in a feature flows through one observable property, a burst of transitions (pagination, streaming updates, rapid refreshes) surfaces the cost as a hotspot rather than spreading it thinly.

> Important: This cost is present **only while the SwiftUI instrument is recording**. It is zero in a normal Debug or Release build. Do not try to "optimize" it away by reverting to `ObservableObject` — that trades a profiler-only artifact for real, per-mutation overhead in your shipping app.

## Recommended Instrument Configurations

Pick the instrument set based on the question you are answering:

| Question | Use |
|---|---|
| Scrolling smoothness, hitches, hangs, frame timing | The **Animation Hitches** template (optionally with **Time Profiler**). It does not enable AttributeGraph tracing, so state-mutation cost is not inflated. |
| CPU cost of your own code during a flow | **Time Profiler**, optionally with the **os_signpost** instrument to bracket VSM transitions (see <doc:Debugging>). |
| "Which view bodies re-evaluate, and how often?" | The **SwiftUI** template — accept the observer effect on state mutations as the price of that visibility, and read any state-mutation cost with skepticism. |

For representative hitch and timing numbers on a VSM app, prefer the first two rows. Reserve the SwiftUI template for structural body-evaluation questions, and cross-check any suspicious state-mutation cost against a run recorded without it.

## See Also

- <doc:Debugging>
- ``CustomStateNameConvertible``
- ``AsyncStateContainer``
