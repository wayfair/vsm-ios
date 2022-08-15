[![Release](https://img.shields.io/github/v/release/wayfair-incubator/vsm-ios?display_name=tag)](CHANGELOG.md)
[![Lint](https://github.com/wayfair-incubator/vsm-ios/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/wayfair-incubator/vsm-ios/actions/workflows/lint.yml)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![Maintainer](https://img.shields.io/badge/Maintainer-Wayfair-7F187F)](https://wayfair.github.io)

# VSM for iOS

VSM is a unidirectional, type-safe, behavior-driven, clean architecture. This repository hosts an open-source swift package framework for easily building features in VSM on iOS.

Open the [Demo App](Demos/Shopping) to see in-depth examples of how to build features using the VSM pattern.

## Overview

VSM stands for ***V***iew ***S***tate ***M***odel. The **View** observes and renders the **State**. Each **State** may provide a **Model**. Each **Model** contains the **Data** and **Action**s available in the given **State**. Each **Action** in a **Model** returns a new **State**. **State** changes cause the **View** to update.

![VSM Diagram](vsm-diagram.png)

In this module, the provided `StateContainer` type encapsulates and observes the State. A `ViewStateRendering` view (SwiftUI or UIKit) can observe the `container.state` value for rendering the States as they change.

## Index

- [Getting Started](#getting-started)
  1. [Define your States and Models](#1-define-your-states-and-models)
  1. [Define your View](#2-define-your-view)
  1. [Render the current State](#3-render-the-current-state)
  1. [Add behaviors to your View](#4-add-behaviors-to-your-view)
  1. [Using your View](#5-using-your-view)
- [Additional Learning](#additional-learning)
  - [Improving Testability](#improving-testability)
  - [Breaking State Cycles with Builders](#breaking-state-cycles-with-builders)
  - [Options for Controlling State Flow](#options-for-controlling-state-flow)

## Getting started

In the following steps, we will walk through building a feature that loads a blog post from an API. Once loaded, the user will see the blog text and a delete button. The delete button will send a "delete" message to the API and then show a completion screen.

### 1. Define your States and Models

Once you have read and internalized the feature requirements, you will convert these requirements into a "State Journey" which will be defined in a series of swift types (usually enums and structs).

First, we'll start by declaring the State/ViewState enum which defines every State that your View can be in, along with the protocols that contain the Data and Actions that the user will be able to see and do in each State.

```swift
enum BlogViewState {
    case initialized(BlogLoaderModeling)
    case loading
    case loaded(LoadedBlogModeling)
    case deleted
}

protocol BlogLoaderModeling {
    func loadBlog() -> AnyPublisher<BlogViewState, Never>
}

protocol LoadedBlogModeling {
    var blogText: String { get }
    func delete() -> AnyPublisher<BlogViewState, Never>
}
```

You'll notice that each of the Actions above ***returns a new State*** (or a future State publisher). This is the essence of the VSM design pattern. Every Action should emit a new State to update the View, and move the user along the "State Journey".

Next, we will define the concrete behavior for each of these Models.

```swift
struct BlogLoaderModel: BlogLoaderModeling {
    let blogId: Int

    func loadBlog() -> AnyPublisher<BlogViewState, Never> {
        // Builds a publisher that immediately sets the State to `.loading`
        let statePublisher = CurrentValueSubject<BlogViewState, Never>(.loading)
        BlogAPI.getBlog(blogId) { blogText in
            // After the blog is loaded, the new `.loaded` State is emitted on the same publisher
            statePublisher.value = .loaded(LoadedBlogModel(blogId: blogId, blogText: blogText))
        }
        return statePublisher.eraseToAnyPublisher()
    }
}

struct LoadedBlogModel: LoadedBlogModeling {
    let blogId: Int
    let blogText: String

    func delete() -> AnyPublisher<BlogViewState, Never> {
        // Kicks off a fire-and-forget delete operation
        BlogAPI.queueBlogForDeletion(blogId)
        // Immediately returns the new `.deleted` State
        return Just(BlogViewState.deleted).eraseToAnyPublisher()
    }
}
```

You can add any number of supporting functions to a Model, as long as they are directly related to the _single-purpose_ of the Model. (Such as converting API data to viewable format to support `loadBlog()`.) These ancillary functions will be hidden from the View by the protocols associated with each State.

Note that the above Models omit some dependency injection. These examples are meant to convey only the basic structure of how States and Models correlate.

Detailed explanations can be found below this guide which cover complex topics such as using a "Builder" to offload the responsibility of constructing each State's Model. In addition, examples of using Composed-Protocol Dependency Injection (CPDI) to satisfy your Model's dependency needs can be found in the [Demo App](Demos/Shopping).

### 2. Define your View

First, build your SwiftUI `View` (or UIKit `UIViewController`/`UIView`) and conform it to the `ViewStateRendering` protocol. This will require that you define a `StateContainer` property with your feature's State/ViewState type.

#### SwiftUI

```swift
struct BlogView: View, ViewStateRendering {
    @StateObject var container: StateContainer<BlogViewState>
    ...
}
```

#### UIKit

```swift
class BlogViewController: UIViewController, ViewStateRendering {
    var container: StateContainer<BlogViewState>
    var cancellable: AnyCancellable?

    init(state: BlogViewState) {
        container = .init(state: state)
        super.init(nibName: nil, bundle: nil)
        cancellable = container.$state.sink { [weak self] newState in self?.render(state: newState) }
    }
    ...
}
```

### 3. Render the current State

Next, you'll want to add code that draws the State on screen when it updates/loads.

#### SwiftUI

```swift
...
var body: some View {
    VStack {
        switch container.state {
        case .loading, .initialized:
            ProgressView()
        case .loaded(let loadedBlogModel):
            Text(loadedBlogModel.blogText)
            Button("Delete")
        case .deleted:
            Text("Deleted!")
        }
    }
}
...
```

#### UIKit

```swift
...
func render(state: BlogViewState) {
    switch state {
    case .loading, .initialized:
        showLoadingState()
    case .loaded(let loadedBlogModel):
        hideLoadingState()
        blogTextView.text = loadedBlogModel.blogText
    case .deleted:
        showDeletedState()
    }
}
...
```

### 4. Add behaviors to your View

Now that your View is drawing each State, you'll want to add behaviors to your View.

To do this, you call the Action functions found on each State. **Be sure to _OBSERVE_ each Action using `container.observe(...)` or the State progression will fail.** (Don't worry, the compiler will warn you if you forget.)

#### SwiftUI#### 

```swift
...
var body: some View {
    VStack {
        switch container.state {
        case .loading, .initialized:
            ...
        case .loaded(let loadedBlogModel):
            ...
            Button("Delete") {
                container.observe(loadedBlogModel.delete())
            }
        case .deleted:
            ...
        }
    }.onAppear {
        if case .initialized(let blogLoaderModel) = container.state {
            container.observe(blogLoaderModel.loadBlog())
        }
    }
}
...
```

#### UIKit

```swift
...
override func viewDidLoad() {
    super.viewDidLoad()
    if case .initialized(let blogLoaderModel) = container.state {
        container.observe(blogLoaderModel.loadBlog())
    }
}
...
func render(state: BlogViewState) {
    switch state {
    case .loading, .initialized:
        ...
    case .loaded(let loadedBlogModel):
        ...
        deleteButton.addAction(UIAction(handler: { _ in
            container.observe(loadedBlogModel.delete())
        }), for: .touchUpInside)
    case .deleted:
        ...
    }
}
...
```

### 5. Using your View

Now we are ready to use the Blog feature that we built using the VSM pattern. Here is one example of how to instantiate a `ViewStateRendering` view:

#### SwiftUI

```swift
BlogView(stateContainer: .init(state: .initialized(BlogLoaderModel(blogId: 1))))
```

#### UIKit

```swift
BlogViewController(state: .initialized(BlogLoaderModel(blogId: 1)))
```

Initialization of a `ViewStateRendering` view is very flexible. You can customize how it is instantiated and what parameters are required. A good example is to add a convenience initializer that accepts the dependencies and other parameters without expecting outside callers to know about the internal States of the `ViewStateRendering` view. For example:

#### SwiftUI

```swift
struct BlogView: View, ViewStateRendering {
    ...
    init(urlSession: UrlSession, blogId: Int) {
        _container = .init(state: .initialized(BlogLoaderModel(urlSession: urlSession, blogId: blogId)))
        // Optional: You can call blogLoaderModel.loadBlog() here if you don't want to wait for onAppear
    }
    ...
}

// Resulting in the following initialization code:
BlogView(urlSession: .shared, blogId: 1)
```

#### UIKit

```swift
class BlogViewController: UIViewController, ViewStateRendering {
    ...
    init(urlSession: UrlSession, blogId: Int) {
        container = .init(state: .initialized(BlogLoaderModel(urlSession: urlSession, blogId: blogId)))
        // Optional: You can call blogLoaderModel.loadBlog() here if you don't want to wait for viewDidLoad
        ...
    }
    ...
}

// Resulting in the following initialization code:
BlogViewController(urlSession: .shared, blogId: 1)
```

## Additional Learning

### Improving Testability

To improve the testability of your Models, you shouldn't instantiate other concrete Model types directly within your Model. Instead, you should require that Model builders be injected into each Model.

This will allow a unit test to focus on a single Model type by mocking the construction of other Models. Doing so eliminates the possibility of accidentally invoking any other Model types or encountering other side effects in your tests.

The following is an example of a simple function being used to abstract the construction of the next State's Model:

```swift
struct BlogLoaderModel: BlogLoaderModeling {
    let blogId: Int
    let loadedBlogModelBuilder: (Int, String) -> LoadedBlogModeling

    func loadBlog() -> AnyPublisher<BlogViewState, Never> {
        let statePublisher = CurrentValueSubject<BlogViewState, Never>(.loading)
        BlogAPI.getBlog(blogId) { blogText in
            statePublisher.value = .loaded(loadedBlogModelBuilder(blogId, blogText))
        }
        return statePublisher.eraseToAnyPublisher()
    }
}
```

Now, the code that constructs the next State's Model is encapsulated by the builder function. This allows you to inject mocks for the next State's Model for unit testing each Action in isolation, like so:

```swift
let mockLoadedBlogModel = MockLoadedBlogModel(...)
let subject = BlogLoaderModel(..., loadedBlogModelBuilder: { _ in return mockLoadedBlogModel })
let output: [BlogViewState] = try awaitPublisher(subject.loadBlog())
if let newState = output.first, case .loaded(let model) = newState { /*no-op*/ } else {
    XCTFail("loadBlog Action failed to produce the correct state.")
}
```

### Breaking State Cycles with Builders

Some "State Journeys" can be cyclical, which can cause problems when trying to make Models mockable and unit-testable (see [above](#improving-testability)). For example, if we added a "reload" Action to the blog feature on the `.loaded` State, the `LoadedBlogModel` would require a builder for `BlogLoaderModel` and vice-versa. Like so:

```swift
struct BlogLoaderModel {
    ...
    let loadedBlogModelBuilder: (Int, String) -> LoadedBlogModeling

    func loadBlog() -> AnyPublisher<BlogViewState, Never> {
        ...
        statePublisher.value = .loaded(loadedBlogModelBuilder(blogId, blogText))
        ...
    }
}

struct LoadedBlogModel {
    ...
    let blogLoaderModelBuilder: (Int) -> BlogLoaderModeling

    func reload() -> AnyPublisher<BlogViewState, Never> {
        return blogLoaderModelBuilder(blogId).loadBlog()
    }
}
```

But how would you instantiate `BlogLoaderModel` if both Models require instructions on how to build each other?

```swift
let blogLoaderModel = BlogLoaderModel(..., loadedBlogModelBuilder: {
    LoadedBlogModel(..., blogLoaderModelBuilder: {
        BlogLoaderModel(..., loadedBlogModelBuilder: {
            // and so on, forever...
        })
    })
})

BlogView(container: .init(state: .initialized(blogLoaderModel)))
```

As you can see, the Model constructors are unresolvable if the States can loop.

In order to break the cycle, a tie-breaker is needed. A single "Model Builder" type can be injected into each Model to offload the process of building other Models. For example:

```swift
protocol BlogModelBuilding {
    func buildBlogLoaderModel(blogId: Int) -> BlogLoaderModeling
    func buildLoadedBlogModel(blogId: Int, blogText: String) -> LoadedBlogModeling
}

class BlogModelBuilder: BlogModelBuilding {
    func buildBlogLoaderModel(blogId: Int) -> BlogLoaderModeling {
        return BlogLoaderModel(blogId: blogId, modelBuilder: self)
    }

    func buildLoadedBlogModel(blogId: Int, blogText: String) -> LoadedBlogModeling {
        return LoadedBlogModel(blogId: blogId, blogText: blogText, modelBuilder: self)
    }
}

struct BlogLoaderModel: BlogLoaderModeling {
    ...
    let modelBuilder: BlogModelBuilding
    ...
    func loadBlog() -> AnyPublisher<BlogViewState, Never> {
        ...
        statePublisher.value = .loaded(modelBuilder.buildBlogLoaderModel(blogId: blogId, blogText: blogText))
        ...
    }
}

struct LoadedBlogModel: LoadedBlogModeling {
    ...
    let modelBuilder: BlogModelBuilding
    ...
    func reload() -> AnyPublisher<BlogViewState, Never> {
        return modelBuilder.buildBlogLoaderModel(blogId: blogId).loadBlog()
    }
}
...
let blogLoaderModel = BlogLoaderModel(..., modelBuilder: BlogModelBuilder())

BlogView(container: .init(state: .initialized(blogLoaderModel)))
```

Now, the code that constructs each Model is encapsulated within the Builder. This allows you to inject mocks for each Model to unit test each Action in isolation, like so:

```swift
let mockBlogLoaderModel = MockBlogLoaderModel(loadBlogImpl: {
    return Just(BlogViewState.loading).eraseToAnyPublisher()
})
let mockBuilder = MockBlogModelBuilder(buildBlogLoaderModelImpl: { _ in
    return mockBlogLoaderModel
})
let subject = LoadedBlogModel(..., modelBuilder: mockModelBuilder)
let output: [BlogViewState] = try awaitPublisher(subject.reload())
XCTAssertEqual(output.first, BlogViewState.loading, "reload Action failed to produce the correct state.")
```

### Options for Controlling State Flow

Sometimes you don't need the full power (and overhead) of Combine `Publisher`s to manage the flow of State in your feature. There are two other options you can use to manage how an Action leads to a new State:

#### Async/Await

You can utilize Swift's async/await behavior to progress from one State to another by conforming your Action to the async/await requirements, like so:

```swift
func delete() async -> BlogViewState {
    await BlogAPI.deleteBlog(blogId)
    return .deleted
}
```

The main limitation of using async/await is that you can only emit one new State from the Action. Here's how you would observe that function call from the View:

```swift
container.observe({ await loadedBlogModel.delete() })
```

#### Synchronous State Progression

If you are _synchronously_ moving from one State to another you can simply return a new State from any Action, like so:

```swift
func delete() -> BlogViewState {
    BlogAPI.queueBlogForDeletion(blogId)
    return .deleted
}
```

The two limitations of this approach are that you can only emit one State and it must be returned immediately. Here's how you would observe that function call from the View:

```swift
container.observe(loadedBlogModel.delete())
```

#### No State Progression

In some scenarios, an Action may not need to emit a new State for the current View. Instead, these Actions kick off some external, ancillary, or silent process. For these cases, your Model's Action can return `Void`. For example:

```swift
func autoSaveBlogChanges(_ blogText: String) {
    BlogCache.autoSave(blogText)
}
```

No observation of the Action is necessary in the view because it does not emit a new State:

```swift
@State editedText = ""

var body: some View {
    TextField("Blog Text", text: $blogText)
        .onChange(of: blogText) { newValue in
            loadedBlogModel.autoSaveBlogChanges(newValue)
        }
}
```

## Project Information

### Credits

VSM for iOS is owned and [maintained](MAINTAINERS.md) by [Wayfair](https://www.wayfair.com/).

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

### Security

See [SECURITY.md](SECURITY.md).

### License

VSM for iOS is released under the MIT license. See [LICENSE](LICENSE) for details.
