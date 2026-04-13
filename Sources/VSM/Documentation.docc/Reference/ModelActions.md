# Model Actions

A reference for choosing the best action types for your VSM models.

## Overview

Actions are responsible for progressing the "State Journey" of a feature and need to be flexible enough to account for any functionality. The VSM framework supports several action types through the `observe()` overloads on ``AsyncStateContainer`` (accessed via the `$state` projected value in ``ViewState`` or ``RenderedViewState``). This article covers each action type and gives examples of when and how to use them.

All action types follow the same **never-throw** design: errors must be caught within the action and converted into an appropriate error view state. The framework does not accept actions that throw.

For **`Sendable` vs non-`Sendable`** state types and which ``AsyncStateContainer`` / `$state` APIs apply in each case, see <doc:DataDefinition> (**Thread Safety and Concurrency** → **Sendable state vs non-Sendable state**).

## Asynchronous State Sequence

```swift
func load() -> StateSequence<UserViewState>
```

This is the most common action shape in VSM. ``StateSequence`` supports three creation styles:

- **`@StateSequenceBuilder` (recommended)**: A result-builder DSL that lets you list synchronous states and ``Next`` closures declaratively. Plain state values placed before any `Next { ... }` are applied **synchronously** by the container, avoiding a one-frame flash.
- **Array-literal syntax**: Return an array of async closures. All closures are treated as asynchronous.
- **Variadic initializer** (`StateSequence({ ... }, { ... })`): Pass async closures directly. All closures are treated as asynchronous.

Use `@StateSequenceBuilder` for initial load flows (typically called from `onAppear`/`viewDidAppear`) so the first frame already reflects the transition state (for example, `.loading`).

Use the array-literal or variadic forms for user-initiated actions on already-visible views (for example, button taps), where a one-tick async delay before the first state is usually imperceptible.

```swift
@StateSequenceBuilder
func load() -> StateSequence<UserViewState> {
    UserViewState.loading                  // applied synchronously
    Next { await self.fetchUser() }        // applied after async work completes
}

@concurrent
private func fetchUser() async -> UserViewState {
    do {
        let user = try await UserRepository().loadUser()
        return .loaded(LoadedModel(user: user))
    } catch {
        return .loadingError(ErrorModel(error: error))
    }
}
```

Errors from async work must be caught and returned as an appropriate error state.

If you prefer the all-async style for user-initiated actions, the array-literal or variadic forms work well:

```swift
func refresh() -> StateSequence<UserViewState> {
    [
        { .loading },
        { await self.fetchUser() }
    ]
}
```

> Note: The `@concurrent` attribute on the private helper moves its execution off the main thread. This is not something you should apply automatically — there is a small cost to hopping threads. Use `@concurrent` with judgement: apply it to work that has a real chance of blocking the main thread, such as large database reads or writes that require sorting through results, network requests that return large amounts of data to parse, or image processing operations. If an action or any function it relies on has the potential to block the main thread for a noticeable amount of time, that is a good signal to mark it `@concurrent`.

## Asynchronous Closure

```swift
func retry() async -> UserViewState
```

Use this action shape when you need to perform async work and return a single state without an interim state. The view calls this via a closure passed to `observe()`.

```swift
func retry() async -> UserViewState {
    do {
        let user = try await UserRepository().loadUser()
        return .loaded(LoadedModel(user: user))
    } catch {
        return .loadingError(ErrorModel(error: error))
    }
}
```

In the view, call it like this:

```swift
Button("Retry") {
    $state.observe { await viewModel.retry() }
}
```

This is a good choice when no interim state is needed and the user expects the result immediately (e.g., fast operations or cases where showing a spinner is not necessary).

## Synchronous State

```swift
func cancel() -> UserViewState
```

Use this action shape when your action immediately returns a single view state without performing any async work. A common example is a cancel button that returns to a previous state.

```swift
func cancel() -> UserViewState {
    return .loaded(userData)
}
```

In the view, pass the result directly to `observe()`:

```swift
Button("Cancel") {
    $state.observe(viewModel.cancel())
}
```

Any errors that occur within this action must be handled with a `do { ... } catch { ... }` block, returning an appropriate view state for the error.

## AsyncStream

```swift
func checkout() -> AsyncStream<CheckoutViewState>
```

Use `AsyncStream` when you need full control over how and when states are emitted throughout a complex, multi-step async operation. Unlike ``StateSequence``, `AsyncStream` lets you yield states at any point within a single async closure.

Because `AsyncStream` is fully asynchronous, the first emitted state is not applied synchronously. If you need a guaranteed synchronous first state transition, use `@StateSequenceBuilder` with plain state values before any `Next` expressions.

```swift
func checkout() -> AsyncStream<CheckoutViewState> {
    AsyncStream { continuation in
        Task {
            continuation.yield(.checkingOut)
            await self.performCheckout(continuation)
            continuation.finish()
        }
    }
}

@concurrent
private func performCheckout(_ continuation: AsyncStream<CheckoutViewState>.Continuation) async {
    do {
        try await CartRepository().checkout()
        continuation.yield(.checkoutComplete)
        try? await Task.sleep(for: .seconds(2))
        continuation.yield(.loaded(LoadedModel(items: [])))
    } catch {
        continuation.yield(.checkoutError(error: error, model: self))
    }
}
```

## Generic AsyncSequence

```swift
func streamUpdates() -> some AsyncSequence<UserViewState, Never>
```

Available on iOS 18+, this overload accepts any `AsyncSequence` whose element type is `State` and failure type is `Never`. This is useful when your data layer vends a custom `AsyncSequence` type that you want to observe directly.

As with `AsyncStream`, generic `AsyncSequence` observation is fully asynchronous. If you need a guaranteed synchronous first state transition, use `@StateSequenceBuilder` with plain state values before any `Next` expressions.

```swift
func streamUpdates() -> AsyncStream<UserViewState> {
    UserRepository().userUpdateStream
        .map { .loaded(LoadedModel(user: $0)) }
}
```

Pass it to `observe()` directly in the view:

```swift
.onAppear {
    $state.observe(viewModel.streamUpdates())
}
```

> Note: The generic `AsyncSequence` overload requires iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, or macCatalyst 18.0. Use ``StateSequence`` or `AsyncStream` for broader OS support.

## No State

```swift
func toggleFavorite()
```

Sometimes you need to call a function on a repository without needing a direct view state result. This action type is valid in VSM when no state change is required. Because there is no return value, you call this directly from the view — **not** through `observe()`.

```swift
func toggleFavorite() {
    sharedFavoritesRepository.toggleFavorite(for: productId)
}
```

In the view:

```swift
Button("Favorite") {
    viewModel.toggleFavorite()
}
```

This pattern is typically paired with an observable repository. A `load()` action observes the repository's data stream, so any future changes to the data automatically update the view state — even without the no-state action returning anything.

```swift
// In LoaderModel:
func load() -> AsyncStream<FavoriteButtonViewState> {
    sharedFavoritesRepository.favoriteStream(for: productId)
        .map { isFavorite in
            .loaded(LoadedModel(isFavorite: isFavorite))
        }
}

// In LoadedModel:
func toggleFavorite() {
    sharedFavoritesRepository.toggleFavorite(for: productId)
}
```

## Pull-to-Refresh

```swift
await $state.refresh(state: { await viewModel.refresh() })
```

When using SwiftUI's `refreshable` modifier, use the `refresh(state:)` method on the container. Unlike `observe()`, this method is `async` and suspends until the state update completes, keeping the pull-to-refresh indicator visible for the full duration of the operation.

```swift
func refresh() async -> UserViewState {
    do {
        let user = try await UserRepository().loadUser()
        return .loaded(LoadedModel(user: user))
    } catch {
        return .loaded(self) // preserve existing state on error
    }
}
```

In the view:

```swift
List { ... }
    .refreshable {
        await $state.refresh(state: { await viewModel.refresh() })
    }
```

## Combine and modern VSM

**VSM 2.0 / modern VSM does not provide a supported `observe` overload for Combine**—not for `Publisher`, and not for `AsyncPublisher` from `publisher.values`. New Apple APIs and platform direction favor Swift concurrency over Combine; Combine’s threading and bridging behavior is also a frequent source of subtle races and hazardous side effects, which is why this module does not integrate publisher observation in 2.0.

If your feature is built around **Combine publishers** for view-state delivery, stay on **VSM 1.x**, which provides that integration. Move to VSM 2.0 when you adopt ``StateSequence``, `AsyncStream`, generic `AsyncSequence` (where available), or async closures for actions.

> Note: In **DEBUG** builds only, the library may compile **unavailable** `observe` overloads that mention `Publisher` so some mistaken call sites fail at compile time. That is a diagnostic aid, not a supported API.

The framework also **does not endorse** ad-hoc publisher bridging in application code (for example turning a `Publisher` into an `AsyncStream` and calling `observe` in a loop): that recreates timing, isolation, and race issues without a supported contract here. For the full rationale—why migration-style Combine APIs were explored and removed, and a table of concrete gaps—see <doc:DataDefinition> (**Combine vs VSM 2.0**).
