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

This action type allows multiple states to be returned as an [AsyncSequence](https://developer.apple.com/documentation/swift/asyncsequence) protocol, which is part of the Swift Concurrency standard library. It is a solid alternative to the State Publisher action type because the code can read a little bit cleaner and guarantees the order of states without additional coding.

However, since the `AsyncSequence` is a protocol that "has Self or associated type requirements," we cannot use that type directly. To solve this problem, the VSM iOS framework provides a custom type called ``StateSequence``, a concrete type that conforms to the `AsyncSequence` protocol. You can use it like so:

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

You can use this action shape if your action immediately returns a single view state. For example, if you have a button that cancels an operation and returns to the previous state.

```swift
cancel = {
    return UserViewState.loaded(userData)
}
```

Any errors thrown within this action must be handled within a `do { ... } catch { ... }` structure, returning an appropriate view state to represent the caught error.

## Asynchronous State

```swift
var toggleFavorite: () async -> ProductViewState
```

Like the Synchronous State, this action type returns only a single view state, but it does so asynchronously using Swift Concurrency. This action type is rarely used because it is a best practice to return an interim state (i.e., "loading") while the user waits for the asynchronous operation to complete. In some cases, the interim state may not be necessary, in which case, the following may be used:

```swift
toggleFavorite = {
    let isFavorite = await FavoritesRepository().toggleFavorite(for: productId)
    return ProductViewState.loaded(isFavorite: isFavorite)
}
```

Any errors thrown within this action must be handled within a `do { ... } catch { ... }` structure, returning an appropriate view state to represent the caught error. For example:

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

Sometimes you need to kick off a process or call a function on a repository without needing a direct view state result. This action type is usable in a VSM feature in situations where a direct view state change is _not_ required. You can't use the `observe()` function to call this function from the view because the `observe()` function's only purpose is to track view state changes from action invocations.

```swift
toggleFavorite = {
    sharedFavoritesRepository.toggleFavorite(for: productId)
}
```

Usually, this action type is used in conjunction with an observable repository. A `load()` action would map the data from the repository's data publisher into a view state for the view to render. The ``StateContainer`` will hold on to that view state subscription (and, consequently, the repository data subscription) indefinitely unless another action is observed. Any future changes to the data will translate instantly into a change in the view.

For example, if you used the `load` action below, the view would always be updated when the data changes, even though the `toggleFavorite` action doesn't return any new view states.

```swift
load = {
    sharedFavoritesRepository.favoritePublisher(for: productId)
        .map { isFavorite in 
            FavoriteButtonViewState.loaded(
                isFavorite: isFavorite,
                toggleFavorite: {
                    sharedFavoritesRepository.toggleFavorite(for: productId)
                }
            )
        }
        .eraseToAnyPublisher()
}
```
