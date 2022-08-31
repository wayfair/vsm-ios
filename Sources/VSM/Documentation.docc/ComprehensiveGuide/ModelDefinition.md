# Implementing the Business Logic in VSM

A guide for implementing business logic with Models in VSM

## Overview

One of the unique things about the VSM architecture is its philosophy on how models work. In VSM, models encapsulate the functionality of the feature, similar to models in other architectures. However, VSM models are divided into multiple "mini-view-models" by view state. This allows the compiler to protect certain data and functionality from being accessed in unintended ways or at unintended times. It also helps the engineer create simpler, [least-knowledge](https://en.wikipedia.org/wiki/Law_of_Demeter), and sometimes [single-purposed](https://en.wikipedia.org/wiki/Single-responsibility_principle) models which are easy to test and maintain.

> Tip: Building VSM models requires an understanding of [finite state machines](https://en.wikipedia.org/wiki/Finite-state_machine) and simple [recursion](https://www.vadimbulavin.com/recursion-in-swift/).

There are 4 slightly different, yet equally viable patterns for building models in VSM. You can read more about each pattern in <doc:ModelPatterns>. In this article, we will be focusing on the "Builder" pattern where each model implements its functionality via type extensions.

We will continue from <doc:StateDefinition> by implementing the business logic for the models associated with `LoadUserProfileViewState` and the `EditUserProfileViewState`.

As a refresher, the state flow chart is as follows, with the `LoadUserProfileViewState` corresponding to the finite state machine on the left and the `EditUserProfileViewState` on the right:

![VSM State Flow Diagram Example](vsm-state-flow-example.jpg)

## Load Profile View Models

First, we'll take a look at the shape of the `LoadUserProfileViewState` and its corresponding behavior in the above state flow chart.

```swift
enum LoadUserProfileViewState {
    case initialized(LoaderModel)
    case loading
    case loadingError(ErrorModel)
    case loaded(UserData)

    struct LoaderModel {
        let load: () -> AnyPublisher<LoadUserProfileViewState, Never>
    }

    struct ErrorModel {
        let message: String
        let retry: () -> AnyPublisher<LoadUserProfileViewState, Never>
    }
}
```

After we have a good idea of how the states and data should flow, we can begin implementing the model by extending the corresponding model struct definition. Our entire implementation for this model will live in this struct extension.

```swift
extension LoadUserProfileViewState.LoaderModel {
    // ...
}
```

Next, we'll create an initializer that defines the behavior of the `load()` action property on the struct.

```swift
extension LoadUserProfileViewState.LoaderModel {
    init(userId: Int) {
        load = {
            // TODO: Implement
        }
    }
}
```

To implement the load action in an easily readable way, we'll define a function within the extension that performs the load work and returns the appropriate view states as it loads.

Because we are initializing the load property on the struct, we cannot reference any member of `self` within the implementation body of the load function. To get around this, we use static functions. We'll mark them as private because no outside callers should have direct access to these functions. Not even for unit tests.

```swift
extension LoadUserProfileViewState.LoaderModel {
    init(userId: Int) {
        load = {
            Just(.loading)
                .merge(with: Self.load(userId: userId))
                .eraseToAnyPublisher()
        }
    }
    
    private static func load(userId: Int) -> AnyPublisher<LoadUserProfileViewState, Never> {
        UserDataRepository().loadUserData()
            .map { userData in
                LoadUserProfileViewState.loaded(userData)
            }
            .catch { error in
                // TODO: Handle error
            }
            .eraseToAnyPublisher()
    }
}
```

The above code instantiates a dependency that can load the user data and return it as a publisher type of `AnyPublisher<UserData, Error>`. It immediately returns a new "saving" state to the view. Then, it invokes the data request, which contacts a web API or local database, returns the result, or completes with an error. (We will cover proper dependency injection in <doc:ObservableRepositories>.)

The code then maps the user data result type from the data source publisher to the desired view state: `LoadUserProfileViewState.loaded(UserData)`. Since the function cannot return a publisher that can emit errors, we are required by the compiler to convert the error into a view state within the `catch()` function.

To improve readability, we'll forward the error handling code to a separate function which we will reference within the `catch()` function. This error handler will be responsible for categorizing the type of error to the most appropriate view state. It can also perform any logging necessary.

```swift
private static func load(userId: Int) -> AnyPublisher<LoadUserProfileViewState, Never> {
    UserDataRepository().loadUserData()
        .map { userData in
            LoadUserProfileViewState.loaded(userData)
        }
        .catch { error in
            handleLoadingError(error, for: userId)
        }
        .eraseToAnyPublisher()
}

private static func handleLoadingError(_ error: Error, for userId: Int) -> Just<LoadUserProfileViewState> {
    NSLog("Error loading user data: \(error)")
    let errorModel = LoadUserProfileViewState.ErrorModel(
        userId: userId,
        message: "\(error.localizedDescription)"
    )
    return Just(LoadUserProfileViewState.loadingError(errorModel))
}
```

In this function, we log the error and then create an error model for the `loadingError` view state that we want to return to the view. Then we return a new publisher that emits a single loading error view state. That will cause the view to update and show the error view state which renders an error message and a retry button.

Our final Load Profile model looks like this:

```swift
extension LoadUserProfileViewState.LoaderModel {
    init(userId: Int) {
        load = {
            Just(.loading)
                .merge(with: Self.load(userId: userId))
                .eraseToAnyPublisher()
        }
    }
    
    private static func load(userId: Int) -> AnyPublisher<LoadUserProfileViewState, Never> {
        UserDataRepository().loadUserData()
            .map { userData in
                LoadUserProfileViewState.loaded(userData)
            }
            .catch { error in
                handleLoadingError(error, for: userId)
            }
            .eraseToAnyPublisher()
    }
    
    private static func handleLoadingError(_ error: Error, for userId: Int) -> Just<LoadUserProfileViewState> {
        NSLog("Error loading user data: \(error)")
        let errorModel = LoadUserProfileViewState.ErrorModel(
            userId: userId,
            message: "\(error.localizedDescription)"
        )
        return Just(LoadUserProfileViewState.loadingError(errorModel))
    }
}
```

Now you may be asking, "but where do we define the `retry()` action for the error model?". For this, we will implement the error model's behavior in a separate extension of the error model struct, like so:

```swift
extension LoadUserProfileViewState.ErrorModel {
    init(userId: Int, message: String) {
        self.message = message
        retry = {
            LoadUserProfileViewState.LoaderModel(userId: userId).load()
        }
    }
}
```

This is where a tiny bit of recursion comes in. We want the retry action to call the `load()` function on our loader model again. Because we're in a separate model, we built a copy of the loader model and called its load function directly.

Since these are structs, the create/copy/destroy operations are generally very inexpensive, as long as the models and associated value types stay relatively small.

The Load User Profile models are now complete and ready for testing. To learn more about testing, visit <doc:UnitTesting>.

You may have noticed that we don't subscribe or receive on the main queue anywhere in this code. (ie, `.receive(on: DispatchQueue.main)` or `.subscribe(on: DispatchQueue.main`). This is because the state container's ``StateContainer/observe(_:)-1uta3`` function does this for us.

> Tip: In VSM, you never have to worry about syncing your view states with the main thread.

You may also have noticed that we don't use `[weak self]` in any of our closures. This is mainly because we don't reference `self` anywhere. But even if we did (ie, via the <doc:ModelPatterns#EncapsulatedProtocol> pattern), there are virtually no scenarios where you need to weakly reference `self` because we are exclusively using structs instead of classes. Structs are copied in memory from scope to scope which prevents strong reference cycles.

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
    
    struct EditingModel {
        let saveUsername: (String) -> AnyPublisher<EditUserProfileViewState, Never>
    }
    
    struct ErrorModel {
        let message: String
        let retry: () -> AnyPublisher<EditUserProfileViewState, Never>
        let cancel: () -> AnyPublisher<EditUserProfileViewState, Never>
    }
}
```

After we have a good idea of how the states and data should flow, we can begin implementing the editing model of the `EditUserProfileViewState` by extending the corresponding model struct definition. As we did above, we'll also add an initializer to the extension.

```swift
extension EditUserProfileViewState.EditingModel {
    init(userData: UserData) {
        saveUsername = { username in
            return Just(
                EditUserProfileViewState(
                    data: userData,
                    editingState: .saving
                )
            )
            .merge(with: Self.save(username: username, for: userData))
            .eraseToAnyPublisher()
        }
    }
}
```

Our repository needs a `UserData` object because the save function also handles the `retry()` and `cancel()` actions in the event of an error. So, the initializer will ask for the user data so that we can forward it to the save function within the `saveUsername()` closure.

Similar to the load action from the Load Profile model, we'll immediately return a new `.saving` state to the view while the save operation is processing. Notice how we have to recreate the view state struct to do so.

Next, we'll implement the save function like so:

```swift
private static func save(
    username: String,
    for userData: UserData
) -> AnyPublisher<EditUserProfileViewState, Never> {
    UserDataRepository().saveUsername(username)
        .map { savedUserData in
            EditUserProfileViewState(
                data: savedUserData,
                editingState: .editing(EditUserProfileViewState.EditingModel(userData: savedUserData))
            )
        }
        .catch { error in
            handleSavingError(error, username: username, for: userData)
        }
        .eraseToAnyPublisher()
}
```

Similar to the Load Profile model's load function, this function instantiates a repository, saves the username, and then converts the published `UserData` result to the appropriate "success" view state. We also handle the error in a similar way as the Load Profile model.

```swift
private static func handleSavingError(
    _ error: Error,
    username: String,
    for userData: UserData
) -> Just<EditUserProfileViewState> {
    NSLog("Error saving username: \(error)")
    let errorModel = EditUserProfileViewState.ErrorModel(
        message: "Error saving username: \(error.localizedDescription)",
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
```

The final editing view model becomes this:

```swift
extension EditUserProfileViewState.EditingModel {
    init(userData: UserData) {
        saveUsername = { username in
            return Just(
                EditUserProfileViewState(
                    data: userData,
                    editingState: .saving
                )
            )
            .merge(with: Self.save(username: username, for: userData))
            .eraseToAnyPublisher()
        }
    }
    
    private static func save(
        username: String,
        for userData: UserData
    ) -> AnyPublisher<EditUserProfileViewState, Never> {
        UserDataRepository().saveUsername(username)
            .map { savedUserData in
                EditUserProfileViewState(
                    data: savedUserData,
                    editingState: .editing(EditUserProfileViewState.EditingModel(userData: savedUserData))
                )
            }
            .catch { error in
                handleSavingError(error, username: username, for: userData)
            }
            .eraseToAnyPublisher()
    }
    
    private static func handleSavingError(
        _ error: Error,
        username: String,
        for userData: UserData
    ) -> Just<EditUserProfileViewState> {
        NSLog("Error saving username: \(error)")
        let errorModel = EditUserProfileViewState.ErrorModel(
            message: "Error saving username: \(error.localizedDescription)",
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

Now, we must extend the error model to implement the error message data, retry action, and cancel action, according to the requirements. This model requires some extra data to properly implement the corresponding actions. Using the same techniques discussed above, our error model looks like this:

```swift
extension EditUserProfileViewState.ErrorModel {
    init(message: String, username: String, userData: UserData) {
        self.message = message
        retry = {
            Self.retry(username: username, for: userData)
        }
        cancel = {
            Self.cancel(userData: userData)
        }
    }
    
    private static func retry(
        username: String,
        for userData: UserData
    ) -> AnyPublisher<EditUserProfileViewState, Never> {
        EditUserProfileViewState.EditingModel(userData: userData)
            .saveUsername(username)
    }
            
    private static func cancel(userData: UserData) -> AnyPublisher<EditUserProfileViewState, Never> {
        let editingModel = EditUserProfileViewState.EditingModel(userData: userData)
        return Just(
            EditUserProfileViewState(
                data: userData,
                editingState: .editing(editingModel)
            )
        ).eraseToAnyPublisher()
    }
}
```

You'll notice several examples of recursive programming in that some actions need to return to previous states which have actions that can lead back to the action in question. In each case, we build a new view state and pass in the dependencies and data required for the model associated with the destination view state.

This "always forward" progression from state to state can be called the "state journey".

## Avoid MVVM Pitfalls

MVVM is currently the most prevalent architecture. Most of Apple's training material and SwiftUI guides use some form of MVVM. If you are already familiar with building features in MVVM, you may be tempted to do any of the following when implementing VSM models:

- Make your model a class type
- Use a single model to manage all of your states and actions
- Declare the model as `ObservableObject` and use `@Published` properties to internally manage the current state, or your internal states and data
- Manage subscriptions by storing `AnyCancellable`s when calling `sink` on publishers that your feature depends on
- Loading the data and then calling a separate action from the view to subscribe to future published data updates

None of these practices are appropriate for use in a VSM feature. If any of these techniques sneak into your feature, it becomes difficult to follow the pattern and see the benefits of building a feature that observes and interacts with a stream of view states.

To address the above points, it is generally less effective to use class types for models in VSM. Classes would merely introduce the risk of memory leaks due to accidental strong-self captures within closures. Because states in VSM are largely ephemeral and have short lifespans, classes increase the cost of state transitions. They also don't come with the benefit of implicit initializers like structs do.

Single "mega-view-model" types violate several SOLID architecture principles and introduce the potential for bugs via shared mutable data and unprotected functions. This applies as well to models that manage state via `@Published` properties. They tend to be hotbeds for bugs caused by unintended states, side effects, and regressions.

Managing subscriptions of various publishers is less effective in VSM because it's much easier (and requires much less code) to let the state container manage the subscriptions for you. You can do this within your actions by combining and translating various data publishers into one view state publisher via Combine functions such as merge, zip, combineLatest, map, flatMap, etc. You then return this single view state publisher from the appropriate action. This also eliminates the need to make any round-trips to the view to trigger actions that observe future updates.

## Up Next

### Working with Data Repositories

Now that we have covered how to build models in VSM, we can learn the power of shared, observable data repositories to hydrate our features and eliminate view and data synchronization bugs in <doc:DataDefinition>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
