# Building the View in VSM - SwiftUI

A guide to building a VSM view in SwiftUI

## Overview

VSM is a reactive architecture and as such is a natural fit for SwiftUI, but it also works very well with UIKit with some minor differences. This guide is written for SwiftUI. The UIKit guide can be found here: <doc:ViewDefinition-UIKit>

The purpose of the "View" in VSM is to render the current view state and provide the user access to the data and actions available in that state.

## View Structure

The basic structure of a SwiftUI VSM view is as follows:

```swift
import VSM

struct LoadUserProfileView: View, ViewStateRendering {
    @StateObject var container: StateContainer<LoadUserProfileViewState>

    var body: some View {
        // View definitions go here
    }
}
```

We are required by the ``ViewStateRendering`` protocol to define a ``StateContainer`` property and specify what the view state's type will be. In these examples, we will use the `LoadUserProfileViewState` and `EditUserProfileViewState` types from <doc:StateDefinition> to build two related VSM views.

In SwiftUI, the `view` property is evaluated and the view is redrawn _every time the state changes_. In addition, any time a dynamic property changes, the `view` property will be reevaluated and redrawn. This includes properties wrapped with `@StateObject`, `@State`, `@ObservedObject`, and `@Binding`.

> Note: In SwiftUI, a view's initializer is called every time its parent view is updated and redrawn.
>
> The `@StateObject` property wrapper is the safest choice for declaring your `StateContainer` property. A `StateObject`'s current value is maintained by SwiftUI between redraws of the parent view. In contrast, `@ObservedObject`'s value is not maintained between redraws of the parent view, so it should only be used in scenarios where the view state can be safely recovered every time the parent view is redrawn.

## Displaying the State

The ``ViewStateRendering`` protocol provides a few properties and functions that help with displaying the current state, accessing the state data, and invoking actions.

The first of these members is the ``ViewStateRendering/state`` property, which is always set to the current state.

As a refresher, the following flow chart expresses the requirements that we wish to draw in the view.

![VSM User Flow Diagram Example](vsm-user-flow-example.jpg)

### Loading View

The resulting view state for the loading behavior of the flow chart (the left section of the state machine) is:

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

In SwiftUI, we simply write a switch statement within the `view` property to evaluate the current state and return the most appropriate view(s) for it.

Note that if you avoid using a `default` case in your switch statement, the compiler will enforce any future changes to the shape of your feature. This is good because it will help you avoid bugs when maintaining the feature.

The resulting `view` property implementation takes this shape:

```swift
var body: some View {
    HStack {
        switch state {
        case .initialized, .loading:
            ProgressView()
        case .loaded(let userData):
            EditUserProfileView(userData: userData)
        case .loadingError(let errorModel):
            Text(errorModel.message)
            Button("Retry") {
                ...
            }
        }
    }
}
```

Here you can see that the `initialized` and `loading` states are combined to produce a `ProgressView`, the `loadingError` state returns a `Text` view describing the error and a retry button that we will implement with an action later in this guide. Finally, the `loaded` state forwards the `UserData` on to the `EditUserProfileView`.

### Editing View

If we go back up to the feature's flow chart and translate the editing behavior (the right section of the state machine) to a view state, we come up with the following view state:

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

To render this editing form, we require an extra property be added to the SwiftUI view to keep track of what the user types for the "Username" field.

```swift
struct EditUserProfileView: View, ViewStateRendering {
    @StateObject var container: StateContainer<EditUserProfileViewState>
    @State var username: String = ""
    
    init(userData: UserData) {
        let editingModel = EditUserProfileViewState.EditingModel(userData: userData)
        let state = EditUserProfileViewState(data: userData, editingState: .editing(editingModel))
        _container = .init(state: state)
    }

    var body: some View {
        ZStack {
            VStack {
                Text("User profile")
                    .font(.headline)
                TextField("Username", text: $username)
                    .textFieldStyle(.roundedBorder)
                Button("Save") {
                    ...
                }
            }
            .disabled(state.isSaving)
            .padding()
            if state.isSaving {
                ProgressView()
            }
            if case .savingError(let errorModel) = state.editingState {
                VStack {
                    Text(errorModel.message)
                    HStack {
                        Button("Retry") {
                            ...
                        }
                        Button("Cancel") {
                            ...
                        }
                    }
                }
                .background(.white)
                .padding()
            }
        }
    }
}
```

Since the root type of this view state is a struct instead of an enum, and this view has a more complicated hierarchy, you'll notice that we don't use a switch statement. Instead, we place components where they need to go and sprinkle in logic within areas of the view, as necessary.

Additionally, you'll notice that there is a reference to a previously unknown view state member in the property wrapper `.disabled(state.isSaving)`. Due to the programming style used in SwiftUI APIs, we sometimes have to extend our view state to transform its shape to work better with SwiftUI views. We define these in view state extensions so that we can preserve the type safety of our feature shape, while reducing the friction when working with specific view APIs.

See <doc:ViewStateExtensions> for further explanation and examples of view state extensions.

In any case, the above view code is made much simpler by the following view state extension, which converts the editing state enum into a simple `isSaving` boolean:

```swift
extension EditUserProfileViewState {
    var isSaving: Bool {
        switch self.editingState {
        case .saving, .savingError:
            return true
        case .editing:
            return false
        }
    }
}
```

> Tip: Avoid creating view state extensions that circumvent or obfuscate the type-safety and intentionality of the feature shape. For example, a view state extension that returns an optional action, like so, will undermine the intentionality of the feature shape and create an opportunity for bugs:
>
> ```swift
> extension EditUserProfileViewState {
>     func saveUsername(_ username: String) -> AnyPublisher<EditUserProfileViewState, Never> {
>         if case .editing(let editingModel) = editingState {
>             return editingModel.saveUsername(username)
>         }
>         return Empty().eraseToAnyPublisher()
>     }
> }
> ```

## Calling the Actions

Now that we have our view states rendering correctly, we need to wire up the various actions in our views so that they are appropriately and safely invoked by the environment or the user.

VSM's ``ViewStateRendering`` protocol provides a critically important function called ``ViewStateRendering/observe(_:)-7vht3``. This function updates the current state with all view states emitted by the action parameter, as they are emitted in real-time.

It is called like so:

```swift
observe(someState.someAction())
// or
observe(someState.someAction)
```

The only way to update the current view state is to use the `observe(_:)` function.

When `observe(_:)` is called, it cancels any existing Combine publisher subscriptions or Swift Concurrency tasks and ignores view state updates from any previously called actions. This prevents future view state corruption from previous actions and frees up device resources.

Actions that do not need to update the current state do not need to be called with the `observe(_:)` function. However, if you attempt to call an action that should update the current state without using `observe(_:)`, the compiler will give you the following warning:

**_Result of call to function returning 'AnyPublisher<LoadUserProfileViewState, Never>' is unused_**

This is a helpful reminder in case you forget to wrap an action call with `observe(_:)`.

> Note: The `observe(_:)` function has many overloads that provide support for several action shapes, including synchronous actions, Swift Concurrency actions, and Combine Publisher actions. For more information, see <doc:ModelActions>.

### Loading View Actions

There are two actions that we want to configure in the `LoadUserProfileView`. The `load()` action in the `initialized` view state and the `retry()` action for the `loadingError` view state. We want `load()` to be called only once in the view's lifetime, so we'll attach it to the `onAppear` event handler on one of the subviews. The `retry()` action will be nestled in the view that uses the unwrapped `errorModel`.

```swift
var body: some View {
    HStack {
        switch state {
        case .initialized, .loading:
            ProgressView()
        case .loaded(let userData):
            EditUserProfileView(userData: userData)
        case .loadingError(let errorModel):
            Text(errorModel.message)
            Button("Retry") {
                observe(errorModel.retry())
            }
        }
    }
    .onAppear {
        if case .initialized(let loaderModel) = state {
            observe(loaderModel.load())
        }
    }
}
```

> Note: SwiftUI calls your view's initializer many times during your view's lifetime. **_Do not call actions that impact data, network, memory, or significant CPU resources within the initializer of a SwiftUI view_**. Failing to comply may cause excessive operation calls, tie up precious resources, or result in data-corruption issues.
>
> To coordinate data load actions with your view's loading event, use SwiftUI's `onAppear` event handler.

### Editing View Actions

In the editing view, there are three actions that we need to call: The `editing` view state's `saveUsername()` action and the `savingError` view state's `retry()` and `cancel()` actions. We'll place these appropriately scoped where we have access to their corresponding view states.

```swift
var body: some View {
    ZStack {
        VStack {
            Text("User profile")
                .font(.headline)
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
            Button("Save") {
                if case .editing(let editingModel) = state.editingState {
                    observe(editingModel.saveUsername(username))
                }
            }
        }
        .disabled(state.isSaving)
        .padding()
        if state.isSaving {
            ProgressView()
        }
        if case .savingError(let errorModel) = state.editingState {
            VStack {
                Text(errorModel.message)
                HStack {
                    Button("Retry") {
                        observe(errorModel.retry())
                    }
                    Button("Cancel") {
                        observe(errorModel.cancel())
                    }
                }
            }
            .background(.white)
            .padding()
        }
    }
}
```

You can see that based on the type-system constraints, _these actions can never be called from the wrong state_, and the feature code indicates this very clearly.

## Synchronize View Logic

All business logic belongs in VSM models and associated repositories. However, there are cases where some logic, pertaining exclusively to view matters, is appropriately placed within the view, managed by the view, and coordinated with the view state. The few areas where this practice is acceptable are:

- Navigating between views (See <doc:Navigation>)
- Receiving/streaming user input
- Animating the view

You will most often see these types of data expressed as properties on a SwiftUI view with the `@State` or `@Binding` property wrappers. There are a handful of approaches in which VSM can synchronize between these view properties and the current view state. The two most common approaches are by using custom `Binding<T>` objects, or by imperatively manipulating view properties and calling VSM actions via the view event handlers.

### Logic Coordination for the Editing View

In the above `EditUserProfileView` code, you may have noticed that we are not coordinating the view's `username` with the `EditUserProfileViewState.data.username` property. There are a few simple ways to coordinate a view's properties with the view state.

#### SwiftUI View Events

The fastest way to solve the problem is to set the view's `username` property to the view state's `data.username` property when the view loads.

```swift
@State var username: String = ""

var body: some View {
    ZStack {
        ...
    }
    .onAppear {
        username = state.data.username
    }
}
```

This approach assumes that the repository does not need to always update the view's `data.username` property. Only if the `onAppear` event is called.

However, if the view's `username` property did need to be kept in sync with the data source, or some other window's editor, etc., then adding an `onReceive` event handler would solve that, but have the potential to overwrite the user's unsaved changes.

```swift
@State var username: String = ""

var body: some View {
    ZStack {
        ...
    }
    .onReceive(container.$state) { newState in 
        username = newState.data.username
    }
}
```

We have to use the `ViewStateRendering`'s ``ViewStateRendering/container`` property because it gives us access to the underlying `StateContainer`'s observable `@Published` ``StateContainer/state`` property which can be observed by `onReceive`.

#### Custom Two-Way Bindings

If we wanted to ditch the `Save` button in favor of having the view input call `saveUsername()` as the user is typing, SwiftUI's `Binding<T>` type behaves much like a property on an object by providing a two-way getter and a setter for a wrapped value. We can utilize this to trick the `TextField` view into thinking it has read/write access to the view state's `username` property.

A custom `Binding<T>` can be created as a view state extension property, as a `@Binding` property on the view, or on the fly right within the view's code, like so:

```swift
var body: some View {
    let usernameBinding = Binding(
        get: { state.data.username },
        set: { newValue in
            if case .editing(let editingModel) = state.editingState {
                observe(editingModel.saveUsername(newValue),
                    debounced: .seconds(1))
            }
        }
    )
    TextField("Username", text: usernameBinding)
        .textFieldStyle(.roundedBorder)
}
```

Notice how our call to ``ViewStateRendering/observe(_:debounced:file:line:)-7ihyy`` includes a `debounced` property. This allows us to prevent thrashing the `saveUsername()` call if the user is typing quickly. It will only call the action a maximum of once per second (or whatever time delay is given).

## View Construction

What's the best way to construct a VSM component? Through the SwiftUI view's initializer. As passively enforced by the SwiftUI API, every feature's true API access point is the initializer of the feature's view. Required dependencies and data are passed to the initializer to initiate the feature's behavior.

A VSM view's initializer can take either of two approaches (or both, if desired):

- Dependent: The parent is responsible for passing in the view's initial view state (and its associated model)
- Encapsulated: The view encapsulates its view state kickoff point (and associated model), only requiring that the parent provide dependencies needed by the view or the models.

The dependent initializer has one upside and one downside when compared to the encapsulated approach. The upside is that the initializer is convenient for use in SwiftUI Previews and automated UI tests. The downside is that it requires any parent view to have some knowledge of the inner workings of the view in question.

### Loading View Initializers

The initializers for the `LoadUserProfileView` are as follows:

```swift
// Dependent
init(state: LoadUserProfileViewState) {
    _container = .init(state: state)
}

// Encapsulated
init(userId: Int) {
    let loaderModel = LoadUserProfileViewState.LoaderModel(userId: userId)
    let state = .initialized(loaderModel)
    _container = .init(state: state)
}
```

### Editing View Initializers

The initializers for the `EditUserProfileView` are as follows:

```swift
// Dependent
init(state: EditUserProfileViewState) {
    _container = .init(state: state)
}

// Encapsulated
init(userData: UserData) {
    let editingModel = EditUserProfileViewState.EditingModel(userData: userData)
    let state = EditUserProfileViewState(data: userData, editingState: .editing(editingModel))
    _container = .init(state: state)
}
```

## Iterative View Development

The best approach to building features in VSM is to start with defining the view state, then move straight to building the view. Rely on SwiftUI previews where possible to visualize each state. Postpone implementing the feature's business logic for as long as possible until you are confident that you have the right feature shape and view code.

The reason for recommending this approach to VSM development is that VSM implementations are tightly coupled with and enforced by the feature shape (via the type system and compiler). By defining the view state and view code, it gives you time to explore the edge cases of the feature without having to significantly refactor the models and business logic.

## Up Next

### Building the Models

Now that we have discovered how to build views, and we have built each view and previewed all the states using SwiftUI previews, we can start implementing the business logic in the models in <doc:ModelDefinition>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
