[![Release](https://img.shields.io/github/v/release/wayfair/vsm-ios?display_name=tag)](CHANGELOG.md)
[![Lint](https://github.com/wayfair/vsm-ios/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/wayfair/vsm-ios/actions/workflows/lint.yml)
[![CI](https://github.com/wayfair/vsm-ios/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/wayfair/vsm-ios/actions/workflows/ci.yml)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![Maintainer](https://img.shields.io/badge/Maintainer-Wayfair-7F187F)](https://wayfair.github.io)

# VSM for Apple Platforms

VSM is a reactive architecture that is unidirectional, highly type-safe, behavior-driven, and clean. This repository hosts an open-source swift package framework for easily building features in VSM on app publicly available Apple platforms.

## Overview

VSM stands for both "View State Model" and "Viewable State Machine". The first definition describes how a feature in VSM is structured, the second definition illustrates how information flows.

![VSM Architecture Diagram](Sources/VSM/Documentation.docc/Resources/vsm-diagram.png))

In VSM, the **View** renders the **State**. Each state may provide a **Model**. Each model contains the data and actions available in a given state. Each action in a model returns one or more new states. Any state changes will update the view.

## Learning Resources

- The [VSM Documentation](https://wayfair.github.io/vsm-ios/documentation/vsm/) contains a complete framework reference, guides, and other learning resources
- Open the [Shopping demo](Demos/Shopping/Swift%206/Shopping.xcodeproj) (`Demos/Shopping/Swift 6`) for working examples with VSM 2.0 (`StateSequence`, `AsyncStream`, async/await)

## Code Introduction

The following are code excerpts of a feature that shows a blog entry from a data repository. **VSM 2.0** uses Swift concurrency on the state container (`StateSequence`, `AsyncStream`, or `async` closures)—not Combine. **VSM 1.x** remains the choice if you need publisher-based observation APIs. Conforming types to **`Sendable`** is optional; add it only when your types and boundaries warrant it (Swift 6.3+ encourages surgical use).

### State Definition

The state is usually defined as an enum or a struct and represents the states that the view can have. It also declares the data and actions available to the view for each model. Actions produce the next state asynchronously.

```swift
enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    case loading(errorModel: ErrorModeling?)
    case loaded(blogModel: BlogModeling)
}

protocol LoaderModeling {
    func load() async -> BlogEntryViewState
}

protocol ErrorModeling {
    var message: String { get }
    func retry() async -> BlogEntryViewState
}

protocol BlogModeling {
    var title: String { get }
    var text: String { get }
    func refresh() async -> BlogEntryViewState
}
```

### Model Definition

The discrete models provide the data for a given view state and implement the business logic within the actions.

```swift
struct LoaderModel: LoaderModeling {
    func load() async -> BlogEntryViewState {
        ...
    }
}

struct ErrorModel: ErrorModeling {
    var message: String
    func retry() async -> BlogEntryViewState {
        ...
    }
}

struct BlogModel: BlogModeling {
    var title: String
    var body: String
    func refresh() async -> BlogEntryViewState {
        ...
    }
}
```

### View Definition

The view observes and renders the state using the `ViewState` property wrapper. State changes will automatically update the view.

```swift
struct BlogEntryView: View {
    @ViewState var state: BlogEntryViewState = .initialized(LoaderModel())

    var body: some View {
        switch state {
        case .initialized(loaderModel: let loaderModel):            
            ...
            .onAppear { 
                $state.observe { await loaderModel.load() }
            }
        case .loading(errorModel: let errorModel):
            ...
        case .loaded(blogModel: let blogModel)
            ...
            Button("Reload") {
                $state.observe { await blogModel.refresh() }
            }
        }
    }
}
```

_This example uses SwiftUI, but the framework is also designed to work seamlessly with UIKit._

For more detailed tutorials and documentation, visit the [VSM Documentation](https://wayfair.github.io/vsm-ios/documentation/vsm/)

## Project Information

### Credits

VSM for Apple platforms is owned and [maintained](MAINTAINERS.md) by [Wayfair](https://www.wayfair.com/).

### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

### Security

See [SECURITY.md](SECURITY.md).

### License

VSM for Apple platforms is released under the MIT license. See [LICENSE](LICENSE) for details.
