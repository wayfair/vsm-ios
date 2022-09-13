# Model Actions - VSM Reference

A reference for choosing the best Action types for your Models

## Overview

Actions are responsible for progressing the "State Journey" of the feature and need to be flexible to account for any functionality. The VSM framework supports several Action types within the `StateContainer`'s `observe()` overloads. This article covers each and gives examples of how to use them appropriately.

## State Publisher

```swift
var loadUser: () -> AnyPublisher<UserViewState, Never>
```

This is the most common action shape used in VSM because it allows the action to return any number of states to the view until another action is called. The ``StateContainer`` accomplishes this through the ``StateContainer/observe(_:)-1uta3`` function by subscribing to the publisher, which is returned from your action. It will only observe (subscribe to) one action at a time. It does this to prevent view state corruption by previously called actions.

The best way to implement this function is to return the Combine publisher result from your data repository. To do this, you will have to convert the data/error output of the repository to the state/never output of the action. This can be done like so:

```swift
loadUser = {
    UserRepository().loadUser()
        .map { userData in UserViewState.loaded(userData) }
        .catch { error in Just(UserViewState.loadingError(error)) }
        .eraseToAnyPublisher()
}
```

If you want to return a loading state for the view to show while the data is being loaded, you can do this by a) merging Combine Publishers or b) by using a `CurrentValueSubject` publisher.

_Figure a._

```swift
loadUser = {
    let dataLoadPublisher = UserRepository().loadUser()
        .map { userData in UserViewState.loaded(userData) }
        .catch { error in Just(UserViewState.loadingError(error)) }

    Just(UserViewState.loading)
        .merge(with: dataLoadPublisher)
        .eraseToAnyPublisher()
}
```

_Figure b._

```swift
loadUser = {
    let stateSubject = CurrentValueSubject<UserViewState, Never>(.loading)
    
    let dataLoadPublisher = UserRepository().loadUser()
        .map { userData in UserViewState.loaded(userData) }
        .catch { error in Just(UserViewState.loadingError(error)) }

    return stateSubject
        .merge(with: dataLoadPublisher)
}
```

> Tip: Combine publishers do not guarantee that the order of operations will follow the order of these statements. When writing unit tests, you may encounter flaky tests that fail when expecting a specific order of states.
>
> To guarantee that the loading view state is always returned before the loaded state, you may need to employ the [`Deferred`](https://developer.apple.com/documentation/combine/deferred) Combine publisher, subscribe to the data publisher on a background queue, or both.
>
> ```swift
> loadUser = {
>     let dataLoadPublisher = Deferred {
>         UserRepository().loadUser()
>                 .map { userData in UserViewState.loaded(userData) }
>                 .catch { error in Just(UserViewState.loadingError(error)) }
>     }
>     .subscribe(on: DispatchQueue.global())
> 
>     Just(UserViewState.loading)
>         .merge(with: dataLoadPublisher)
>         .eraseToAnyPublisher()
> }
> ```

## Asynchronous State Sequence

```swift
var loadUser: () -> StateSequence<UserViewState>
```

This action type allows multiple states to be returned as an [AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence) protocol, which is part of the Swift Concurrency standard library. This is a solid alternative to the State Publisher action type because the code can read a little bit cleaner and it guarantees the order of states without any additional coding.

However, since the `AsyncSequence` is a protocol that "has Self or associated type requirements", we cannot use that type directly. To solve this, the VSM iOS framework provides a custom type called ``StateSequence`` which is a concrete type that conforms to the `AsyncSequence` protocol. It can be used like so:

```swift
loadUser = {
    StateSequence<UserViewState>({
        UserViewState.loading
    }, {
        do {
            let userData try await UserRepository().loadUser()
            return UserViewState.loaded(userData)
        } catch {
            return UserViewState.loadingError(error)
        }
    })
}
```

## Synchronous State

```swift
var cancel: () -> UserViewState
```

This action shape can be used if your action will immediately return a single view state. For example, if your feature can cancel an operation and return to the previous state.

```swift
cancel = {
    return UserViewState.loaded(userData)
}
```

Any errors that are thrown within this action will have to be handled within a `do { ... } catch { ... }` structure, returning a suitable view state to represent the caught error.

## Asynchronous State

```swift
var toggleFavorite: () async -> ProductViewState
```

Like the Synchronous State, this action type returns only a single view state, but it does so asynchronously by using Swift Concurrency. This action type is rarely used because it is a best practice to return an interim state (ie, "loading") while the user waits for the asynchronous operation to complete. In some cases, the interim state may not be necessary, in which case, the following may be used:

```swift
toggleFavorite = {
    let isFavorite = await FavoritesRepository().toggleFavorite(for: productId)
    return ProductViewState.loaded(isFavorite: isFavorite)
}
```

Any errors that are thrown within this action will have to be handled within a `do { ... } catch { ... }` structure, returning a suitable view state to represent the caught error. For example:

```swift
toggleFavorite = {
    do {
        let isFavorite = try await FavoritesRepository().toggleFavorite(for: productId)
        return ProductViewState.loaded(isFavorite: isFavorite)
    } catch {
        return ProductViewState.toggleFavoriteError(error)
    }
}
```

## No State

```swift
var toggleFavorite: () -> Void
```

Sometimes you just need to kick off a process or call a function on a repository without needing a direct view state result. This action type is legal to use in a VSM feature in a situation where a direct state change is required. Do not use the `observe()` function to call this function from the view because the `observe()` function's only purpose is to track view state changes from action invocations.

Normally this action is used in conjunction with an observable repository whose load "State Publisher" action is already being observed by the `StateContainer`. This action can cause the repositories published data to change, which would automatically update the view without having to return any state directly from this function.

```swift
toggleFavorite = {
    sharedFavoritesRepository.toggleFavorite(for: productId)
}
```
