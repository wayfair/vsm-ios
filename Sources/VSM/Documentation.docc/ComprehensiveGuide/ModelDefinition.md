# Implementing the Business Logic in VSM

A guide for implementing business logic with Models in VSM

## Overview

One of the unique things about the VSM architecture is its philosophy on how models work. In VSM, models encapsulate the functionality of the feature, similar to models in other architectures. However, VSM models are divided into multiple "mini-view-models" by view state. This allows the compiler to protect certain data and functionality from being accessed in unintended ways or at unintended times. It also helps the engineer create simpler, [least-knowledge](https://en.wikipedia.org/wiki/Law_of_Demeter), and sometimes [single-purposed](https://en.wikipedia.org/wiki/Single-responsibility_principle) models which are easy to test and maintain.

> Tip: Building VSM models requires an understanding of [finite state machines](https://en.wikipedia.org/wiki/Finite-state_machine) and simple [recursion](https://www.vadimbulavin.com/recursion-in-swift/).

There are multiple styles for building models in VSM. You can read more about each pattern in <doc:ModelPatterns>. In this article, we will be focusing on the "Protocol" pattern where each model implements its functionality by creating structs that implement the protocol requirements. We recommend that you use the "Protocol" model style by default.

We will continue from <doc:StateDefinition> by implementing the business logic for the models associated with `LoadUserProfileViewState` and the `EditUserProfileViewState`.

As a refresher, the state flow chart is as follows, with the `LoadUserProfileViewState` corresponding to the finite state machine on the left and the `EditUserProfileViewState` on the right:

![VSM State Flow Diagram Example](vsm-state-flow-example.jpg)

## Load Profile View Models

First, we'll take a look at the shape of the `LoadUserProfileViewState` and its corresponding behavior in the above state flow chart.

```swift
enum LoadUserProfileViewState {
    case initialized(LoaderModeling)
    case loading
    case loadingError(LoadingErrorModeling)
    case loaded(UserData)
}

protocol LoaderModeling {
    func load() -> AnyPublisher<LoadUserProfileViewState, Never>
}

protocol LoadingErrorModeling {
    let message: String
    func retry() -> AnyPublisher<LoadUserProfileViewState, Never>
}
```

After we have a good idea of how the states and data should flow, we can begin implementing the model by creating a struct that implements the corresponding model protocol. Our entire implementation for this model will live in this struct.

```swift
struct LoaderModel: LoaderModeling {
    ...
}
```

Next, we'll create an initializer that collects the data required for the `load()` action.

```swift
struct LoaderModel: LoaderModeling {
    let userId: Int

    init(userId: Int) {
        self.userId = userId
    }
}
```

To implement the model in a readable way, we'll define the `load()` function to orchestrate the load work by returning the appropriate view states as the data loads. The `load()` function immediately returns a new "loading" state to the view and calls the `fetch()` function which will perform the data request.


```swift
struct LoaderModel: LoaderModeling {
    ...
    func load() -> AnyPublisher<LoadUserProfileViewState, Never> {
        Just(.loading)
            .merge(with: fetch())
            .eraseToAnyPublisher()
    }
}
```

The `fetch()` function instantiates a `UserDataRepository` dependency which loads the user data (from a web service, cache, or database) and returns it by way of `AnyPublisher<UserData, Error>`. (We will cover proper dependency injection in <doc:DataDefinition>.)

Upon completion of the request, the code maps the user data type to the "loaded" view state.

```swift
struct LoaderModel: LoaderModeling {
    ...
    private func fetch() -> AnyPublisher<LoadUserProfileViewState, Never> {
        UserDataRepository().loadUserData(userId: userId)
            .map { userData in
                LoadUserProfileViewState.loaded(userData)
            }
            .catch { error in
                handleLoadingError(error)
            }
            .eraseToAnyPublisher()
    }
}
```

Since the publisher returned by the `UserDataRepository` can emit errors, we are required by the compiler to convert the error into a view state within the `catch()` closure.

To improve readability, we'll forward the error handling code to a `handleLoadingError()` function. This error handler will be responsible for categorizing the type of error to the most appropriate view state. It can also perform any logging necessary.

```swift
struct LoaderModel: LoaderModeling {
    ...
    private func handleLoadingError(_ error: Error) -> Just<LoadUserProfileViewState> {
        NSLog("Error loading user data: \(error)")
        let errorModel = ErrorModel(userId: userId, error: error)
        return Just(LoadUserProfileViewState.loadingError(errorModel))
    }
}
```

In this function, we log the error and then create an error model for the `loadingError` view state. Then, we return a publisher that emits the loading error view state. That will cause the view to update and show the error view state which renders an error message and a retry button.

Our final Load Profile model looks like this:

```swift
struct LoaderModel: LoaderModeling {
    let userId: Int

    init(userId: Int) {
        self.userId = userId
    }

    func load() -> AnyPublisher<LoadUserProfileViewState, Never> {
        Just(.loading)
            .merge(with: fetch())
            .eraseToAnyPublisher()
    }

    private func fetch() -> AnyPublisher<LoadUserProfileViewState, Never> {
        UserDataRepository().loadUserData(userId: userId)
            .map { userData in
                LoadUserProfileViewState.loaded(userData)
            }
            .catch { error in
                handleLoadingError(error)
            }
            .eraseToAnyPublisher()
    }

    private func handleLoadingError(_ error: Error) -> Just<LoadUserProfileViewState> {
        NSLog("Error loading user data: \(error)")
        let errorModel = LoadingErrorModel(userId: userId, error: error)
        return Just(LoadUserProfileViewState.loadingError(errorModel))
    }
}
```

Now you may be asking, "where do we define the error message and retry behavior for the error state?". We will implement the error state's behavior in a separate model, like so:

```swift
struct LoadingErrorModel: LoadingErrorModeling {
    let userId: Int
    var message: String

    init(userId: Int, error: Error) {
        self.userId = userId
        message = "\(error.localizedDescription)"
    }

    func retry() -> AnyPublisher<LoadUserProfileViewState, Never> {
        LoaderModel(userId: userId).load()
    }
}
```

This is where a tiny bit of recursion comes in. We want the retry action to call the `load()` function on our loader model again. Because we're in a separate model, we built a copy of the loader model and called its load function directly.

Since these are structs, the create/copy/destroy operations are generally very inexpensive, as long as the models and associated value types stay relatively small.

The Load User Profile models are now complete and ready for testing. To learn more about testing, visit <doc:UnitTesting>.

You may have noticed that we don't subscribe or receive on the main queue anywhere in this code. (ie, `.receive(on: DispatchQueue.main)` or `.subscribe(on: DispatchQueue.main`). This is because the state container's ``StateContainer/observe(_:)-1uta3`` function does this for us.

> Tip: In VSM, you never have to worry about syncing your view states with the main thread.

You may also have noticed that we don't use `[weak self]` in any of our closures. This is mainly because we don't reference `self` anywhere. Even if we did, there are virtually no scenarios where you need to weakly reference `self` because we are exclusively using structs instead of classes. Structs are copied in memory from scope to scope which prevents strong reference cycles.

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
        case savingError(ErrorModel)
    }
}

protocol EditingModeling {
    func saveUsername(_ username: String) -> AnyPublisher<EditUserProfileViewState, Never>
}

protocol SavingErrorModeling {
    let message: String
    func retry() -> AnyPublisher<EditUserProfileViewState, Never>
    func cancel() -> AnyPublisher<EditUserProfileViewState, Never>
}
```

After we have a good idea of how the states and data should flow, we can begin implementing the editing model of the `EditUserProfileViewState` by creating the corresponding model struct.

```swift
struct EditingModel: EditingModeling {
    let userData: UserData

    init(userData: UserData) {
        self.userData = userData
    }

    func saveUsername(_ username: String) -> AnyPublisher<EditUserProfileViewState, Never> {
        return Just(
            EditUserProfileViewState(
                data: userData,
                editingState: .saving
            )
        )
        .merge(with: performSave(username: username))
        .eraseToAnyPublisher()
    }
}
```

Our repository needs a `UserData` object because the save function also handles the `retry()` and `cancel()` actions in the event of an error. So, the initializer will ask for the user data so that we can forward it to the `performSave()` function.

Similar to the load action from the Load Profile model, we'll immediately return a new "saving" state to the view while the save operation is processing. Notice how we have to recreate the view state struct to do so.

Next, we'll implement the `performSave()` function like so:

```swift
struct EditingModel: EditingModeling {
    ...
    private func performSave(username: String) -> AnyPublisher<EditUserProfileViewState, Never> {
        UserDataRepository().saveUsername(username)
            .map { savedUserData in
                EditUserProfileViewState(
                    data: savedUserData,
                    editingState: .editing(EditingModel(userData: savedUserData))
                )
            }
            .catch { error in
                handleSavingError(error, username: username)
            }
            .eraseToAnyPublisher()
    }
}
```

Similar to the Load Profile model's load function, this function instantiates a repository, saves the username, and then converts the published `UserData` result to the appropriate "success" view state. We also handle the error in a similar way as the Load Profile model.

```swift
struct EditingModel: EditingModeling {
    ...
    private func handleSavingError(_ error: Error, username: String) -> Just<EditUserProfileViewState> {
        NSLog("Error saving username: \(error)")
        let errorModel = SavingErrorModel(
            error: error,
            username: username,
            userData: userData
        )
        return Just(
            EditUserProfileViewState(
                data: userData,
                editingState: .savingError(errorModel)
            )
        )
    }
}
```

The final editing view model becomes this:

```swift
struct EditingModel: EditingModeling {
    let userData: UserData

    init(userData: UserData) {
        self.userData = userData
    }

    func saveUsername(_ username: String) -> AnyPublisher<EditUserProfileViewState, Never> {
        return Just(
            EditUserProfileViewState(
                data: userData,
                editingState: .saving
            )
        )
        .merge(with: performSave(username: username))
        .eraseToAnyPublisher()
    }

    private func performSave(username: String) -> AnyPublisher<EditUserProfileViewState, Never> {
        UserDataRepository().saveUsername(username)
            .map { savedUserData in
                EditUserProfileViewState(
                    data: savedUserData,
                    editingState: .editing(EditingModel(userData: savedUserData))
                )
            }
            .catch { error in
                handleSavingError(error, username: username)
            }
            .eraseToAnyPublisher()
    }

    private func handleSavingError(_ error: Error, username: String) -> Just<EditUserProfileViewState> {
        NSLog("Error saving username: \(error)")
        let errorModel = SavingErrorModel(
            error: error,
            username: username,
            userData: userData
        )
        return Just(
            EditUserProfileViewState(
                data: userData,
                editingState: .savingError(errorModel)
            )
        )
    }
}
```

Now, we must build the error model to implement the error message data, retry action, and cancel action, according to the requirements. This model requires some extra data to properly implement the corresponding actions. Using the same techniques discussed above, our error model looks like this:

```swift
struct SavingErrorModel: SavingErrorModeling {
    let message: String
    let username: String
    let userData: String

    init(error: Error, username: String, userData: UserData) {
        message = "Error saving username: \(error.localizedDescription)"
        self.username = username
        self.userData = userData
    }
    
    func retry() -> AnyPublisher<EditUserProfileViewState, Never> {
        EditingModel(userData: userData).saveUsername(username)
    }
            
    func cancel() -> AnyPublisher<EditUserProfileViewState, Never> {
        let editingModel = EditingModel(userData: userData)
        return Just(
            EditUserProfileViewState(
                data: userData,
                editingState: .editing(editingModel)
            )
        ).eraseToAnyPublisher()
    }
}
```

You'll notice several examples of recursive programming where some actions need to go back to previous states and those states have actions that can lead back to the state in question. In each case, we build a new view state and pass in the dependencies and data required for the view state's model.

This "always forward" progression from state to state can be called the "state journey".

## Avoid MVVM Pitfalls

MVVM is currently the most prevalent architecture. Most of Apple's training material and SwiftUI guides use some form of MVVM. If you are already familiar with building features in MVVM, you may be tempted to do any of the following when implementing VSM models:

- Make your model a class type
- Use a single model to manage all of your states and actions
- Declare the model as `ObservableObject` and use `@Published` properties to internally manage the current state, or your internal states and data
- Manage subscriptions by storing `AnyCancellable`s when calling `sink` on publishers that your feature depends on
- Loading the data and then calling a separate action from the view to subscribe to future published data updates

None of these practices are appropriate for use in a VSM feature. If any of these techniques sneak into your feature, it becomes difficult to follow the pattern and see the benefits of building features that observe and interact with a stream of view states.

It is generally less effective to use class types for models in VSM. Classes introduce the risk of memory leaks due to accidental strong-self captures within closures. Because states in VSM are largely ephemeral and have short lifespans, classes increase the cost of state transitions. They also don't come with the benefit of implicit internal initializers like structs do.

"Massive View Model" types tend to violate several [SOLID](https://en.wikipedia.org/wiki/SOLID) architecture principles and introduce the potential for bugs from shared mutable data and unprotected functions. This applies as well to models that manage state by using `@Published` properties. They tend to be a hotbed for bugs caused by unintended states, side effects, and regressions.

Manually managing publisher subscriptions within a model is less effective in VSM because it's much easier (and requires much less code) to let the state container manage the subscriptions for you. You can do this within your actions by weaving multiple data publishers into a single view state publisher. Combine functions such as merge, zip, combineLatest, map, flatMap, etc. are powerful tools that allow you to weave streams of data into the shape of your choice. This also eliminates the need to make any round-trips to the view to trigger actions that observe future updates.

## Up Next

### Working with Data Repositories

Now that we have covered how to build models in VSM, we can learn the power of shared, observable data repositories to hydrate our features and eliminate view and data synchronization bugs in <doc:DataDefinition>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
