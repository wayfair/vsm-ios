## Problem Statement

Using VSM with UIKit can be cumbersome. Specifically, when rendering state changes. In addition, this ADR explores the possibility of using property wrappers for a more holistic approach to working with the `StateContainer` type.

Currently, UIKit views require developers to manually subscribe to state updates to update the view when the state changes.

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

1. [RenderedViewState Property Wrapper](#Part%201%20-%20RenderedViewState%20Property%20Wrapper)
2. [ViewState Property Wrapper](#Part%202%20-%20ViewState%20Property%20Wrapper)

### Part 1 - RenderedViewState Property Wrapper

The most appropriate solution is to create a UIKit-specific property wrapper called `@RenderedViewState` that encapsulates the state observation logic (`StateContainer`) which manages the current view state. It exposes a subset of `StateContainer` members through the projected value (`$`) of the property wrapper.

`@RenderedViewState` can access its enclosing UIView (or UIViewController) and invoke a specified `render()` function which serves to notify the view of changes in the view state. This `render()` function is not needed or used in SwiftUI views.

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

As you can see from the examples, the solution takes the opportunity to improve the ergonomics of a VSM view by leveraging the power of property wrappers. It does this through the properties and functions found in the projected value (`$`) of the property wrapper. These members are:

- `publisher` is an `AnyPublisher<State, Never>` which publishes the view state on the main thread from the `didSet` event of the `StateContainer`'s state property.
- `observe` is forwarded directly to the `StateContainer`, which updates the current view state to the results of some action.
- `bind` is forwarded directly to the `StateContainer`, which creates two-way bindings to the current view state.

Benefits

- Removes 9 lines of boilerplate code (Solves problem #1)
- Removes potential for incorrect state subscription (Solves problem #2)
- Removes potential for memory leaks in state observation (Solves problem #3)
- Invokes `render()` after the state value changes, ensuring that the `state` property is safe to access in the rendering code (Solves problem #4)

Knock-on Benefits

- Allows custom state subscription to be possible if required (by opting out of the `@RenderedViewState` property and using the `StateContainer`'s new `statePublisher` property)
- The new `$state.publisher` property allows for more stable custom state observation (on `didSet` vs `willSet`)
- Improves the ergonomics of building a VSM view
  - `ViewStateRendering` is superseded by `@RenderedViewState` in every way. This removes developer confusion around `ViewStateRendering` and its somewhat ambiguous purpose
  - A simpler view state declaration allows developers to directly focus on the view state type and concerns instead of clouding the concept with the `StateContainer` declaration
  - Developers can name their view state property as they see fit. It is no longer constrained to `container.state` by the `ViewStateRendering` protocol. `state` is the recommended view state property name and will be used throughout the documentation.

Drawbacks

- Forgetting to apply `@RenderedViewState` to the `state` property will result in unexpected runtime behavior
  - This concern is mitigated by the fact that SwiftUI's property wrappers have the same tradeoff (`@State`, `@ObservedObject`, etc.)
  - This can be mitigated by Swift Lint rules, or possibly targeted ("purple") runtime warnings as the [Composable Architecture](https://github.com/pointfreeco/swift-composable-architecture/blob/main/Sources/ComposableArchitecture/Internal/RuntimeWarnings.swift) does
- Extra typing is required on some lines because `observe` and `bind` are no longer accessible directly on the view through the `ViewStateRendering` protocol (`$state.observe(...)` vs `observe(...)`)
- The developer is further removed from the "metal" of the framework (the `StateContainer`)

### Part 2 - ViewState Property Wrapper

The `@RenderedViewState` property wrapper brings so many benefits with trivial tradeoffs that it inspired the idea to bring this approach to SwiftUI.

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

// Enables simple default initializer:
SomeView(state: SomeViewState())
```

This property wrapper works exactly like `@RenderedViewState`, but without the need to specify a render function. It relies on SwiftUI's `DynamicProperty`, and `@StateObject` under the hood to propagate changes in view state to the view, which are automatically rendered each time the state changes, as you'd expect.

Benefits

- All of the benefits of `@RenderedViewState` mentioned above
- Developers will no longer have to worry about navigating the nuances of `@StateObject` vs `@ObservedObject` because it is handled automatically within `@ViewState`
- The `ViewStateRendering` protocol is no longer useful or necessary and can be fully deprecated

Drawbacks

- The same drawbacks as the `@RenderedViewState` property
- `@ViewState` may be confused with `@RenderedViewState`. The compiler prevents `@RenderedViewState` from being used in a SwiftUI view, but the reverse is possible. This mistake causes unexpected runtime behavior and runtime warnings.
  - To a lesser extent, this concern is deflated by the fact that SwiftUI's property wrappers have the same tradeoff (`@State`, `@ObservedObject`, etc.)
  - This can be mitigated by Swift Lint rules
  - See [Alternative: A Single ViewState Property Wrapper](A%20Single%20ViewState%20Property%20Wrapper) for contrast

## Alternatives Considered

Several other solutions were considered which provide similar benefits while making the VSM framework more ergonomic. The three alternatives mentioned below were the most noteworthy.

### UIKit-only @AutoRendered Property Wrapper

The first idea was to introduce a UIKit-specific property wrapper used in conjunction with the `ViewStateRendering` protocol. It was originally dubbed `@AutoRendered` and its sole purpose was to automate the `render()` function call when the view state changes.

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

This solution was to create a single property wrapper called `@ViewState` that works for both UIKit and SwiftUI. It solves all of the problems that the proposed solution solves, with some interesting tradeoffs.

Because the `render()` function requirement is UIKit specific, an extra set of initializers exists for UIKit only.

SwiftUI Example Usage

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

// Default initializer
SomeView(state: .init(wrappedValue: SomeViewState()))
```

UIKit Example Usage

```swift
class SomeViewController: UIViewController {
    @ViewState var state: SomeViewState
    
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

Benefits

- Solves all the problems that the proposed solution solves
- Same name for both UIKit and SwiftUI

Drawbacks

- The simple default initializer for SwiftUI views is lost because the extra set of UIKit initializers prevent the convenience initializer from being inferred by the Swift compiler
- The property wrapper is incorrectly configurable in a way that is not immediately apparent to the developer (ie, if you use the SwiftUI initializer on a UIKit view).
  - It is difficult for the developer to understand which initializers are appropriate in which situations
  - This makes it feel like a problem with the framework instead of a developer education issue.

The proposed solution addresses these drawbacks by providing two distinct property wrappers, one for each paradigm. This simplifies both the implementation code and improves developer understanding of the framework types and requirements.

### ViewState Property Wrapper with ViewStateRendering Extension

This solution extends the above "ViewState Property Wrapper" solution by restoring the `ViewStateRendering` protocol to access the underlying `StateContainer` members, such as `observe` and `bind` without having to go through the `$state` property.

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

This approach changes the `ViewStateRendering` protocol requirement from `container` to `state`. If desired, this could be done in a new alternative protocol (ie, `StateRendering`) to prevent breaking changes in existing VSM implementations that use `ViewStateRendering`.

Benefits

- Accomplishes all the benefits of the solutions above
- Removes the need (but not the capability) of the `$state` prefix to access the `StateContainer` members
- Provides direct access to the underlying `StateContainer` via the `container` property on `ViewStateRendering`
- Is the most ergonomic solution for VSM

Drawbacks

- Introduces a breaking change or the potential workaround of introducing a new/confusing `StateRendering` protocol
- A tiny, but non-zero performance hit *per function call* of `observe`, `bind`, etc. to map the action to the underlying property wrapper's `StateContainer`
- If the user attempts to invoke `observe`, `bind`, et al. without adding the `@ViewState` property wrapper, unexpected runtime behavior will occur
- If Apple ever changes the `_` property wrapper accessor, apps will fail at runtime instead of compile time

## Additional Context

This proposal improves the VSM framework while upholding the original goals of VSM. Specifically, extreme type-safety and determinism while eliminating all possible implementation mistakes. These proposed solutions *do not* introduce new types of risks or potential failure points to the developer workflow. Any risks in these solutions are similar or equal to the existing risks present within the VSM framework.
