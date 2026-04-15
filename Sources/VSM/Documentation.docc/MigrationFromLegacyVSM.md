# Migrating from VSM 1.x (LegacyVSM) to VSM 2.0

This guide walks you through upgrading an app that was built on **VSM 1.x** (Combine and the old `@ViewState`) so it runs on the **VSM 2.x** package, then moving feature-by-feature to **Swift structured concurrency** and the new APIs.

You do not have to rewrite everything at once. The intended path is: **first get the project building** on the new package with minimal code churn, **then migrate screens one at a time** while the rest of the app still uses the compatibility module.

## How this repository can help

Two demo apps implement the same shopping UI in the old and new styles:

- **LegacyShopping** (`Demos/LegacyShopping/`) — `import LegacyVSM`, `@LegacyViewState`, Combine publishers, a `class`-based product store.
- **Shopping (Swift 6)** (`Demos/Shopping (Swift 6)/`) — `import VSM`, `@ViewState`, ``StateSequence`` and `async`/`await`, an `actor`-based store.

When you are unsure how to translate a pattern, open both Xcode projects and compare the same area of the tree. A good first comparison is the product screen:

- `LegacyShopping/.../Views/Product/ProductViewState.swift` and `Dependencies/ProductRepository.swift`
- `Shopping/.../Views/Product/ProductViewState.swift` and `Dependencies/ProductRepository.swift`

---

## Before you start

The **`VSM`** library in this package is built with **Swift 6** and strict concurrency. The **`LegacyVSM`** library stays on Swift 5 so existing Combine-based code can keep compiling. They are **two separate products** in Package.swift: during migration you may link **both** to the same app target (legacy screens use `LegacyVSM`, migrated screens use `VSM`).

Updating the package and imports is usually quick. Replacing Combine with async/await, ``StateSequence``, and sometimes **actors** for shared data is **the slow part**—plan for incremental work and expect the compiler to teach you where isolation or `Sendable` matters.

---

## Part 1 — Upgrade the package and keep VSM 1-style code working

Do this once for the whole project (or for each module that still uses the old pattern).

### Step 1: Point your app at VSM 2.0 or newer

In Xcode or your `Package.swift`, bump the **vsm-ios** dependency to a **2.0+** release (or your team’s equivalent version that split `LegacyVSM` and `VSM`).

*Why:* Older tutorials assumed a single `import VSM` module. That module is now the **async** framework; the old behavior lives under **`LegacyVSM`**.

### Step 2: Add the LegacyVSM product to targets that still use Combine

For each target that has not been migrated yet, ensure the **LegacyVSM** library is linked (in addition to any future **VSM** linkage for migrated code).

### Step 3: Switch imports from the old module name to LegacyVSM

In every file that still uses **Combine-backed** models and publisher-based `observe`, change:

- `import VSM` → **`import LegacyVSM`**

*Why:* In 2.x, **`import VSM`** is reserved for the new concurrency-based APIs. Your existing 1.x code should import **`LegacyVSM`** until you rewrite that file.

### Step 4: Rename the SwiftUI property wrapper

Anywhere you still have the **1.x** wrapper name, update it:

- `@ViewState` → **`@LegacyViewState`**

If you use UIKit with the legacy rendered wrapper, use **`LegacyRenderedViewState`** the same way you used the old rendered type (details are in the LegacyVSM documentation bundle in the repo).

*Why:* The name **`@ViewState`** in 2.x is tied to ``AsyncStateContainer`` and async observation. **`@LegacyViewState`** is the drop-in for your existing publisher-driven flows.

### Step 5: Build and fix any stragglers

Do a full build. Fix any remaining references to the old module or wrapper **only in files you have not migrated yet**.

**Important:** Avoid a blind project-wide replace. Once a file is migrated to 2.0 (next part), it should use **`import VSM`** and **`@ViewState`**, not LegacyVSM.

At the end of Part 1, **`$state.observe(...)`** should still accept **Combine publishers** wherever you are on LegacyVSM—same mental model as VSM 1.x, new package layout.

---

## Part 2 — Migrate one feature at a time to VSM 2.0

Treat each screen or flow as its own mini project. Start with something small (the **Product** flow in the Swift 6 Shopping demo is a good template).

### Step 1: Choose a single feature and switch it to `import VSM`

For **only** the Swift files in that feature (view + its state types + models + any types only used there), change:

- `import LegacyVSM` → **`import VSM`**
- `@LegacyViewState` → **`@ViewState`**

The compiler will now enforce the **2.0** rules for those files. Everything else in the app can stay on LegacyVSM until you touch it.

### Step 2: Rewrite model actions from publishers to async and ``StateSequence``

In VSM 1.x, actions often returned **`AnyPublisher<YourState, Never>`** (sometimes chaining `Just`, `merge`, `map`, `catch`, etc.). In 2.0, the same “emit several states over time” idea is expressed with:

- **`@StateSequenceBuilder`** and a return type of **`StateSequence<YourState>`** for multi-step flows (for example: show **loading** immediately, then run async work and transition to **loaded** or **error**), and/or
- plain **`async` functions** that return the next **`State`** when a single async step is enough, and/or
- **`AsyncStream<State>`** for more elaborate streams (see <doc:ModelDefinition>).

**Retries and buttons** that used to return publishers should generally become **`() async -> State`** (or similar) in your enum’s associated values, matching the Swift 6 demo.

This step usually forces you to **actually use** async/await: there is no supported path in 2.0 to keep driving the container with **`observe(Publisher)`**. If you are not ready to convert an action, keep that file on **LegacyVSM** until you are.

### Step 3: Update the view’s `observe` calls

Where you previously wrote something like **`$state.observe(loaderModel.load())`** and `load()` returned a publisher, you now pass what the **async** API returns, for example:

- **`$state.observe(model.load())`** when `load()` returns a **`StateSequence`**, or
- another supported overload (async sequence, async closure, etc.—see <doc:ModelActions> and ``AsyncStateContainer``).

The **projected value** `$state` is still the right place to call **`observe`**, but the overloads are concurrency-based, not Combine-based.

### Step 4: Evolve your data layer when the compiler (or design) demands it

Shared **data stores** with mutable state and Combine pipelines were common in 1.x samples. In 2.x, shared stores often become **`actor`** types with **`async throws`** methods, like **`ProductDatabase`** in the Swift 6 demo. That gives you a clear isolation boundary and plays well with strict concurrency.

You might not need actors for every dependency, but when multiple features share mutable state or you see **`Sendable`** / **`sending`** diagnostics, <doc:DataDefinition> explains how VSM 2.0 thinks about main-actor updates, **`sending`**, and optional **`Sendable`** on state.

The Swift 6 product loader also shows **`@concurrent`** on heavier async work when you want to steer runtime behavior; see that file and <doc:ModelDefinition> when you get there.

### Step 5: Watch for the two different types named `StateSequence`

**`LegacyVSM`** and **`VSM`** both define a type named **`StateSequence`**, but they are **not** the same type. The 2.0 one is the rich pipeline used with **`@StateSequenceBuilder`** and ``AsyncStateContainer``.

If a single file **imports both** modules, you can get confusing errors. Prefer **one module per file** during migration, or split legacy and modern code across files.

### Step 6: UIKit-only checklist

- **SwiftUI:** ``ViewState`` follows the availability and behavior described in its documentation.
- **UIKit (iOS 18+):** ``ViewState`` on `UIView` / `UIViewController` relies on UIKit’s observation tracking; you may need **`UIObservationTrackingEnabled`** in **Info.plist**. Full detail is in <doc:ViewDefinition-UIKit>.
- **UIKit (iOS 17):** use **`RenderedViewState`** and the explicit `render()` pattern described there until you can adopt the iOS 18+ path.

---

## Learn Swift structured concurrency

Moving to VSM 2.0 is tightly coupled with learning **async/await**, **tasks**, and often **actors**. These are good starting points:

- [Concurrency — The Swift Programming Language](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html)
- [Swift Concurrency](https://developer.apple.com/documentation/swift/concurrency) (Apple Documentation)
- [Meet Swift Concurrency (WWDC21)](https://developer.apple.com/videos/play/wwdc2021/10132/)

---

## More detail inside this documentation

- **Big picture:** <doc:VSMOverview>
- **Defining state:** <doc:StateDefinition>
- **Models and ``StateSequence``:** <doc:ModelDefinition>
- **Data, concurrency, and “Combine vs VSM 2.0”:** <doc:DataDefinition>
- **SwiftUI views:** <doc:ViewDefinition-SwiftUI>
- **UIKit views:** <doc:ViewDefinition-UIKit>
- **What `observe` can take:** <doc:ModelActions>

**LegacyVSM (Combine era):** Markdown and DocC for the bridge module live under `Sources/LegacyVSM/Documentation.docc` in the vsm-ios repo. Hosted GitHub Pages for this project is generated from the **`VSM`** target only, so open LegacyVSM’s catalog in Xcode or browse that folder on disk for the old articles.

---

## See Also

- ``ViewState``
- ``AsyncStateContainer``
- ``StateSequence``
- ``StateSequenceBuilder``
