# Building the View in VSM - SwiftUI

A guide to building a VSM view in SwiftUI or UIKit

## Overview

VSM is a reactive architecture and as such is a natural fit for SwiftUI, but it also works very well with UIKit with some minor differences. This guide is written for SwiftUI. The UIKit guide can be found here: <doc:ViewDefinition-UIKit>

The purpose of the "View" in VSM is to render the current view state, and provide the user access to the data and actions available in that state.

## View Construction

The basic structure of a SwiftUI VSM view is as follows:

```swift
import VSM

struct LoadUserProfileView: View, ViewStateRendering {
    @StateObject var container: StateContainer<LoadUserProfileViewState>

    var view: some View {
        // View definitions go here
    }
}
```

We are required by the ``ViewStateRendering`` protocol to define a ``StateContainer`` property and specify what the view state's type will be. In these examples, we will use the `LoadUserProfileViewState` and `EditUserProfileViewState` types from <doc:FeatureRequirements> to build two related VSM views.

In SwiftUI, the `view` property is evaluated and the view is redrawn _every time the state changes_. In addition, any time a dynamic property changes, the `view` property will be reevaluated and redrawn. This includes properties wrapped with `@StateObject`, `@State`, `@ObservedObject`, and `@Binding`.

> Note: In SwiftUI, a view's initializer is called every time its parent view is updated and redrawn.
> 
> The `@StateObject` property wrapper is the safest choice for declaring your `StateContainer` property. A `StateObject`'s current value is maintained by SwiftUI between redraws of the parent view. In contrast, `@ObservedObject`'s value is not maintained between redraws of the parent view, so it should only be used in scenarios where the view state can be safely recovered every time the parent view is redrawn.
>
> todo: Move this to wiring up actions section: Regardless of which property wrapper you use, SwiftUI calls your view's initializer many times during your view's lifetime. Therefore, _no data or resource impacting actions should be called within the initializer_ of a SwiftUI view to avoid excessive, duplicate data operations.

## Displaying the State

The ``ViewStateRendering`` protocol provides a few properties and functions that help with displaying the current state, accessing the state data, and invoking actions.

The first of these members is the ``ViewStateRendering/state`` property, which is always set to the current state.

> todo: Move this to <doc:ModelDefinition> : Note: ``ViewStateRendering/state`` is guaranteed by the state container to be updated on the main thread. No thread dispatching is required in either framework.

As a refresher, the following flow chart expresses the requirements that we wish to draw in the view.

![VSM User Flow Diagram Example](vsm-user-flow-example.jpg)

### Loading View

The resulting view state for the loading behavior of the flow chart (the left section of the state machine) is:

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

In SwiftUI, we simply write a switch statement within the `view` property to evaluate the current state and return the most appropriate view(s) for it. Note that if you avoid using a `default` case in your switch statement, the compiler will enforce any future changes to the shape of your feature. This is good because it will help you avoid bugs when maintaining the feature.

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
                // TODO: implement this action
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

To render this editing form, we require an extra property be added to the SwiftUI view to keep track of what the user types for the "Username" field.

```swift
@State var username: String = ""

var body: some View {
    ZStack {
        VStack {
            Text("User profile")
                .font(.headline)
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
            Button("Save") {
                // TODO: implement this action
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
                        // TODO: implement this action
                    }
                    Button("Cancel") {
                        // TODO: implement this action
                    }
                }
            }
            .background(.white)
            .padding()
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

Now that we have our state rendering correctly, we need to wire up the various actions in our views so that they are appropriately and safely invoked by the environment or the user.

### Loading View Actions

### Editing View Actions
