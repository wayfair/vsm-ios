# Model Styles - VSM Reference

A compendium of styles for building models in VSM

## Overview

There are several acceptable coding styles for building models in VSM. The best overall style is generally considered to be "Protocols with Structs". However, there may be cases where your particular feature would benefit more from a slightly different style. In this article, we'll demonstrate some common styles and discuss their tradeoffs.

## Protocols with Structs

This is the primary recommended style for building models in VSM. With this style, the view state is defined by using a combination of structs and enums, but _all models are defined along side the view state with protocols_.

These protocols are not used for injection, mind you. VSM models are inherently unit testable without the need for injecting models. However, they do have the following 3 benefits:

1. They support the ["least knowledge"](https://en.wikipedia.org/wiki/Law_of_Demeter) architectural principle by limiting which properties and functions on the Model are visible to the View
1. They help the engineer stay on target when implementing the Model by providing compiler-enforcement of the Feature Shape contract
1. If desired, they allow the engineer to do the "layered pass" development approach, where the View and the Feature Shape are built together without having to implement any functionality. This approach may help catch feature requirement problems before they are implemented incorrectly

### Pros

- The benefits listed above
- Fewest lines of code in comparison to the other styles
- Working with protocols is familiar to many devs
- The implementation for each model is very easy to read
- The implementation for each model can be located in separate files for better organization and separation
- It's easy to share dependencies and other data between actions within a model

### Cons

- Using protocols without the intent to inject can be a little misleading
- Protocol definitions cannot be nested within other types, so model protocol names will have to be unique between features
- The protocols may require separate mock objects in order to support SwiftUI Previews, Automated UI tests, or demo applications

### Examples

The figures below show examples of different Feature Shapes that use this style.

Figure a.

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
    var message: String { get }
    func retry() -> AnyPublisher<LoadUserProfileViewState, Never>
}
```

Figure b.

```swift
struct EditUserProfileViewState {
    var data: UserData
    var editingState: EditingState
    
    enum EditingState {
        case editing(EditingModeling)
        case saving
        case savingError(ErrorModeling)
    }
}

protocol EditingModeling {
    func saveUsername(_ username: String) -> AnyPublisher<EditUserProfileViewState, Never>
}

protocol ErrorModeling {
    var message: String { get }
    func retry() -> AnyPublisher<EditUserProfileViewState, Never>
    func cancel() -> AnyPublisher<EditUserProfileViewState, Never>
}
```

To implement the `LoadUserProfileViewState` models in this style, we create structs that implement the protocols. To protect the access of properties and functions from one model to another, standard `public|internal|private` accessors can be used on each member of the model.

See the following example for details.

```swift
struct LoaderModel: LoaderModeling {
    typealias Dependencies = UserDataProvidingDependency
    let dependencies: Dependencies
    let userId: Int
    
    func load() -> AnyPublisher<LoadUserProfileViewState, Never> {
        Just(.loading)
            .merge(with:
                    dependencies.userDataRepository.load()
                        .map { userData in
                            LoadUserProfileViewState.loaded(userData)
                        }
                        .catch { error in
                            handleLoadingError(error)
                        }
            )
            .eraseToAnyPublisher()
    }
    
    private func handleLoadingError(_ error: Error) -> Just<LoadUserProfileViewState> {
        NSLog("Error loading user data: \(error)")
        let errorModel = LoadingErrorModel(dependencies: dependencies, error: error, userId: userId)
        return Just(LoadUserProfileViewState.loadingError(errorModel))
    }
}

struct LoadingErrorModel: LoadingErrorModeling {
    typealias Dependencies = LoaderModel.Dependencies
    let dependencies: Dependencies
    let error: Error
    let userId: Int
    
    var message: String {
        error.localizedDescription
    }
    
    func retry() -> AnyPublisher<LoadUserProfileViewState, Never> {
        LoaderModel(dependencies: dependencies, userId: userId).load()
    }
}
```

> Note: It is possible to use the "Protocols with Structs" style along with a builder protocol and struct which offloads the responsibility of constructing each of the models. The builder is injected into each model which can be used to build any other model needed.
>
> While that would make everything fully injectable, **it increases the lines of code per feature by about 10% with virtually no additional value**. As mentioned above, no model injection is necessary for unit testing VSM models.
>
> Regardless, here is an example of a builder that would be used in models above:
>
> ```swift
> struct LoadModelBuilder: LoadModelBuilding {
>     typealias Dependencies = LoaderModel.Dependencies & LoadingErrorModel.Dependencies
>     let dependencies: Dependencies
>     
>     func buildLoaderModel() -> LoaderModeling {
>         LoaderModel(dependencies: dependencies, builder: self)
>     }
>     
>     func buildLoadingErrorModel(error: Error) -> LoadingErrorModeling {
>         LoadingErrorModel(dependencies: dependencies, builder: self, error: error)
>     }
> }
> ```

## Struct Extensions

This approach declares each model as a struct with closures for the actions. Each model struct is then extended to provide an initializer that sets the concrete implementation of the action closures.

### Pros

- Doesn't require any special mock types for unit testing, SwiftUI previews, UI tests, demo apps, etc. because the structs act as both the protocol and implementation
- The implementation for each model is somewhat easy to read
- The implementation for each model can be located in separate files for better organization and separation
- The model types can be defined within the view state type, allowing for conflict-proof naming like `LoadUserProfileViewState.LoaderModel`

### Cons

- Uses closures for the actions, which is not a common programming style
- Closures cannot have parameter names. This makes it difficult to follow Swift function naming conventions and can make the code a bit harder to read
- Odd syntax is required for defining the model's behavior within the initializer because `self` cannot be accessed until all required members are assigned. This is a "catch-22" problem because the closures that need to reference `self` are required members that must be set within the initializer. To get around this, you either have to assign the closure to a "no-op" implementation, like `load = { Empty().eraseToAnyPublisher() }` and then assign it again to the actual closure implementation within the same initializer. Alternatively, you can use static members within the action closures instead of requiring `self`.
- Dependencies and other data are shared between actions within a model by passing them along with each function call
  - Engineers may be tempted to over-share model members with the view to reduce the friction of passing dependencies and data between the actions

### Examples

The figures below show examples of different Feature Shapes that use this style.

Figure a.

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

Figure b.

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

To implement the `LoadUserProfileViewState` models in this style, we extend the model structs. To protect the access of properties and functions from one model to another, standard `public|internal|private` accessors can be used on each member of the model.

```swift
extension LoadUserProfileViewState.LoaderModel {
    typealias Dependencies = UserDataProvidingDependency
    
    init(dependencies: Dependencies, userId: Int) {
        load = {
            Just(.loading)
                .merge(with: Self.load(dependencies: dependencies))
                .eraseToAnyPublisher()
        }
    }
    
    private static func load(dependencies: Dependencies, userId: Int) -> AnyPublisher<LoadUserProfileViewState, Never> {
        dependencies.userDataRepository.load(userId: userId)
            .map { userData in
                LoadUserProfileViewState.loaded(userData)
            }
            .catch { error in
                handleLoadingError(dependencies: dependencies, error, for: userId)
            }
            .eraseToAnyPublisher()
    }
    
    private static func handleLoadingError(dependencies: Dependencies, _ error: Error, for userId: Int) -> Just<LoadUserProfileViewState> {
        NSLog("Error loading user data: \(error)")
        let errorModel = LoadUserProfileViewState.ErrorModel(dependencies: dependencies, error: error, userId: userId)
        return Just(LoadUserProfileViewState.loadingError(errorModel))
    }
}

extension LoadUserProfileViewState.ErrorModel {
    typealias Dependencies = LoadUserProfileViewState.LoaderModel.Dependencies
    
    init(dependencies: Dependencies, error: Error, userId: Int) {
        self.message = error.localizedDescription
        retry = {
            LoadUserProfileViewState.LoaderModel(dependencies: dependencies, userId: userId).load()
        }
    }
}
```

As mentioned in the "Pros" section, SwiftUI Previews can easily be populated using this approach without the need for creating custom mock objects for the models:

```swift

struct LoadUserView_Previews: PreviewProvider {
    let previewErrorState = .loadingError(
        LoadUserProfileViewState.ErrorModel(
            dependencies: MockDependencies(),
            error: NSError(code: 1, domain: "")
        )
    )

    static var previews: some View {
        LoadUserView(state: previewErrorState)
            .previewDisplayName("Loading Error State")
    }
}

```

## Struct Builder

This approach uses the exact same Feature Shape style as the "Struct Extensions", but its implementation approach is drastically different. Instead of implementing the model by extending the model struct, the Struct Builder style uses a builder struct to provide the implementation to each model. This builder struct has a function for building each model. Within each model function, there are nested functions that contain the actual functionality of the feature.

### Pros

- Doesn't require any special mock types for unit testing, SwiftUI previews, UI tests, demo apps, etc. because the structs act as both the protocol and implementation
- The model types can be defined within the view state type, allowing for conflict-proof naming like `LoadUserProfileViewState.LoaderModel`
- May feel more familiar to MVVM engineers because all the implementation code is contained in one type

### Cons

- Somewhat difficult to read
- Uses closures for the actions, which is not a common programming style
- Closures cannot have parameter names. This makes it difficult to follow Swift function naming conventions and can make the code a bit harder to read
- Odd syntax is required for defining the model's behavior within the builder because nested functions are required
- Dependencies and other data are shared between actions within a model by passing them along with each function call
  - Engineers may be tempted to over-share model members with the view to reduce the friction of passing dependencies and data between the actions
- Engineers may be tempted to share functions between models by way of the builder. This would violate the VSM architecture principles
- The builder may become bloated because it contains the entire feature's implementation

### Examples

To implement the `LoadUserProfileViewState` models in this style, we create a builder struct which provides all the functionality. To protect the access of properties and functions from one model to another, nested functions are used.

```swift
struct LoadModelBuilder {
    typealias Dependencies = UserDataProvidingDependency
    let dependencies: Dependencies
    let userId: Int
    
    func buildLoaderModel() -> LoadUserProfileViewState.LoaderModel {
        func load() -> AnyPublisher<LoadUserProfileViewState, Never> {
            Just(.loading)
                .merge(with:
                        dependencies.userDataRepository.load(userId: userId)
                            .map { userData in
                                LoadUserProfileViewState.loaded(userData)
                            }
                            .catch { error in
                                handleLoadingError(error)
                            }
                )
                .eraseToAnyPublisher()
        }
        
        func handleLoadingError(_ error: Error) -> Just<LoadUserProfileViewState> {
            NSLog("Error loading user data: \(error)")
            let errorModel = buildErrorModel(error: error)
            return Just(LoadUserProfileViewState.loadingError(errorModel))
        }
        
        return LoadUserProfileViewState.LoaderModel(load: load)
    }
    
    func buildErrorModel(error: Error) -> LoadUserProfileViewState.ErrorModel {
        LoadUserProfileViewState.ErrorModel(
            message: error.localizedDescription,
            retry: buildLoaderModel().load
        )
    }
}
```
