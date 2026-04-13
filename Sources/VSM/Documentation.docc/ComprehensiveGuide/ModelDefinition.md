# Building the Model in VSM

A guide for implementing business logic with Models in VSM

## Overview

One of the unique things about the VSM architecture is its philosophy on how models work. In VSM, models encapsulate the functionality of the feature, similar to models in other architectures. However, VSM models are divided into multiple "mini-view-models" by view state. This allows the compiler to protect certain data and functionality from being accessed in unintended ways or at unintended times. It also helps the engineer create simpler, [least-knowledge](https://en.wikipedia.org/wiki/Law_of_Demeter), and sometimes [single-purposed](https://en.wikipedia.org/wiki/Single-responsibility_principle) models which are easy to test and maintain.

> Tip: Building VSM models requires an understanding of [finite state machines](https://en.wikipedia.org/wiki/Finite-state_machine) and simple [recursion](https://www.vadimbulavin.com/recursion-in-swift/).

There are multiple styles for building models in VSM. You can read more about each pattern in <doc:ModelStyles>. In this article, we will be focusing on the <doc:ModelStyles#Plain-Structs> pattern where each model is implemented as a plain struct with `async` methods. This is the recommended default style.

We will continue from <doc:StateDefinition> by implementing the business logic for the models associated with `LoadUserProfileViewState` and the `EditUserProfileViewState`.

As a refresher, the state flow chart is as follows, with the `LoadUserProfileViewState` corresponding to the finite state machine on the left and the `EditUserProfileViewState` on the right:

![VSM State Flow Diagram Example](vsm-state-flow-example.jpg)

## Load Profile View Models

First, we'll take a look at the shape of the `LoadUserProfileViewState` and its corresponding behavior in the above state flow chart.

```swift
enum LoadUserProfileViewState {
    case initialized(LoaderModel)
    case loading
    case loadingError(LoadingErrorModel)
    case loaded(UserData)
}

struct LoaderModel {
    let userId: Int
    func load() -> StateSequence<LoadUserProfileViewState>
}

struct LoadingErrorModel {
    let message: String
    let userId: Int
    func retry() -> StateSequence<LoadUserProfileViewState>
}
```

After we have a good idea of how the states and data should flow, we can begin implementing the model by creating a struct that conforms to the above shape. Our entire implementation for this model will live in this struct.

```swift
struct LoaderModel {
    let userId: Int
    ...
}
```

To implement the model in a readable way, we'll define the `load()` function to orchestrate the load work by returning the appropriate view states as the data loads. The `load()` function returns a `StateSequence` that applies `.loading` synchronously first, then calls `fetchUser()` which performs the data request asynchronously. We use the ``StateSequenceBuilder`` DSL to declare this sequence — plain state values listed before any `Next` expression are applied synchronously, ensuring the loading indicator is visible on the very first frame.

```swift
struct LoaderModel {
    let userId: Int

    @StateSequenceBuilder
    func load() -> StateSequence<LoadUserProfileViewState> {
        LoadUserProfileViewState.loading
        Next { await fetchUser() }
    }
}
```

The `fetchUser()` function loads the user data (from a web service, cache, or database) and returns the appropriate view state. (We will cover proper dependency injection in <doc:DataDefinition>.)

Upon completion of the request, the function returns the `.loaded` view state containing the user data. Errors are caught inside the function and converted to an appropriate error state — the framework never accepts throwing actions.

```swift
struct LoaderModel {
    let userId: Int

    @StateSequenceBuilder
    func load() -> StateSequence<LoadUserProfileViewState> {
        LoadUserProfileViewState.loading
        Next { await fetchUser() }
    }

    @concurrent
    private func fetchUser() async -> LoadUserProfileViewState {
        do {
            let userData = try await UserDataRepository().load(userId: userId)
            return .loaded(userData)
        } catch {
            return handleLoadingError(error)
        }
    }
}
```

> Tip: The `@concurrent` attribute moves `fetchUser()` off the main thread. Apply it to helper functions that have a real chance of blocking the main thread — such as network requests or large database reads. Do not apply it automatically; there is a small cost to hopping threads.

To improve readability, we'll forward the error handling code to a `handleLoadingError()` function. This error handler categorizes the error into the most appropriate view state and can perform any logging necessary.

```swift
struct LoaderModel {
    let userId: Int

    ...

    private func handleLoadingError(_ error: Error) -> LoadUserProfileViewState {
        Logger().error("Error loading user data: \(error)")
        let errorModel = LoadingErrorModel(userId: userId, error: error)
        return .loadingError(errorModel)
    }
}
```

In this function, we log the error and create a `LoadingErrorModel` for the `.loadingError` view state. That causes the view to show the error state, which renders an error message and a retry button.

Our final Load Profile model looks like this:

```swift
struct LoaderModel {
    let userId: Int

    @StateSequenceBuilder
    func load() -> StateSequence<LoadUserProfileViewState> {
        LoadUserProfileViewState.loading
        Next { await fetchUser() }
    }

    @concurrent
    private func fetchUser() async -> LoadUserProfileViewState {
        do {
            let userData = try await UserDataRepository().load(userId: userId)
            return .loaded(userData)
        } catch {
            return handleLoadingError(error)
        }
    }

    private func handleLoadingError(_ error: Error) -> LoadUserProfileViewState {
        Logger().error("Error loading user data: \(error)")
        return .loadingError(LoadingErrorModel(userId: userId, error: error))
    }
}
```

Now you may be asking, "where do we define the error message and retry behavior for the error state?". We will implement the error state's behavior in a separate model, like so:

```swift
struct LoadingErrorModel {
    let userId: Int
    let message: String

    init(userId: Int, error: Error) {
        self.userId = userId
        message = error.localizedDescription
    }

    func retry() -> StateSequence<LoadUserProfileViewState> {
        LoaderModel(userId: userId).load()
    }
}
```

This is where a tiny bit of recursion comes in. We want the retry action to call the `load()` function on our loader model again. Because we're in a separate model, we build a new `LoaderModel` and call its `load()` function directly.

Since these are structs, the create/copy/destroy operations are generally very inexpensive, as long as the models and associated value types stay relatively small.

The Load User Profile models are now complete and ready for testing. To learn more about testing, visit <doc:UnitTesting>.

You may have noticed that we don't dispatch to the main queue anywhere in this code. This is because `AsyncStateContainer` is `@MainActor`-isolated, which guarantees that all state changes occur on the main thread automatically.

> Tip: In VSM, you never have to worry about syncing your view states with the main thread.

You may also have noticed that we don't use `[weak self]` in any of our closures. This is because we are exclusively using structs instead of classes. ``StateSequence`` stores plain producing closures; when you call `observe(_:)` on ``AsyncStateContainer``, transfers use Swift 6 **`sending`** (and **`@Sendable`** overloads when `State: Sendable`). Capturing structs by value avoids strong reference cycles with `self`.

> Tip: Avoid using classes for your models. This removes the need for capturing `[weak self]` within closures.

## Edit Profile View Models

First, we'll take a look at the shape of the `EditUserProfileViewState` and its corresponding behavior in the state flow chart near the top of the article.

```swift
struct EditUserProfileViewState {
    var data: UserData
    var editingState: EditingState

    enum EditingState {
        case editing(EditingModel)
        case saving
        case savingError(SavingErrorModel)
    }
}

struct EditingModel {
    func save(username: String) -> StateSequence<EditUserProfileViewState>
}

struct SavingErrorModel {
    let message: String
    func retry() -> StateSequence<EditUserProfileViewState>
    func cancel() -> EditUserProfileViewState
}
```

After we have a good idea of how the states and data should flow, we can begin implementing the editing model of the `EditUserProfileViewState` by creating the corresponding model struct.

```swift
struct EditingModel {
    let userData: UserData

    @StateSequenceBuilder
    func save(username: String) -> StateSequence<EditUserProfileViewState> {
        EditUserProfileViewState(
            data: userData,
            editingState: .saving
        )
        Next { await performSave(username: username) }
    }
}
```

Similar to the load action from the Load Profile model, we apply a new `.saving` state synchronously while the save operation is processing. Using `@StateSequenceBuilder`, the plain state value placed before the `Next` expression is applied synchronously by the container.

Next, we'll implement the `performSave()` function by using the `UserDataRepository` to save the username to the data source. (We will cover proper dependency injection in <doc:DataDefinition>.)

```swift
struct EditingModel {
    let userData: UserData

    ...

    @concurrent
    private func performSave(username: String) async -> EditUserProfileViewState {
        do {
            let savedUserData = try await UserDataRepository().save(username: username)
            return EditUserProfileViewState(
                data: savedUserData,
                editingState: .editing(EditingModel(userData: savedUserData))
            )
        } catch {
            return handleSavingError(error, username: username)
        }
    }
}
```

Similar to the Load Profile model, this function instantiates a repository, saves the username, and then returns the appropriate "success" view state. We handle the error in a similar way as the Load Profile model.

```swift
struct EditingModel {
    let userData: UserData

    ...

    private func handleSavingError(_ error: Error, username: String) -> EditUserProfileViewState {
        Logger().error("Error saving username: \(error)")
        let errorModel = SavingErrorModel(
            error: error,
            username: username,
            userData: userData
        )
        return EditUserProfileViewState(
            data: userData,
            editingState: .savingError(errorModel)
        )
    }
}
```

The final editing view model becomes this:

```swift
struct EditingModel {
    let userData: UserData

    @StateSequenceBuilder
    func save(username: String) -> StateSequence<EditUserProfileViewState> {
        EditUserProfileViewState(
            data: userData,
            editingState: .saving
        )
        Next { await performSave(username: username) }
    }

    @concurrent
    private func performSave(username: String) async -> EditUserProfileViewState {
        do {
            let savedUserData = try await UserDataRepository().save(username: username)
            return EditUserProfileViewState(
                data: savedUserData,
                editingState: .editing(EditingModel(userData: savedUserData))
            )
        } catch {
            return handleSavingError(error, username: username)
        }
    }

    private func handleSavingError(_ error: Error, username: String) -> EditUserProfileViewState {
        Logger().error("Error saving username: \(error)")
        let errorModel = SavingErrorModel(
            error: error,
            username: username,
            userData: userData
        )
        return EditUserProfileViewState(
            data: userData,
            editingState: .savingError(errorModel)
        )
    }
}
```

Now, we must build the error model to implement the error message data, retry action, and cancel action, according to the requirements. This model requires some extra data to properly implement the corresponding actions. Using the same techniques discussed above, our error model looks like this:

```swift
struct SavingErrorModel {
    let message: String
    let username: String
    let userData: UserData

    init(error: Error, username: String, userData: UserData) {
        message = "Error saving username: \(error.localizedDescription)"
        self.username = username
        self.userData = userData
    }

    func retry() -> StateSequence<EditUserProfileViewState> {
        EditingModel(userData: userData).save(username: username)
    }

    func cancel() -> EditUserProfileViewState {
        EditUserProfileViewState(
            data: userData,
            editingState: .editing(EditingModel(userData: userData))
        )
    }
}
```

You'll notice several examples of recursive programming where some actions need to go back to previous states and those states have actions that can lead back to the state in question. In each case, we build a new view state and pass in the dependencies and data required for the view state's model.

Notice that `cancel()` returns a single `EditUserProfileViewState` synchronously — no async work is needed, so no `StateSequence` is required. The `retry()` action delegates back to the `EditingModel`'s `save()` function, which handles the full `StateSequence` progression.

This "always forward" progression from state to state can be called the "state journey".

## Avoid MVVM Pitfalls

MVVM is currently the most prevalent architecture. Most of Apple's training material and SwiftUI guides use some form of MVVM. If you are already familiar with building features in MVVM, you may be tempted to do any of the following when implementing VSM models:

- Make your model a class type
- Use a single model to manage all of your states and actions
- Declare the model as `ObservableObject` and use `@Published` properties to internally manage the current state, or your internal states and data
- Manage concurrency by storing and manually cancelling `Task` handles within your model
- Load the data and then call a separate action from the view to subscribe to future data updates

None of these practices are appropriate for use in a VSM feature. If any of these techniques sneak into your feature, it becomes difficult to follow the pattern and see the benefits of building features that observe and interact with a stream of view states.

It is generally less effective to use class types for models in VSM. Classes introduce the risk of memory leaks due to accidental strong-self captures within closures. Because states in VSM are largely ephemeral and have short lifespans, classes increase the cost of state transitions. They also don't come with the benefit of implicit internal initializers like structs do.

"Massive View Model" types tend to violate several [SOLID](https://en.wikipedia.org/wiki/SOLID) architecture principles and introduce the potential for bugs from shared mutable data and unprotected functions. This applies as well to models that manage state by using `@Published` properties. They tend to be a hotbed for bugs caused by unintended states, side effects, and regressions.

Manually managing `Task` handles or `AsyncStream.Continuation`s within a model is less effective in VSM because it's much easier (and requires much less code) to let the state container manage the lifecycle for you. You can do this within your actions by weaving multiple async operations into a single `StateSequence` or `AsyncStream`. This also eliminates the need to make any round-trips to the view to trigger actions that observe future updates.

## Up Next

### Working with Data Repositories

Now that we have covered how to build models in VSM, we can learn the power of shared, observable data repositories to hydrate our features and eliminate view and data synchronization bugs in <doc:DataDefinition>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
