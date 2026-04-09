# PR: VSM 2.0 — unconstrained `State` with `sending` (Swift 6)

## Description

This PR builds on top of the `async-vsm` branch (VSM 2.0) to **remove the blanket `Sendable` requirement on `State`**, replacing it with Swift 6’s `sending` keyword and region-based isolation (SE-0430). This means `AsyncStateContainer` now works with **any** `State` type — including non-`Sendable` classes — without sacrificing compile-time safety. The `sending` keyword shifts the proof obligation to the call site: the compiler still rejects unsafe captures (e.g. a non-`Sendable` value used across isolation boundaries), but it no longer requires the `State` type itself to be `Sendable`.

### Key changes

#### `sending` replaces `@Sendable` for core APIs

- `AsyncStateContainer<State>` no longer requires `State: Sendable`. The generic parameter is now unconstrained.
- Core observation methods (`observe`, `refresh`) use `sending @escaping () async -> State` instead of `@escaping @Sendable () async -> State`. The `sending` keyword leverages region-based isolation to prove safety at the call site without requiring `Sendable` conformance on captured values.
- `StateSequence<State>` is similarly unconstrained — its closures use `() -> State` / `() async -> State` instead of `@Sendable` variants. Safety is guaranteed by the `sending` transfer at the `observe` call site.
- `Sendable` conformance on `AsyncStateContainer` is now **conditional**: `extension AsyncStateContainer: Sendable where State: Sendable {}`.
- The `where State: Sendable` overloads (`observe`, `refresh`, legacy Combine methods) remain for ergonomics — the compiler prefers them when `State` is `Sendable`.

#### `refresh(state:)` is now cancellable

- `_refresh` wraps its work in a stored `Task` so that subsequent actions (observe/refresh) can cancel an in-flight refresh via `cancelRunningObservations()`.
- `withTaskCancellationHandler` bridges cancellation from the caller’s task to the stored task, so cancellation works from both directions: container-initiated and caller-initiated.
- Comment documents why `withUnsafeCurrentTask` was ruled out (storing the reference is undefined behavior per Apple docs).

#### `bind` no longer requires `State: Sendable`

- The public `bind` methods are now available for **all** `State` types.
- A private `Binding.safeInit` factory (mirrors Apple’s `Binding.init` but without `@preconcurrency`) and `_safeBindMainActor` prove compiler-verified safety: `@MainActor` closures keep captures in the same isolation region, so neither `self`, `KeyPath`, nor `observedSetter` need `Sendable`.
- Removed `bindAsync` and Publisher-based `bind` overloads (unused in practice).

#### Legacy Combine observation — safe/unsafe split

- **Safe** (requires `State: Sendable`): `observeLegacy(_:firstState:)`, `observeLegacyAsync(_:)`, `observeLegacyBlocking(_:)` — compiler-proven safe via `Sendable` constraint.
- **Unsafe** (any `State`): `observeLegacyUnsafe(_:firstState:)`, `observeLegacyAsyncUnsafe(_:)`, `observeLegacyBlockingUnsafe(_:)` — use `publisher.values` bridge or `@unchecked Sendable` internally. Documented for deletion once callers adopt `Sendable` state types.

#### `StateObserving` protocol removed

- The internal `StateObserving` protocol couldn’t represent `sending` parameters or the safe/unsafe split. Removed in favor of keeping `RenderedViewState` in sync via pass-throughs (Cursor-assisted auditing).

#### `RenderedViewState` and `ViewState` unconstrained

- `RenderedViewState<State>` and `ViewState<State>` no longer require `State: Sendable`.
- All `AsyncStateContainer` API pass-throughs are updated (`sending` parameters, legacy safe/unsafe split).

#### Package and tooling

- `swift-tools-version: 6.2` with `swiftLanguageModes: [.v6]` (enables `sending`, `@concurrent`, and other Swift 6.x features).
- `AsyncAlgorithms` dependency removed from the library target.
- `@preconcurrency import Combine` → `import Combine` (no longer needed).

#### Unsafe code audit

- The entire library has **one** piece of unsafe code: `UnsafeSendableBox<T>: @unchecked Sendable`, used only by `observeLegacyBlockingUnsafe`. It is isolated, documented, and marked for deletion once callers adopt `Sendable` state types.
- **Zero** `@preconcurrency` attributes in source code (only in comments explaining `Binding.safeInit`).
- **Zero** `unsafeBitCast` or `nonisolated(unsafe)` in library source.

#### Tests

- **`NonSendableStateTests`** — covers non-`Sendable` state across `observe`, `refresh`, `StateSequence`, `AsyncStream`, `ViewState`, `bind`, and all legacy **unsafe** Combine variants.
- **`StateContainerTests`** — `refresh` cancellation (container-initiated and caller-initiated), `bind` with Sendable state, safe legacy Combine (`observeLegacy`, `observeLegacyAsync`), and subscription-timing regressions (Passthrough immediate-send drop vs cold `Just`/`append` and `CurrentValueSubject`).
- **`CombineFrameworkIssuesTests`** — documents two known Combine framework issues:
  - **`publisher.values` Sendable gap**: Apple’s `AsyncPublisher` has no `Sendable` constraint on `Output`; a test demonstrates a real data race with `withKnownIssue` — the same risk the “unsafe” legacy methods inherit.
  - **`append` + `delay` + `subscribe(on:)` race**: intermittent Combine bug where completion can fire before the appended publisher emits; documented with `withKnownIssue(isIntermittent: true)`.
- **`@available`** on `AsyncStream`-based tests where required (iOS 18+).

#### DEBUG test recording (package tests only)

- In **DEBUG** builds, `AsyncStateContainer` can opt into an in-memory `debugStateHistory` via `turnOnRecordingStateHistory()`, plus `waitUntilRecordedStateChanges(atLeast:timeout:)` for deterministic assertions.
- **`makeContainer()`** in test targets enables recording; there is **no** SwiftPM trait or environment variable — tests assume **Debug** configuration.
- Doc comments in `AsyncStateContainer` describe **`publisher.values` subscription timing** and mitigations (cold chains, `CurrentValueSubject`, `await`/`Task.yield`), aligned with the tests above.

#### Subscription timing & test style (stability)

- Legacy **async** observation still uses `for await` over `publisher.values`; emissions before the iterator attaches can be dropped (especially `PassthroughSubject`). Tests prefer **cold** `Just(…).append(Just(…))`, **`CurrentValueSubject`** when replay is appropriate, and **recorded history** instead of arbitrary `Task.sleep` / long yield loops where possible.
- **Refresh** cancellation tests intentionally use a **500 ms** sleep inside the refresh body (keep work in flight) and a **`Task.yield()` spin** until the refresh body starts — minimal, documented synchronization without polling sleeps.

### API comparison: `async-vsm` → this branch

| Aspect | `async-vsm` | This branch |
|--------|-------------|-------------|
| `State` constraint | `State: Sendable` required | Unconstrained (any type) |
| Async closures | `@Sendable () async -> State` | `sending () async -> State` |
| `StateSequence` closures | `@Sendable` | Plain closures (safety via `sending` transfer) |
| `Sendable` conformance | Unconditional | Conditional (`where State: Sendable`) |
| `bind` constraint | `State: Sendable` | None (proven safe via `@MainActor` region isolation) |
| Legacy Combine | Single set of methods | Safe (`Sendable`) + Unsafe (any `State`) split |
| `StateObserving` protocol | Present | Removed |
| Unsafe code | N/A | 1 instance (`UnsafeSendableBox`), isolated to legacy blocking method |
| `@preconcurrency` in source | `@preconcurrency import Combine` | Zero — only in comments |
| Swift tools version | 6.0 | 6.2 |

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
- Prefer **safe** legacy Combine APIs when `State: Sendable`; use **unsafe** variants only during migration or for types that cannot be `Sendable`.
- For intermittent failures involving **background-thread publishers**, see `CombineFrameworkIssuesTests` and the note on `testObservingStatePublisherOnBackgroundThread` in `StateContainerTests`.
