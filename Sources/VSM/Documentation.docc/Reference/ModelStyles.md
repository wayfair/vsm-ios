# Model Styles

A compendium of styles for building Models in VSM

## Overview

There are several acceptable coding styles for building models in VSM. The best overall style is generally considered to be "Plain Structs". However, there may be cases where your particular feature would benefit from a slightly different style. In this article, we'll demonstrate some common styles and discuss their tradeoffs.

## Plain Structs

This is the primary recommended style for building models in VSM. With this style, the view state is defined by using a combination of enums and/or structs, and _all models are defined as plain structs_.

Model structs can be defined anywhere that makes sense for your feature — in the same file as the view state, in separate files if they are large or complex, or as nested types inside the view state type via an extension. Nesting is not required, but it is a good organizational practice because it namespaces each model to the view state it belongs to (e.g., `LoadUserProfileViewState.LoaderModel` instead of just `LoaderModel`), which prevents naming conflicts between features.

### Pros

- Simple and idiomatic Swift — plain structs with `async` methods
- No protocol abstractions required; models are unit testable directly
- Dependencies and other data are easy to share between actions within a model via stored properties
- Models can live inline with the view state, in extensions on the view state, or in their own files — whatever suits the complexity of the feature

### Cons

- Model types are not injectable, so SwiftUI Previews, automated UI tests, or demo apps that need to control state must set the state directly rather than through mock models

### Examples

The figures below show examples of different Feature Shapes that use this style.

Figure a. — Models defined inline in the same file, nested inside the view state via extensions:

```swift
// LoadUserProfileViewState.swift

enum LoadUserProfileViewState {
    case initialized(LoaderModel)
    case loading
    case loadingError(LoadingErrorModel)
    case loaded(UserData)
}

extension LoadUserProfileViewState {
    struct LoaderModel: Sendable {
        let dependencies: UserDataProvidingDependency
        let userId: Int
        
        func load() -> StateSequence<LoadUserProfileViewState> {
            StateSequence(
                first: .loading,
                rest: { await fetchUser() }
            )
        }
        
        @concurrent
        private func fetchUser() async -> LoadUserProfileViewState {
            do {
                let userData = try await dependencies.userDataRepository.load(userId: userId)
                return .loaded(userData)
            } catch {
                return .loadingError(LoadingErrorModel(dependencies: dependencies, error: error, userId: userId))
            }
        }
    }
    
    struct LoadingErrorModel: Sendable {
        let dependencies: UserDataProvidingDependency
        let error: Error
        let userId: Int
        
        var message: String {
            error.localizedDescription
        }
        
        func retry() -> StateSequence<LoadUserProfileViewState> {
            LoaderModel(dependencies: dependencies, userId: userId).load()
        }
    }
}
```

Figure b. — Models defined in separate files for a more complex feature. Each model gets its own extension:

```swift
// LoadUserProfileViewState.swift

enum LoadUserProfileViewState {
    case initialized(LoaderModel)
    case loading
    case loadingError(LoadingErrorModel)
    case loaded(UserData)
}
```

```swift
// LoadUserProfileViewState.LoaderModel.swift

extension LoadUserProfileViewState {
    struct LoaderModel: Sendable {
        let dependencies: UserDataProvidingDependency
        let userId: Int
        
        func load() -> StateSequence<LoadUserProfileViewState> {
            StateSequence(
                first: .loading,
                rest: { await fetchUser() }
            )
        }
        
        @concurrent
        private func fetchUser() async -> LoadUserProfileViewState {
            do {
                let userData = try await dependencies.userDataRepository.load(userId: userId)
                return .loaded(userData)
            } catch {
                return .loadingError(LoadingErrorModel(dependencies: dependencies, error: error, userId: userId))
            }
        }
    }
}
```

```swift
// LoadUserProfileViewState.LoadingErrorModel.swift

extension LoadUserProfileViewState {
    struct LoadingErrorModel: Sendable {
        let dependencies: UserDataProvidingDependency
        let error: Error
        let userId: Int
        
        var message: String {
            error.localizedDescription
        }
        
        func retry() -> StateSequence<LoadUserProfileViewState> {
            LoaderModel(dependencies: dependencies, userId: userId).load()
        }
    }
}
```

> Note: Nesting models inside the view state type via extensions is entirely optional. If namespacing is not a concern for your project, models can simply be defined as top-level types alongside the view state.

## Passing Dependencies Through Actions

When using the Plain Structs style, the most straightforward approach is to store dependencies on the model as properties, as shown in the examples above. The view creates the initial model — and all subsequent models — by passing in the dependencies at initialization time.

An alternative is to let the _view_ own the dependencies and pass them into each action function at call time, rather than storing them on the model. This can simplify the view's dependencies on the model (since the model no longer needs to be initialized with dependencies), but it shifts some complexity into the model's action implementations.

**Tradeoffs:**

- **Simpler view init:** The view holds one reference to the dependencies and passes them into actions as needed, rather than constructing each model with dependencies threaded through it.
- **More complex model code:** Because dependencies are not stored on the model, any private helper functions called by an action must also accept the dependencies as a parameter, rather than accessing them via `self`.

The view can pass dependencies into action functions either using an existential type (`any DependencyProtocol`) or generically (`<D: DependencyProtocol>`). The generic approach avoids boxing but requires the view to be generic as well.

### Example

**Dependencies stored on the model (standard approach):**

```swift
// The view initializes the model with dependencies
struct LoadUserProfileView: View {
    @ViewState var state: LoadUserProfileViewState

    init(dependencies: UserDataProvidingDependency, userId: Int) {
        _state = .init(wrappedValue: .initialized(
            LoadUserProfileViewState.LoaderModel(dependencies: dependencies, userId: userId)
        ))
    }
}

// The model stores dependencies and can pass them to private helpers freely
extension LoadUserProfileViewState {
    struct LoaderModel: Sendable {
        let dependencies: UserDataProvidingDependency
        let userId: Int

        func load() -> StateSequence<LoadUserProfileViewState> {
            StateSequence(
                first: .loading,
                rest: { await fetchUser() }
            )
        }

        @concurrent
        private func fetchUser() async -> LoadUserProfileViewState {
            do {
                let userData = try await dependencies.userDataRepository.load(userId: userId)
                return .loaded(userData)
            } catch {
                return .loadingError(LoadingErrorModel(dependencies: dependencies, error: error, userId: userId))
            }
        }
    }
}
```

**Dependencies passed through action functions (view-owned approach):**

```swift
// The view holds the dependencies and passes them into each action
struct LoadUserProfileView: View {
    let dependencies: any UserDataProvidingDependency
    @ViewState var state: LoadUserProfileViewState

    init(dependencies: any UserDataProvidingDependency, userId: Int) {
        self.dependencies = dependencies
        _state = .init(wrappedValue: .initialized(LoadUserProfileViewState.LoaderModel(userId: userId)))
    }

    var body: some View {
        switch state {
        case .initialized(let model):
            Color.clear.onAppear {
                $state.observe(model.load(dependencies: dependencies))
            }
        // ...
        }
    }
}

// The model has no stored dependencies; they are passed in at call time
extension LoadUserProfileViewState {
    struct LoaderModel: Sendable {
        let userId: Int

        func load(dependencies: any UserDataProvidingDependency) -> StateSequence<LoadUserProfileViewState> {
            StateSequence(
                first: .loading,
                rest: { await fetchUser(dependencies: dependencies) }  // dependencies must be threaded through
            )
        }

        @concurrent
        private func fetchUser(dependencies: any UserDataProvidingDependency) async -> LoadUserProfileViewState {
            do {
                let userData = try await dependencies.userDataRepository.load(userId: userId)
                return .loaded(userData)
            } catch {
                return .loadingError(LoadingErrorModel(error: error, userId: userId))
            }
        }
    }
}
```

Choose whichever approach best suits your team's coding style and the complexity of the feature. Neither is strictly required by VSM.

## Protocols for Shared Behavior

Protocols are not needed as a general abstraction for VSM models — plain structs are unit testable without any protocol-based injection. However, protocols are a useful tool when _multiple model types need to share the same action implementation_.

For example, if both a `.loaded` state and a `.loadedEmpty` state need a `refresh()` action, a shared protocol with a default implementation prevents code duplication while keeping each model type independent.

### Pros

- Eliminates code duplication when multiple states need the same action
- Implementation is provided once via a protocol extension, not repeated in each model
- Each model type remains independent and can still have its own state-specific actions

### Cons

- Adds a layer of indirection that may be confusing if overused
- Protocol names must be globally unique since protocols cannot be nested within other types

### Example

```swift
protocol UserProfileRefreshable: Sendable {
    var dependencies: UserDataProvidingDependency { get }
    var userId: Int { get }
}

extension UserProfileRefreshable {
    func refresh() -> StateSequence<LoadUserProfileViewState> {
        StateSequence(
            first: .loading,
            rest: { await fetchUser() }
        )
    }
    
    @concurrent
    private func fetchUser() async -> LoadUserProfileViewState {
        do {
            let userData = try await dependencies.userDataRepository.load(userId: userId)
            return .loaded(userData)
        } catch {
            return .loadingError(LoadUserProfileViewState.LoadingErrorModel(
                dependencies: dependencies,
                error: error,
                userId: userId
            ))
        }
    }
}

extension LoadUserProfileViewState {
    struct LoadedModel: UserProfileRefreshable {
        let dependencies: UserDataProvidingDependency
        let userId: Int
        let userData: UserData
    }
    
    struct LoadingErrorModel: UserProfileRefreshable {
        let dependencies: UserDataProvidingDependency
        let userId: Int
        let error: Error
        
        var message: String { error.localizedDescription }
    }
}
```

Both `LoadedModel` and `LoadingErrorModel` get the `refresh()` action automatically, while each can still define its own state-specific properties and actions.
