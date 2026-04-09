# PR: VSM 2.0 — unconstrained `State` with `sending` (Swift 6)

## Description

This PR builds on top of the `async-vsm` branch (VSM 2.0) to **remove the blanket `Sendable` requirement on `State`**, replacing it with Swift 6’s `sending` keyword and region-based isolation (SE-0430). This means `AsyncStateContainer` now works with **any** `State` type — including non-`Sendable` classes — without sacrificing compile-time safety. The `sending` keyword shifts the proof obligation to the call site: the compiler still rejects unsafe captures (e.g. a non-`Sendable` value used across isolation boundaries), but it no longer requires the `State` type itself to be `Sendable`.

### Key changes

#### `sending` replaces `@Sendable` for core APIs

- `AsyncStateContainer<State>` no longer requires `State: Sendable`. The generic parameter is now unconstrained.
- Core observation methods (`observe`, `refresh`) use `sending @escaping () async -> State` instead of `@escaping @Sendable () async -> State`. The `sending` keyword leverages region-based isolation to prove safety at the call site without requiring `Sendable` conformance on captured values.
- `StateSequence<State>` is similarly unconstrained — its closures use `() -> State` / `() async -> State` instead of `@Sendable` variants. Safety is guaranteed by the `sending` transfer at the `observe` call site.
- `Sendable` conformance on `AsyncStateContainer` is now **conditional**: `extension AsyncStateContainer: Sendable where State: Sendable {}`.
- The `where State: Sendable` overloads (`observe`, `refresh`) remain for ergonomics — the compiler prefers them when `State` is `Sendable`.

#### `refresh(state:)` is now cancellable

- `_refresh` wraps its work in a stored `Task` so that subsequent actions (observe/refresh) can cancel an in-flight refresh via `cancelRunningObservations()`.
- `withTaskCancellationHandler` bridges cancellation from the caller’s task to the stored task, so cancellation works from both directions: container-initiated and caller-initiated.
- Comment documents why `withUnsafeCurrentTask` was ruled out (storing the reference is undefined behavior per Apple docs).

#### `bind` no longer requires `State: Sendable`

- The public `bind` methods are now available for **all** `State` types.
- A private `Binding.safeInit` factory (mirrors Apple’s `Binding.init` but without `@preconcurrency`) and `_safeBindMainActor` prove compiler-verified safety: `@MainActor` closures keep captures in the same isolation region, so neither `self`, `KeyPath`, nor `observedSetter` need `Sendable`.
- Removed `bindAsync` and Publisher-based `bind` overloads (unused in practice).

#### Combine observation removed from this library

- **No** `observeLegacy*` APIs and **no** first-class `Publisher` observation on `AsyncStateContainer`, `RenderedViewState`, or SwiftUI `$state` pass-throughs.
- Rationale and the full list of problems we were carrying (or pushing onto callers) are summarized below in **Combine support: what we tried and why it’s out of scope here**.
- **Callers who need Combine-driven view state should depend on legacy VSM** (separate target / package), not reimplement bridges in app code — see that section.

#### `StateObserving` protocol removed

- The internal `StateObserving` protocol couldn’t represent `sending` parameters cleanly. Removed in favor of keeping `RenderedViewState` in sync via pass-throughs (Cursor-assisted auditing).

#### `RenderedViewState` and `ViewState` unconstrained

- `RenderedViewState<State>` and `ViewState<State>` no longer require `State: Sendable`.
- All remaining `AsyncStateContainer` API pass-throughs use `sending` where applicable, plus `where State: Sendable` overloads for `observe` / `refresh`.

#### Package and tooling

- `swift-tools-version: 6.2` with `swiftLanguageModes: [.v6]` (enables `sending`, `@concurrent`, and other Swift 6.x features).
- `AsyncAlgorithms` dependency removed from the library target.
- **No** `import Combine` in library sources.

#### Unsafe code audit

- **No** `@unchecked Sendable` shims in the library for Combine bridging (those lived on the removed blocking-legacy path).
- **Zero** `@preconcurrency` attributes in source code (only in comments explaining `Binding.safeInit`).
- **Zero** `unsafeBitCast` or `nonisolated(unsafe)` in library source.

#### Tests

- **`NonSendableStateTests`** — non-`Sendable` state across `observe`, `refresh`, `StateSequence`, `AsyncStream` (where available), `ViewState`, and `bind`.
- **`StateContainerTests`** — `refresh` cancellation (container-initiated and caller-initiated), `bind` with Sendable state, `StateSequence` / `AsyncStream` ordering, synchronous-first-frame behavior for builder-based sequences, and related regressions.
- **`@available`** on `AsyncStream`-based tests where required (iOS 18+).
- Publisher / Combine-specific tests and `CombineFrameworkIssuesTests` were **removed** with the APIs (issues below remain valid for anyone still using Combine elsewhere).

#### DEBUG test recording (package tests only)

- In **DEBUG** builds, `AsyncStateContainer` can opt into an in-memory `debugStateHistory` via `turnOnRecordingStateHistory()`, plus `waitUntilRecordedStateChanges(atLeast:timeout:)` for deterministic assertions.
- **`makeContainer()`** in test targets enables recording; there is **no** SwiftPM trait or environment variable — tests assume **Debug** configuration.

#### Refresh cancellation tests (stability)

- **Refresh** cancellation tests intentionally use a **500 ms** sleep inside the refresh body (keep work in flight) and a **`Task.yield()` spin** until the refresh body starts — minimal, documented synchronization without polling sleeps.

---

## Combine support: what we tried and why it’s **not** in this package

We previously explored (and in some iterations shipped) **migration-style** Combine observation: wrapping `Publisher<State, Never>` with a **safe** surface when `State: Sendable`, and **unsafe** variants for arbitrary `State`, plus a **blocking** `sink` path to reduce first-frame timing gaps. We **removed** all of that from VSM 2.0 in this repo. Below is a concise recap of the **gaps and costs** that combination imposed — these are largely **Apple framework / bridging** behaviors, not bugs unique to VSM, but they are exactly why we do not want to own Combine in the modern target.

| Area | What goes wrong |
|------|------------------|
| **`publisher.values` / `AsyncPublisher`** | The async iterator is installed from a `Task`, so emissions that happen **immediately after** the call returns (same actor, no `await`) can occur **before** subscription — **`PassthroughSubject`** can **drop** values with no error. Mitigations (cold chains, `CurrentValueSubject`, `await` / `Task.yield`) are easy to get wrong at every call site. |
| **Sendable vs reference types** | Apple’s `.values` bridge does **not** require `Output: Sendable`. For **non-`Sendable` classes**, the same reference can cross execution contexts with only handoff synchronization — **data races on mutable class state** are a real risk (we had tests demonstrating this class of issue). |
| **`observeLegacyAsync`-style paths** | Every publisher-driven value, **including the first**, is applied only after a **hop**. That can cause **first-frame flicker** or mismatches with “show loading synchronously” expectations unless the caller carefully chooses APIs or initial state. |
| **Blocking `sink` path** | To capture a **first** synchronous emission without that hop, the natural tool is **subscribe-then-drain** with a lock-assisted buffer — which **blocks the calling thread** briefly during subscription. That’s a sharp edge for UI code. |
| **Combine operator races** | Patterns such as **`.append` + `.delay` + `.subscribe(on:)`** can complete in an order where **`sink` sees completion before appended values** — any subscriber is affected; not VSM-specific but it showed up in publisher-based integration tests. |
| **Safe vs unsafe matrix** | Supporting both **Sendable-only “safe”** APIs and **unchecked / unsafe** bridges for non-`Sendable` state duplicated semantics, documentation, and tests, and still left callers one mistake away from subtle races or dropped events. |

### Product stance

- **We do not support or recommend** ad-hoc **app-level bridging** (e.g. `Publisher` → `AsyncStream` → repeated `observe(_:)`) as a substitute for first-class library support. Those patterns **reproduce the same timing, isolation, and race issues** without a single supported contract or test matrix in this module.
- If your architecture is still **Combine-first** for view-state delivery, use **legacy VSM** (dedicated target / package) for Combine observation until you migrate to **`StateSequence`**, **`AsyncStream`**, or **async closures** here.

---

### API comparison: `async-vsm` → this branch

| Aspect | `async-vsm` | This branch |
|--------|-------------|-------------|
| `State` constraint | `State: Sendable` required | Unconstrained (any type) |
| Async closures | `@Sendable () async -> State` | `sending () async -> State` |
| `StateSequence` closures | `@Sendable` | Plain closures (safety via `sending` transfer) |
| `Sendable` conformance | Unconditional | Conditional (`where State: Sendable`) |
| `bind` constraint | `State: Sendable` | None (proven safe via `@MainActor` region isolation) |
| Combine observation | Present (various forms) | **Removed** — use legacy VSM for Combine |
| `StateObserving` protocol | Present | Removed |
| Unsafe code for Combine | Various bridging shims | **None** in this target |
| `@preconcurrency` in source | `@preconcurrency import Combine` (when Combine was linked) | **Zero** — only in comments where relevant |
| Swift tools version | 6.0 | 6.2 |

### API reference — surface & variants

The following are the **primary entry points** on `AsyncStateContainer<State>` (and are **mirrored** on `RenderedViewState` / `$` access where applicable). Methods split into **unconstrained** (`sending`) vs **`where State: Sendable`** overloads; the compiler picks the `Sendable` overload when `State` conforms.

#### Core observation, sequences, and refresh

| API | `State` constraint | Role |
|-----|---------------------|------|
| `observe(_ nextState: sending State)` | None | Apply a concrete next state (transfer at call site). |
| `observe(_ nextStateClosure: sending @escaping () async -> State)` | None | Async closure produces next state (`sending` proof at call site). |
| `observe(_ stateSequence: sending StateSequence<State>)` | None | `StateSequence` / builder-driven multi-step updates. |
| `observe(_ sequence: some AsyncSequence<State, Never>)` | None | `AsyncStream` and other non-throwing async sequences (platform availability applies). |
| `refresh(state nextStateClosure: sending @escaping () async -> State) async` | None | Same shape as async `observe`, but **async** entry and **cancellable**. |
| `observe(_ nextStateClosure: @escaping @Sendable () async -> State)` | `where State: Sendable` | Ergonomic overload when state is `Sendable`. |
| `refresh(state nextState: @escaping @Sendable () async -> State) async` | `where State: Sendable` | Sendable overload for `refresh`. |

#### `bind` (SwiftUI)

| API | `State` constraint | Role |
|-----|---------------------|------|
| `bind<Value>(_:to: (State, Value) -> State) -> Binding<Value>` | None | Two-way binding via key path + reducer (both overloads are `@MainActor`-isolated). |
| `bind<Value>(_:to: (State) -> (Value) -> State) -> Binding<Value>` | None | Curried setter form. |

### Type of change

- [x] New feature
- [x] Breaking change
- [x] Refactor

### Checklist

- [x] I have read the contributing guidelines
- [x] Existing issues have been referenced (where applicable)
- [x] I have verified this change is not present in other open pull requests
- [x] Functionality is documented
- [x] All code style checks pass
- [x] New code contribution is covered by automated tests
- [x] All new and existing tests pass

### Reviewer notes

- Call sites that previously relied on `State: Sendable` should compile with `sending` where values are produced in a valid region; **unsafe captures** may surface as new diagnostics — that is expected.
- **`Sendable` on view state is optional** in 2.0: add it **surgically** when nested types already justify it or when you want `@Sendable` / `Sendable` container semantics—not as a blanket requirement. **`actor`**-confined classes and valid **`sending`** transfers are often enough without marking `State: Sendable`.
- **Combine** is intentionally out of scope for this target; teams still on publishers should stay on **legacy VSM** until migration to `StateSequence` / `AsyncStream` / async closures — not unsupported hand-rolled bridges in app code.
