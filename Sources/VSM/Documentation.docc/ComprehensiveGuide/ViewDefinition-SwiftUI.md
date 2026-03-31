# Building the View in VSM - SwiftUI

A guide to building a VSM view in SwiftUI

## Overview

VSM is a reactive architecture and as such is a natural fit for SwiftUI, but it also works very well with UIKit with some minor differences. This guide is written for SwiftUI. The UIKit guide can be found here: <doc:ViewDefinition-UIKit>

The purpose of the "View" in VSM is to render the current view state and provide the user access to the data and actions available in that state.

## View Structure

The basic structure of a SwiftUI VSM view is as follows:

```swift
import VSM

struct LoadUserProfileView: View {
    @ViewState var state: LoadUserProfileViewState

    var body: some View {
        // View definitions go here
    }
}
```

To turn any view into a "VSM View", define a property that holds our current state and decorate it with the ``ViewState`` (`@ViewState`) property wrapper.

**The `@ViewState` property wrapper updates the view every time the state changes**. It works in the same way as other SwiftUI property wrappers (i.e., `@StateObject`, `@State`, `@ObservedObject`, and `@Binding`).

As with other SwiftUI property wrappers, when the wrapped value (state) changes, the view's `body` property is reevaluated and the result is drawn on the screen.

In the following examples, we will use the `LoadUserProfileViewState` and `EditUserProfileViewState` types from <doc:StateDefinition> to build two related VSM views.

## Displaying the State

As a refresher, the following flow chart expresses the requirements that we wish to draw in the view.

![VSM User Flow Diagram Example](vsm-user-flow-example.jpg)

### Loading View

The resulting view state for the loading behavior of the flow chart (the left section of the state machine) is:

```swift
enum LoadUserProfileViewState {
    case initialized(LoaderModel)
    case loading
    case loadingError(LoadingErrorModel)
    case loaded(UserData)
}

struct LoaderModel {
    func load() -> StateSequence<LoadUserProfileViewState>
}

struct LoadingErrorModel {
    let message: String
    func retry() -> StateSequence<LoadUserProfileViewState>
}
```

In SwiftUI, we write a switch statement within the `body` property to evaluate the current state and draw the most appropriate content for it.

Note that if you avoid using a `default` case in your switch statement, the compiler will enforce any future changes to the shape of your feature. This is good because it will help you avoid bugs when maintaining the feature.

The resulting `body` property implementation takes this shape:

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

To render this editing form, we need a property that keeps track of what the user types for the "Username" field. A `@State` property called "username" will do nicely.

```swift
struct EditUserProfileView: View {
    @ViewState var state: EditUserProfileViewState
    @State var username: String = ""
    
    init(userData: UserData) {
        let editingModel = EditUserProfileViewState.EditingModel(userData: userData)
        let state = EditUserProfileViewState(data: userData, editingState: .editing(editingModel))
        _state = .init(wrappedValue: state)
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

Since the root type of this view state is a `struct` instead of an `enum`, and this view has a more complicated hierarchy, you'll notice that we don't use a switch statement. Instead, we place components where they need to go and sprinkle in logic within areas of the view, as necessary.

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
>     func save(username: String) -> StateSequence<EditUserProfileViewState>? {
>         if case .editing(let editingModel) = editingState {
>             return editingModel.save(username: username)
>         }
>         return nil
>     }
> }
> ```

## Calling the Actions

Now that we have our view states rendering correctly, we need to wire up the various actions in our views so that they are appropriately and safely invoked by the environment or the user.

VSM's ``ViewState`` property wrapper provides a critically important function called `observe(_:)` through its projected value (`$`). This function updates the current state with all view states emitted by an action, as they are emitted in real-time.

It is called like so:

```swift
$state.observe(someState.someAction())
```

The only way to update the current view state is to use the `ViewState`'s `observe(_:)` function.

When `observe(_:)` is called, it cancels any existing Swift Concurrency tasks and active Combine subscriptions, then ignores view state updates from any previously called actions. This prevents future view state corruption from previous actions and frees up device resources.

Actions that do not need to update the current state do not need to be called with the `observe(_:)` function. However, if you attempt to call an action that should update the current state without using `observe(_:)`, the compiler will give you the following warning:

**_Result of call to function returning `StateSequence<LoadUserProfileViewState>` is unused_**

This is a helpful reminder in case you forget to wrap an action call with `observe(_:)`.

> Note: The `observe(_:)` function has many overloads that provide support for several action shapes, including synchronous state values, async closures, `StateSequence`, and `AsyncStream`. For more information, see <doc:ModelActions>.

### Implementing Actions with StateSequence

When implementing actions in your models, use `StateSequence` to emit multiple states over time. For initial view loading actions, prefer `@StateSequenceBuilder` so the loading state is applied synchronously in the first frame, followed by async work that produces the final state:

```swift
struct LoaderModel {
    private let repository: UserRepository

    @StateSequenceBuilder
    func load() -> StateSequence<LoadUserProfileViewState> {
        LoadUserProfileViewState.loading
        Next { await self.fetchUserData() }
    }

    @concurrent
    private func fetchUserData() async -> LoadUserProfileViewState {
        do {
            let userData = try await repository.getUserProfile()
            return .loaded(userData)
        } catch {
            return .loadingError(LoadingErrorModel(
                message: "Failed to load profile: \(error.localizedDescription)",
                retry: { await self.fetchUserData() }
            ))
        }
    }
}
```

Notice how errors are handled within the async function using `do-catch` blocks, converting any `Error` into an appropriate error state. This ensures all state transitions are type-safe and explicit.

### Loading View Actions

There are two actions that we want to call in the `LoadUserProfileView`: the `load()` action in the `initialized` view state and the `retry()` action for the `loadingError` view state. We want `load()` to be called only once in the view's lifetime, so we'll attach it to the `onAppear` event handler on one of the subviews and implement `load()` with `@StateSequenceBuilder`. The `retry()` action will be nestled in the view that uses the unwrapped `errorModel`.

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
                $state.observe(errorModel.retry())
            }
        }
    }
    .onAppear {
        if case .initialized(let loaderModel) = state {
            $state.observe(loaderModel.load())
        }
    }
}
```

> Note: SwiftUI calls your view's initializer many times during your view's lifetime. **_Do not call actions that impact data, network, memory, or significant CPU resources within the initializer of a SwiftUI view_**. Failing to comply may cause excessive operation calls, tie up precious resources, or result in data-corruption issues.
>
> To coordinate data load actions with your view's loading event, use SwiftUI's `onAppear` event handler.

### Editing View Actions

In the editing view, there are three actions that we need to call: The `editing` view state's `save(username:)` action and the `savingError` view state's `retry()` and `cancel()` actions. We'll place these appropriately scoped where we have access to their corresponding view states.

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
                    $state.observe(editingModel.save(username: username))
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
                        $state.observe(errorModel.retry())
                    }
                    Button("Cancel") {
                        $state.observe(errorModel.cancel())
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

You will most often see these types of data expressed as properties on a SwiftUI view with the `@State` or `@Binding` property wrappers. There are a handful of approaches in which VSM can synchronize between these view properties and the current view state. The two most common approaches are by using custom `Binding<T>` objects, or by manipulating view properties and calling VSM actions via the view event handlers.

### Comparing State Changes

SwiftUI's `.onChange(of:)` modifier enables view properties to be updated when the view state changes. By making your view state conform to `Equatable`, you can use this modifier to react to state transitions and update view-specific properties accordingly.

The following example displays a progress view that shows the loading state of some imaginary data operation. It begins loading when the view first appears and then animates the progress bar as the bytes are loaded. The view utilizes an `@State` property for animating the progress view and keeps the value up to date by observing state changes.

```swift
struct MyView: View {
    @ViewState var state: MyViewState
    @State var progress: Double = 0

    var body: some View {
        ProgressView("Loading...", value: progress)
            .onAppear {
                if case .initialized(let loaderModel) = state {
                    $state.observe(loaderModel.load())
                }
            }
            .onChange(of: state) { oldState, newState in
                switch newState {
                case .loading(let loadingModel):
                    withAnimation() {
                        progress = loadingModel.loadedBytes / loadingModel.totalBytes
                    }
                default:
                    break
                }
            }
    }
}
```

> Note: Because this example uses `.onChange(of:)` rather than Combine's `onReceive(_:)`, the closure will only be called while the view is part of the active view hierarchy. If a state change occurs after the user has navigated away from this view, the `.onChange(of:)` closure will not fire for that update. This is generally desirable behavior — view-specific side effects like animations should only run while the view is on screen — but it is worth keeping in mind if your closure performs work that must happen regardless of the view's visibility.
> Tip: Make your view state conform to `Equatable` to enable the `.onChange(of:)` modifier. For simple view states, you can add `Equatable` conformance automatically. For complex states with closures or non-equatable types, you may need to implement custom equality or use alternative approaches like comparing specific properties.

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

However, if the view's `username` property did need to be kept in sync with the data source, or some other window's editor, etc., then using the `.onChange(of:)` modifier would solve that, but have the potential to overwrite the user's unsaved changes.

```swift
@State var username: String = ""

var body: some View {
    ZStack {
        ...
    }
    .onChange(of: state.data.username) { oldValue, newValue in
        username = newValue
    }
}
```

The `.onChange(of:)` modifier observes changes to specific properties of your view state and executes the provided closure when those properties change.

#### Auto-Saving with Debounced Input

If we want to ditch the `Save` button in favor of auto-saving as the user types, we need to be careful not to call `save(username:)` on every keystroke. Spamming `$state.observe()` with a new async action on every character change would cause excessive state updates and redundant network work.

The recommended approach uses three complementary techniques:

1. **Focused local state**: Store the text field value in a `@State` property rather than driving it directly from the view state. This lets the text field update freely without touching VSM on every keystroke.
2. **`@FocusState`**: Start the editing session only when the user actually focuses the field, keeping the view state simple.
3. **Debounced `onChange`**: Debounce at the view layer (the Shopping demo app ships an example `View` extension backed by Swift Async Algorithms' `debounce`) so work fires only after the user pauses typing, not on every character.

```swift
struct ProfileView: View {
    @ViewState var state: ProfileViewState

    @State private var username: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        switch state {
        case .loaded, .editing:
            loadedView()
                .onAppear {
                    // Populate local state from the loaded model on first appearance
                    guard case .loaded(let loadedModel) = state else { return }
                    username = loadedModel.fetchedUsername
                }
                .onChange(of: isTextFieldFocused) { _, focused in
                    // Transition to the editing state only when the user focuses the field
                    if focused {
                        guard case .loaded(let loadedModel) = state else { return }
                        $state.observe(loadedModel.startEditing())
                    }
                }
        // ...
        }
    }

    func loadedView() -> some View {
        TextField("User Name", text: $username)
            .focused($isTextFieldFocused)
            // Fire save only after the user pauses typing for 0.5 seconds
            .onChange(of: username, debounce: .seconds(0.5)) { _, newValue in
                if case .editing(let editingModel) = state {
                    $state.observe(editingModel.save(username: newValue))
                }
            }
    }
}
```

The model's `save(username:)` action can also do its part to prevent redundant work by short-circuiting early when the value hasn't actually changed:

```swift
struct ProfileEditingModel: MutatingCopyable {
    var username: String
    var editingState: ProfileEditingState

    func save(username: String) -> StateSequence<ProfileViewState> {
        // No-op if the user typed something but ended up back at the original value
        guard username != self.username else {
            return StateSequence({ .editing(self) })
        }
        guard !username.isEmpty else {
            return StateSequence({
                .editing(self.copy(mutating: { $0.editingState = .error(Errors.emptyUsername) }))
            })
        }
        return StateSequence(
            { .editing(self.copy(mutating: { $0.editingState = .saving })) },
            { /* perform network save... */ }
        )
    }
}
```

This combination means `$state.observe()` is only ever called when the user has paused typing _and_ the value has actually changed — the view modifier handles the debounce, and the model handles the equality check.

## View Construction

What's the best way to construct a VSM component? Through the SwiftUI view's initializer. As passively enforced by the SwiftUI API, every feature's true API access point is the initializer of the feature's view. Required dependencies and data are passed to the initializer to initiate the feature's behavior.

A VSM view's initializer can take either of two approaches (or both, if desired):

- Dependent: The parent is responsible for passing in the view's initial view state (and its associated model)
- Encapsulated: The view encapsulates its view state kickoff point (and associated model), only requiring that the parent provide dependencies needed by the view or the models.

The "Dependent" initializer has two upsides and one downside when compared to the encapsulated approach. The upsides are that Swift provides a default initializer automatically and the initializer is convenient for use in SwiftUI Previews and automated UI tests. The downside is that it requires parent views to have some knowledge of the inner workings of the view in question.

### Loading View Initializers

The initializers for the `LoadUserProfileView` are as follows:

"Dependent" Approach

```swift
// Parent View Code
let loaderModel = LoadUserProfileViewState.LoaderModel(userId: userId)
let state = LoadUserProfileViewState.initialized(loaderModel)
LoadUserProfileView(state: state)
```

"Encapsulated" Approach

```swift
// LoadUserProfileView Code
init(userId: Int) {
    let loaderModel = LoadUserProfileViewState.LoaderModel(userId: userId)
    let state = LoadUserProfileViewState.initialized(loaderModel)
    _state = .init(wrappedValue: state, observedViewType: Self.self)
}

// Parent View Code
LoadUserProfileView(userId: someUserId)
```

> Note: The `observedViewType` parameter helps with debugging by providing better log categorization. You can also enable logging during development by setting `loggingEnabled: true` in the initializer.
>
> Alternatively, if you assign a value directly to your `@ViewState` wrapped property, you can set `loggingEnabled` directly on the property wrapper:
>
> ```swift
> @ViewState(loggingEnabled: true)
> var state: MyExampleViewState = .initialized(MyExampleModel())
> ```

### Editing View Initializers

The initializers for the `EditUserProfileView` are as follows:

"Dependent" Approach

```swift
// Parent View Code
let editingModel = EditUserProfileViewState.EditingModel(userData: userData)
let state = EditUserProfileViewState(data: userData, editingState: .editing(editingModel))
EditUserProfileView(state: state)
```

"Encapsulated" Approach

```swift
// EditUserProfileView Code
init(userData: UserData) {
    let editingModel = EditUserProfileViewState.EditingModel(userData: userData)
    let state = EditUserProfileViewState(data: userData, editingState: .editing(editingModel))
    _state = .init(wrappedValue: state, observedViewType: Self.self)
}

// Parent View Code
EditUserProfileView(userData: someUserData)
```

## Iterative View Development

The best approach to building features in VSM is to start with defining the view state, then move straight to building the view. Rely on SwiftUI previews where possible to visualize each state. Postpone implementing the feature's business logic for as long as possible until you are confident that you have the right feature shape and view code.

The reason for recommending this approach to VSM development is that VSM implementations are tightly coupled with and enforced by the feature shape (via the type system and compiler). By defining the view state and view code, it gives you time to explore the edge cases of the feature without having to significantly refactor the models and business logic.

## Up Next

### Building the Models

Now that we have discovered how to build views, and we have built each view and previewed all the states using SwiftUI previews, we can start implementing the business logic in the models in <doc:ModelDefinition>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
