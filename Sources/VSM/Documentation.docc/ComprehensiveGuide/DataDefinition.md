# Working with Data

A guide for building reactive data repositories with Combine for VSM

## Overview

VSM is a reactive architecture. Views observe and render a stream of view states. The source of these view states are streams of observable data which are weaved and formed into the desired view states within the VSM models.

If these observable repositories are shared between VSM views, then they will automatically update as the state of data changes. This helps significantly reduce the volume of code required to keep data in sync between views and communicate changes in data state between views.

These reactive data sources can use Combine Publishers to communicate changes in the state of data to any observer. Repositories can adapt in shape and behavior to best suit the type of data being shared and the behaviors associated with managing that data.

## Basic Structure

The outline for a reactive repository for our earlier examples may look something like this:

```swift
protocol UserDataProviding {
    var userDataPublisher: AnyPublisher<UserDataState, Never> { get }
    func load() -> AnyPublisher<UserData, Error>
    func save(userData: UserData) -> AnyPublisher<UserData, Error>
}

enum UserDataState {
    case loading
    case loaded(UserData)
}
```

You'll notice that there's a user data publisher property as well as publishers returned from each of the data operations. These two publisher types have unique purposes.

The data publisher property exists to let features react to any updates to the user's data.

The publishers returned from the functions let features react to the individual data operations and handle any problems that arise in their completion.

The basic implementation for the repository may look something like this:

```swift
struct UserDataRepository: UserDataProviding {
    private var userDataSubject = CurrentValueSubject<UserDataState, Never>(.loading)
    var userDataPublisher: AnyPublisher<UserDataState, Never> {
        userDataSubject.share().eraseToAnyPublisher()
    }

    func load() -> AnyPublisher<UserData, Error> {
        ...
    }

    func save(userData: UserData) -> AnyPublisher<UserData, Error> {
        ...
    }
}
```

We choose to manage the user data by way of the `CurrentValueSubject` publisher which always emits the current value to new subscribers and will emit any future changes to the subject's value property (or `.send(_:)` function). We also make sure to set the error type to `Never` because this specific publisher is only meant to keep track of the most recent stable value.

We expose the current value by using a type-erased publisher property, as dictated by the `UserDataProviding` protocol. We make sure to `share()` this publisher so that all subscribers receive the same state updates.

Now, how do we keep this shared value up to date? As we implement the actions that manipulate the data, as you would expect from any repository, we'll make sure those actions appropriately update the state of the data.

```swift
func load() -> AnyPublisher<UserData, Error> {
    URLSession.shared.dataTaskPublisher(for: loadUrl)
        .tryMap(\.data)
        .decode(type: UserData.self, decoder: JSONDecoder())
        .map { userData -> UserData in
            userDataSubject.value = .loaded(userData)
            return userData
        }
        .eraseToAnyPublisher()
}

func save(userData: UserData) -> AnyPublisher<UserData, Error> {
    var request = URLRequest(url: saveUrl)
    request.httpMethod = "POST"
    do {
        request.httpBody = try JSONEncoder().encode(userData)
    } catch {
        return Fail(error: error).eraseToAnyPublisher()
    }
    return URLSession.shared.dataTaskPublisher(for: request)
        .tryMap { _ in userData }
        .eraseToAnyPublisher()
}
```

The save function sends the changes to the API. Assuming the save API returns an empty "success" response, we then use the map function to replace the empty result with the updated user data object. Depending on your situation, you can manipulate a published stream of data by using any of Combine's in-line publisher manipulation functions, such as `map`, `flatMap`, `catch`, etc. Alternatively, you could use the `sink` operation while managing the subscriptions within the repository.

## Using Observable Repositories in VSM

Now that we have the `UserDataProviding` protocol, any VSM feature can use it as a dependency. The concrete `UserDataRepository` type can be initialized at a higher level in the app and then be passed into whichever VSM views need it. This guarantees that the underlying data will be synchronized across all views. The repository is passed around by including it in the initializers for the view and the corresponding models.

For example, we have the User Profile Editor VSM feature, but we want to add a User Bio VSM feature, which will display the user's username and photo. The feature shape of the User Bio can look something like this:

```swift
enum UserBioViewState {
    case initialized(LoaderModel)
    case loading
    case loaded(UserData)
    case loadingError(ErrorModel)
    
    struct LoaderModel {
        let load: () -> AnyPublisher<UserBioViewState, Never>
    }
    
    struct ErrorModel {
        let message: String
        let retry: () -> AnyPublisher<UserBioViewState, Never>
    }
}
```

To support this feature shape, the User Bio models can be as simple as the following:

```swift
extension UserBioViewState.LoaderModel {
    init(repository: UserDataProviding) {
        load = {
            Self.loadUserData(from: repository)
                .merge(with: Self.getUserDataStream(from: repository))
                .eraseToAnyPublisher()
        }
    }
    
    private static func loadUserData(from repository: UserDataProviding) -> AnyPublisher<UserBioViewState, Never> {
        repository.load()
            .map { UserBioViewState.loaded($0) }
            .catch { error -> Just<UserBioViewState> in
                let errorModel = UserBioViewState.ErrorModel(repository: repository, message: error.localizedDescription)
                return Just(UserBioViewState.loadingError(errorModel))
            }
            .eraseToAnyPublisher()
    }
    
    private static func getUserDataStream(from repository: UserDataProviding) -> AnyPublisher<UserBioViewState, Never> {
        repository.userDataPublisher
            .map { dataState -> UserBioViewState in
                switch dataState {
                case .loading:
                    return .loading
                case .loaded(let userData):
                    return .loaded(userData)
                }
            }
            .eraseToAnyPublisher()
    }
}

extension UserBioViewState.ErrorModel {
    init(repository: UserDataProviding, message: String) {
        self.message = message
        retry = {
            UserBioViewState.LoaderModel(repository: repository).load()
        }
    }
}
```

The loader model above triggers the user data to load and then merges the persistent user data stream into a single view state publisher. The error model allows the load to be retried in case of failure. This approach is durable and safe for use across the entire app.

With the above models, the User Bio feature is guaranteed to always have the most up-to-date version of the user data. It will update the very instant that any changes occur within the User Profile Editor feature, even if that feature is launched from a distant location within the app view hierarchy.

## Composed Protocol Dependency Injection

When considering how to share these repositories across your app, there are many viable approaches to dependency injection. A recommended approach that is type-safe, follows the least-knowledge architectural principle, and has a 0% chance of runtime crashes is the Composed Protocol Dependency Injection approach or CPDI for short.

The above dependency can be shared easily via CPDI by adding the following protocol:

```swift
protocol UserDataProvidingDependency {
    var userDataRepository: UserDataProviding { get }
}
```

Then your model and view can declare a Dependency type alias which contains all the dependency protocol types aggregated together via the `&` operator, like so:

```swift
typealias Dependencies = UserDataProvidingDependency
                         & FooDepencency
                         & BarDependency
                         & BazDependency
```

The resulting initializer chain will end up looking something like this:

```swift
struct UserBioView: View, ViewStateRendering {
    typealias Dependencies = UserBioViewState.LoaderModel.Dependencies
                             & UserBioViewState.ErrorModel.Dependencies
    init(dependencies: Dependencies) {
        let loaderModel = UserBioViewState.LoaderModel(dependencies: Dependencies)
        let state = UserBioViewState.initialized(loaderModel)
        _container = .init(state: state)
    }
}

extension UserBioViewState.LoaderModel {
    typealias Dependencies = UserDataProvidingDependency
    init(dependencies: Dependencies) {
        load = {
            dependencies.userDataRepository.load()
            ...
        }
    }
}
```

CPDI reduces the frustration of dependency-hot-potato by reducing the number of disparate dependency values that must be passed from initializer to initializer throughout the view hierarchy of your app. It does this by implicitly aggregating all of your disparate dependencies into a single dependency variable which preserves the correct scope limitations at every level of your app. This dependency only needs to be satisfied once at the root of your app.

```swift
struct AppDependencies: RootView.Dependencies {
    init() {
        // Spin up all dependencies or provide closures for spinning up dependencies on-demand
    }
}

@main
struct VSMDocsExampleApp: App {
    var body: some Scene {
        WindowGroup {
            RootView(dependencies: AppDependencies())
        }
    }
}
```

The `RootView.Dependencies` type is the combination of its child view dependency types, and each child dependency type is the combination of that child's children's dependency types, and so on. As a result, the `RootView.Dependencies` type contains all of the dependency requirements for the entire app in a single parameter.

Depending on your app's requirements there may be some hurdles to overcome when using this approach, especially concerning app startup speed, memory use, and asynchronously loaded dependencies. However, none of these issues are insurmountable. All in all, the CPDI approach to dependency injection is a proven solution that does not require any third-party dependency injection libraries. It is a great option when considering how to share your observable repositories across your app.

## Up Next

### Unit Testing VSM features

Now that you know how to use observable repositories to power VSM features, you can learn how to write unit tests to validate the requirements of VSM features in <doc:UnitTesting>.

#### Support this Project

If you find anything wrong with this guide, or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
