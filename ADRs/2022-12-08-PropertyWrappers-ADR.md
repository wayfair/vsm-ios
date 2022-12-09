## Problem Statement

Using VSM with UIKit can be cumbersome. Specifically, when rendering state changes. In addition, this ADR explores the possibility of using property wrappers for a more holistic approach to working with the `StateContainer` type.

Currently, UIKit views require developers to manually subscribe to state updates to update the view hierarchy when the state changes.

Example:

```swift
import Combine

class SomeViewController: UIViewController, ViewStateRendering {
    var container: StateContainer<SomeViewState>
    var stateSubscription: AnyCancellable?
    ...
    func viewDidLoad() {
        stateSubscription = container
            .$state
            .sink { [weak self] newState in
                self?.render(state: newState)
            }
    }

    func render(state newState: SomeViewState) {
        switch newState {
            ...
        }
    }
}
```

These are the problems with the current approach:

1. Wiring up the subscription, including toting a subscription property, introduces repetitive boilerplate code to each VSM view.
1. It's easy to incorrectly configure the state subscription.
1. Accidentally capturing `self` within the `sink` closure will cause memory leaks (strong reference cycles)
1. Using `state` or `container.state` within the `sink` closure of the `$state` publisher will give you the previous value, not the current value. (Due to the inherent behavior of the `@Published` state property in the `StateContainer`)

## Proposed Solution

### AutoRendered Property Wrapper

The most appropriate solution is to create a property wrapper that encapsulates the state observation logic.

This property wrapper, called `@AutoRendered` can access the enclosing UIView (or UIViewController) and invoke a new `render()` function on `ViewStateRendering`. The `render()` function is not needed or used in SwiftUI views.

Example Usage

```swift
class SomeViewController: UIViewController, ViewStateRendering {
    @AutoRendered var container: StateContainer<SomeViewState>
    ...
    func render() {
        switch state {
            ...
        }
    }
}
```

The solution utilizes the same technique that powers SwiftUI's `@Published` property behavior, where the property wrapper parent can be accessed in a static subscript to add observation behavior to the wrapped value.

Benefits

- Removes 9 lines of boilerplate code (Solves problem #1)
- Removes potential for incorrect state subscription (Solves problem #2)
- Removes potential for memory leaks in state observation (Solves problem #3)
- Invokes `render()` after the state value changes, ensuring `state` and `container.state` are both safe to access in the rendering code. (Solves problem #4)
- Allows custom state subscription to be possible if required (by opting out of the `@AutoRendered` property)

Drawbacks

- Forgetting to apply `@AutoRendered` to the `container` property will result in runtime behavior issues (Property wrapper usage cannot be enforced by the compiler, as is the standard for all property wrappers like `@State`, `@ObservedObject`, etc.)

## Alternatives Considered

Two other solutions were considered which provide similar benefits while making the VSM framework more ergonomic.

### ViewState Property Wrapper

This solution focuses on addressing the problems in question while improving the ergonomics of the SwiftUI VSM view code. It does so by introducing a `@ViewState` property wrapper which encapsulates the `StateContainer` entirely from the engineer. It also provides the same convenient auto-observing behavior as `@AutoRender`, allowing it to be used for both SwiftUI and UIKit.

All `StateContainer` properties and functions would then be accessed directly from the `@ViewState` wrapper by way of the `_` underscore prefix.

Example Usage

```swift
struct SomeView: View {
    @ViewState var state: SomeViewState
    ...
    var body: some View {
        Button("\(state.isEnabled)") {
            _state.observe(state.toggle(isEnabled: !state.isEnabled))
        }
        .onChange(of: state.isEnabled) { isEnabled in 
            print(isEnabled)
        }
        .onReceive(_state.publisher) { newState in 
            print(newState)
        }
    }
}

// Enables simple default initializer:
SomeView(state: .init(SomeViewState()))
```

As you can see from the example, the `ViewStateRendering` protocol is no longer necessary.

Benefits

- Solves all the problems that `@AutoRendered` solves
- Works for both UIKit and SwiftUI
- More ergonomic for declaring the view state property on a view
- More ergonomic for instantiating a view
- No longer requires a protocol
- The developer no longer has to choose between `@ObservedObject` and `@StateObject` for the `container` property in SwiftUI

Drawbacks

- The `_` prefix is generally unpopular for such a use case, causing much nose-wrinkling
- Extra typing (`_state...`) is required on some lines because `observe` and `bind` are no longer accessible directly on the view
- The developer is further removed from the "metal" of the framework (the `StateContainer`)

### ViewState Property Wrapper with ViewStateRendering Extension

This solution extends the above "ViewStateProperty Wrapper" solution by restoring the `ViewStateRendering` protocol to access the underlying `StateContainer` members, such as `observe` and `bind` without having to go through the `_state` property.

It does this by using reflection in a protocol extension to map `observe`, `bind`, et al. to the `StateContainer` found within the `@ViewState` property wrapper.

Example Usage

```swift
struct SomeView: View {
    @ViewState var state: SomeViewState
    ...
    var body: some View {
        Button("\(state.isEnabled)") {
            observe(state.toggle(isEnabled: !state.isEnabled))
        }
        .onChange(of: state.isEnabled) { isEnabled in 
            print(isEnabled)
        }
        .onReceive(statePublisher) { newState in 
            print(newState)
        }
    }
}
```

Under the hood, the `ViewStateRendering` protocol is extended like so:

```swift
public extension ViewStateRendering {
    var container: StateContainer<State> {
        let mirror = Mirror(reflecting: self)
        let viewStatePropertyWrapper = mirror
            .children
            .filter({ $0.label == "_state" })
            .first?.value as? ViewState<State>
        return viewStatePropertyWrapper?.container ?? StateContainer(state: state)
    }
}
```

This approach changes the `ViewStateRendering` protocol requirement from `container` to `state`. If desired, this could be done in a new protocol (ie, `StateRendering`) to prevent breaking changes in existing VSM implementations that use `ViewStateRendering`.

Benefits

- Accomplishes all that `@ViewState` and `@AutoRendered` have to offer
- Removes the need (but not the capability) of the `_` prefix to access the `StateContainer` members
- Provides direct access to the underlying `StateContainer` via the `container` property on `ViewStateRendering`
- Is the most ergonomic solution for VSM

Drawbacks

- Is a breaking change (with a potential workaround)
- A tiny, but non-zero performance hit *per function call* of `observe`, `bind`, etc. to map the action to the underlying property wrapper's `StateContainer`
- Runtime errors instead of compile-time errors if the user attempts to invoke `observe`, `bind`, et al. without adding the `@ViewState` property wrapper
- If Apple ever changes the `_` prefix requirement, apps will fail at runtime instead of compile time

## Additional Context

This proposal improves the VSM framework while upholding the original goals of VSM. Specifically, extreme type-safety and determinism while eliminating all possible implementation mistakes. These proposed solutions *do not* introduce new risks or potential failure points to the developer workflow. Any risks in these solutions are similar or equal to the existing risks present within the VSM framework.
