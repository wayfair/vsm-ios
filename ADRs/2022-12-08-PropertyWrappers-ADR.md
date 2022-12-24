## Problem Statement

Using VSM with UIKit can be cumbersome. Specifically, when rendering state changes. In addition, this ADR explores the possibility of using property wrappers for a more holistic approach to working with the `StateContainer` type.

Currently, UIKit views require developers to manually subscribe to state updates to update the view hierarchy when the state changes.

Example:

```swift
import Combine

class SomeViewController: UIViewController, ViewStateRendering {
    var container: StateContainer<SomeViewState>
    var stateSubscription: AnyCancellable?
    
    init() {
        container = .init(state: SomeViewState())
    }

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
2. It's easy to incorrectly configure the state subscription.
3. Accidentally capturing `self` within the `sink` closure will cause memory leaks (strong reference cycles)
4. Using `state` or `container.state` within the `sink` closure of the `$state` publisher will give you the previous value, not the current value. (Due to the inherent behavior of the `@Published` state property in the `StateContainer`)

## Proposed Solution

The solution is broken into two parts:
1. [RenderedViewState Property Wrapper](#RenderedViewState-Property-Wrapper)
2. [ViewState Property Wrapper](#ViewState-Property-Wrapper)

### RenderedViewState Property Wrapper

The most appropriate solution is to create a UIKit-specific property wrapper that encapsulates the state observation logic.

This property wrapper, called `@RenderedViewState` can access the enclosing UIView (or UIViewController) and invoke a specified `render()` function. The `render()` function is not needed or used in SwiftUI views.

Example Usage

```swift
class SomeViewController: UIViewController {
    @RenderedViewState(render: SomeViewController.render)
    var state: SomeViewState = SomeViewState()
    ...
    func render() {
        switch state {
            ...
            $state.observe(state.someAction())
        }
    }
}
```

Alternative Usage

```swift
class SomeViewController: UIViewController {
    @RenderedViewState var state: SomeViewState
    
    init() {
        _state = .init(wrappedValue: SomeViewState(), render: Self.render)
        super.init(bundle: nil, nib: nil)
    }

    func render() {
        switch state {
            ...
            $state.observe(state.someAction())
        }
    }
}
```

The solution utilizes the same technique that powers SwiftUI's `@Published` property behavior, where the property wrapper parent can be accessed in a static subscript to add observation behavior to the wrapped value.

Bonus: This solution also takes the opportunity to improve the ergonomics of a VSM view by leveraging the power of property wrappers. It does this by encapsulating the `StateContainer` and exposing a subset of the `StateContainer` members via the projected value (`$`) of the property wrapper. These members are:

- `publisher` is a `Publisher<State, Never>` which publishes the view state on the main thread from the `didSet` event of the `StateContainer`'s state property.
- `observe` is forwarded directly to the `StateContainer`, which updates the current view state to the results of some action.
- `bind` is forwarded directly to the `StateContainer`, which creates two-way bindings to the current view state.

Benefits

- Removes 8 lines of boilerplate code (Solves problem #1)
- Removes potential for incorrect state subscription (Solves problem #2)
- Removes potential for memory leaks in state observation (Solves problem #3)
- Invokes `render()` after the state value changes, ensuring that the `state` property is safe to access in the rendering code (Solves problem #4)

Knock-on Benefits
- Allows custom state subscription to be possible if required (by opting out of the `@RenderedViewState` property and using the `StateContainer`'s new `statePublisher` property)
- `publisher` allows for more stable custom state observation
- Improves the ergonomics of building a VSM view
    - `ViewStateRendering` is deprecated because `@RenderedViewState` supersedes it in every way. This removes developer confusion around `ViewStateRendering` and its somewhat ambiguous purpose
    - A simpler view state declaration allows developers to focus on the state type instead of clouding the concept with the `StateContainer` requirements
    - Developers can name their view state property as they see fit

Drawbacks

- Forgetting to apply `@RenderedViewState` to the `state` property will result in unexpected runtime behavior.
    - This concern is mitigated by the fact that SwiftUI's property wrappers have the same tradeoff (`@State`, `@ObservedObject`, etc.)
    - This can be mitigated by Swift Lint rules, or possibly targeted ("purple") runtime warnings as the [Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Internal/RuntimeWarnings.swift) does.

### ViewState Property Wrapper

The `@RenderedViewState` property wrapper brings so many benefits with trivial tradeoffs that it spawned the idea that the SwiftUI VSM view ergonomics would stand to benefit greatly from the same treatment.

Therefore, a new `@ViewState` property wrapper is proposed in tandem which provides the same conveniences of `@RenderedViewState` but is purpose-built for SwiftUI and its nuances.

Example Usage

```swift
struct SomeView: View {
    @ViewState var state: SomeViewState
    ...
    var body: some View {
        Button("\(state.isEnabled)") {
            $state.observe(state.toggle(isEnabled: !state.isEnabled))
        }
        .onChange(of: state.isEnabled) { isEnabled in 
            print(isEnabled)
        }
        .onReceive($state.publisher) { newState in 
            print(newState)
        }
    }
}
```

This property wrapper works exactly like `@RenderedViewState`, but without the need to specify a render function. It relies on SwiftUI's `DynamicProperty`, and `@StateObject` under the hood to propagate changes in view state to the view, which are automatically rendered each time the state changes, as you'd expect.

Benefits

- All of the benefits of `@RenderedViewState` mentioned above
- Developers will no longer have to worry about navigating the nuances of `@StateObject` vs `@ObservedObject` as it is handled automatically within `@ViewState`
- When considered with `@RenderedViewState`, the `ViewStateRendering` protocol is no longer useful or necessary and can be fully deprecated

Drawbacks

- `@ViewState` be confused with `@RenderedViewState`. The compiler prevents `@RenderedViewState` from being used in a SwiftUI view, the reverse is possible. This causes unexpected runtime behavior and runtime warnings.
    - To a lesser extent, this concern is mitigated by the fact that SwiftUI's property wrappers have the same tradeoff (`@State`, `@ObservedObject`, etc.)
    - This can be mitigated by Swift Lint rules

## Alternatives Considered

Several other solutions were considered which provide similar benefits while making the VSM framework more ergonomic. The two alternatives mentioned below were the most noteworthy.

### UIKit-only @AutoRendered Property Wrapper

The first idea was to introduce a UIKit-specific property wrapper used in conjunction with the `ViewStateRendering` protocol. It was originally dubbed `@AutoRendered` and its sole purpose was to automate the `render()` function.

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

This required adding a `render()` function to the `ViewStateRendering` protocol that was optional for SwiftUI views, but required for UIKit views.

Benefits

- Very simple solution
- Addresses the main issues with VSM in UIKit

Drawbacks

- This causes a breaking change for developers with the new `render()` protocol requirement
- It doesn't do as much for overall ergonomics as the `ViewState` property wrapper solutions

### A Single ViewState Property Wrapper

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
