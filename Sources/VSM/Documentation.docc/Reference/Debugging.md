# Debugging State Machines

Trace and visualize state changes in your VSM views using Console logging and Instruments.

## Overview

`AsyncStateContainer` provides two complementary debugging tools built on Apple's unified logging system: **structured Console logging** that shows state transitions as they happen, and **OS signposts** that let you visualize those transitions as a timeline in Instruments. Both are controlled by the same parameters you pass to ``ViewState`` or ``RenderedViewState``.

## Console Logging

### Enabling Logging Per View

Console logging is disabled by default. Leaving it always on would flood Xcode's Console with output from every view in your app simultaneously, making it harder to focus on the view you care about. Instead, turn it on for individual views while you are actively debugging them.

To enable logging for a SwiftUI view, pass `loggingEnabled: true` to the `@ViewState` property wrapper:

```swift
struct ProductDetailView: View {
    @ViewState(loggingEnabled: true)
    var state: ProductDetailViewState = .initialized(.init())

    var body: some View {
        // ...
    }
}
```

For a UIKit view controller using `@RenderedViewState`:

```swift
class ProductDetailViewController: UIViewController {
    @RenderedViewState(render: ProductDetailViewController.render, loggingEnabled: true)
    var state: ProductDetailViewState = .initialized(.init())

    func render() {
        // ...
    }
}
```

When enabled, you will see `.debug`-level log messages in the Console that describe each state machine event — when observations start, when states change, and when sequences complete or are cancelled.

### Filtering Console Output

Because VSM state change messages are logged at the `.debug` level, Xcode's Console will hide them by default. To see them:

1. Open **Xcode's Console** (View > Debug Area > Activate Console, or `⇧⌘C`).
2. Click the **filter icon** in the Console toolbar and enable the **Info** filter level (or **Debug** for maximum verbosity). This ensures `.debug`-level messages are visible alongside the standard output.
3. Optionally, type a string in the Console's search field to narrow output further — for example the subsystem `com.wayfair.vsm` or the name of a specific view type.

> Tip: The Info filter is the recommended starting point. It shows state change messages without surfacing every internal OS log message from the system.

![An example of VSM state change log output in Xcode's Console, showing subsystem, category, and state transition messages](ExampleLogging)

### Customizing the Logging Subsystem

All VSM logging uses the subsystem `"com.wayfair.vsm"` by default. If your app has its own logging subsystem or you need to distinguish VSM logs in a mixed-logging environment, you can override it. Providing `observedViewType` at the same time sets the log category to the view's type name, which makes the subsystem and category columns in the Console immediately useful as filters:

```swift
struct ProductDetailView: View {
    @ViewState(
        subsystem: "com.myapp.vsm",
        observedViewType: ProductDetailView.self,
        loggingEnabled: true
    )
    var state: ProductDetailViewState = .initialized(.init())
}
```

The `subsystem` value maps directly to an `OSLog` subsystem and the type name becomes its `category`, so both columns appear in the Console and can be used to filter output to exactly the view you are debugging.

### Identifying Views in the Log Output

When you enable logging for more than one view at the same time, it can be difficult to tell which log messages belong to which view. Pass `observedViewType` to tag each view's log output with its type name:

```swift
struct ProductDetailView: View {
    @ViewState(observedViewType: ProductDetailView.self, loggingEnabled: true)
    var state: ProductDetailViewState = .initialized(.init())
}

struct CartView: View {
    @ViewState(observedViewType: CartView.self, loggingEnabled: true)
    var state: CartViewState = .initialized(.init())
}
```

The type name becomes the `category` of the underlying `OSLog`. Xcode's Console displays the category alongside each message, making it straightforward to filter by view name. When `observedViewType` is not provided, all log output lands in the generic `"VSM View"` category.

> Note: `@RenderedViewState` always infers the view type from the `render` parameter, so there is no separate `observedViewType` argument — the parent type is used automatically.

## Instruments: Visualizing State Changes with OS Signposts

In addition to Console logging, `AsyncStateContainer` emits **OS signposts** for every state transition. Signposts are always active, regardless of the `loggingEnabled` flag, and they let you visualize state machine activity on a precise timeline in Instruments alongside other instruments such as the SwiftUI instrument.

This makes it easy to answer questions like: "Did a state change cause a surge of SwiftUI body re-evaluations?" or "How long did the app spend in the loading state?"

### Adding the os_signpost Instrument

The os_signpost instrument is not included in any of Instruments' built-in templates, so you need to add it manually:

1. Open **Instruments** (Xcode > Open Developer Tool > Instruments, or `⌘I` from Xcode).
2. Choose any template to start — **Blank** is the cleanest option if you plan to build your own instrument set.
3. Click the **+** button in the instrument library (top-right area of the Instruments toolbar) to open the instrument picker.
4. Search for **"os_signpost"** and double-click it to add it to your trace document.
5. Profile your app. VSM signpost intervals will appear in the os_signpost track as labelled intervals.

### Reading the Signpost Lanes

Each call to `observe()` on a state container produces a signpost interval. The interval begins when the observation starts and ends when the resulting state change is applied. For `StateSequence` observations, a single interval spans the entire sequence, with individual state changes marked as events within it.

The signpost lane name is derived from the same `subsystem` and `observedViewType` values passed to the property wrapper:

- If you use the defaults, all state changes across every view land in a single lane named `"com.wayfair.vsm"` under the `"VSM View"` category. This can become crowded quickly in an app with many VSM views.
- If you provide a `subsystem` and `observedViewType`, each view gets its own clearly labelled lane, making it straightforward to correlate a specific view's state changes with other timeline data.

For best results in Instruments, configure each view that you are profiling with both parameters:

```swift
struct ProductDetailView: View {
    @ViewState(
        subsystem: "com.myapp.vsm",
        observedViewType: ProductDetailView.self
    )
    var state: ProductDetailViewState = .initialized(.init())
}
```

![An example of VSM signpost intervals in Instruments, showing per-view state change lanes on the os_signpost timeline](ExampleInstruments)

> Tip: You do not need to enable `loggingEnabled` to get signpost data in Instruments. Signpost calls are always made by `AsyncStateContainer`, but the OS discards them at negligible cost unless Instruments is actively recording a trace. There is no special build configuration required — you can profile a Debug build directly from Xcode using **Product > Profile** (`⌘I`).
