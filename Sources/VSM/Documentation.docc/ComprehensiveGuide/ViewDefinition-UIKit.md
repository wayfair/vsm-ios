# Building the View in VSM - UIKit

A guide to building a VSM view in SwiftUI or UIKit

## Overview

VSM is a reactive architecture and as such is a natural fit for SwiftUI, but it also works very well with UIKit with some minor differences.  This guide is written for UIKit. The SwiftUI guide can be found here: <doc:ViewDefinition>

The purpose of the "View" in VSM is to render the current view state, and provide the user access to the data and actions available in that state.

## View Construction

The basic structure of a VSM view is as follows:

```swift
// SwiftUI
import VSM

struct LoadUserProfileView: View, ViewStateRendering {
    @StateObject var container: StateContainer<LoadUserProfileViewState>

    var view: some View {
        // View definitions go here
    }
}
```

We are required by the ``ViewStateRendering`` protocol to define a ``StateContainer`` property and specify what the associated view state's type will be. In these examples, we will use the `LoadUserProfileViewState` and `EditUserProfileViewState` types from <doc:FeatureRequirements> to build two related VSM views.

In SwiftUI, the `view` property is evaluated and the view is redrawn _every time the state changes_. In addition, any time a dynamic property changes, the `view` property will be reevaluated and redrawn. This includes properties wrapped with `@StateObject`, `@State`, `@ObservedObject`, and `@Binding`.

> Note: In SwiftUI, a view's initializer is called every time its parent view is updated and redrawn.
> 
> `@StateObject` is the safest choice for declaring your ``StateContainer``, as its current value is maintained by SwiftUI between redraws of the parent view. `@ObservedObject`s' value is not maintained between redraws of the parent view, so it should only be used in scenarios where the view state can be safely recovered every time the parent view is redrawn.


In UIKit, we have to manually connect the state changes to a `render` function. This render function will be called any time the state changes and can be used to create, destroy, or configure views or components within the view controller.

```swift
// UIKit
import VSM

class UserProfileViewController: UIViewController, ViewStateRendering {
    var container = StateContainer<UserProfileViewState>
    var stateSubscriber: AnyCancellable?

    init(state: UserProfileViewState) {
        container = .init(state: state)
        super.init(nibName: nil, bundle: nil)
        stateSubscriber = container.$state.sink { [weak self] newState in
            self?.render(state: newState)
        }
    }

    func render(state: VSMBasicExampleViewState) {
        // View configuration goes here
    }
}
```

> Tip: Unlike SwiftUI, the view controller's initializer will not be repeatedly called, so data loads can safely begin within the initializer.

## Displaying the State

The ``ViewStateRendering`` protocol is a convenient way for engineers to conform any view to the VSM pattern. It provides a few properties and functions that help with displaying the current state, accessing the state data, and invoking actions.

The first of these members is the ``ViewStateRendering/state`` property, which is always set to the current state in SwiftUI. In UIKit, the ``ViewStateRendering/state`` property is updated on the published state's `willChange` event, so evaluations of the current state should always be performed within the `render` function where the state parameter is guaranteed to be current.

> Note: ``ViewStateRendering/state`` is guaranteed by the state container to be updated on the main thread. No thread dispatching is required in either framework.

As a refresher, the following flow chart expresses the requirements that we wish to draw in the view.

![VSM User Flow Diagram Example](vsm-user-flow-example.jpg)

In SwiftUI, we simply write a switch statement to evaluate the current state and return the most appropriate view for it. (Note: If you avoid using a `default` case in your switch statement, the compiler will enforce any future changes to the shape of your feature.)

```swift
// SwiftUI
@State var username: String

var body: some View {
    switch state {
    case .initialized, .loading:
        ProgressView()
    case .loadingError(let errorModel):
        Text(errorModel.message)
        Button("Retry") {
            ...
        }
    case .loaded(let userData):
        TextField("User Name", $username)
            .onReceive(container.$state) {
                if case .loaded(let userData) = $0 {
                    username = userData.username
                }
            }
        Button("Save") {
            ...
        }
    case .saving(let userData):
        Text(userData.username)
    case .savingError(let errorModel):
        Text(errorModel.userData.username)
        Text(errorModel.message)
        Button("Retry") {
            ...
        }
    }
}
```
