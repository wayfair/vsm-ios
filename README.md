[![Release](https://img.shields.io/github/v/release/wayfair/vsm-ios?display_name=tag)](CHANGELOG.md)
[![Lint](https://github.com/wayfair/vsm-ios/actions/workflows/lint.yml/badge.svg?branch=main)](https://github.com/wayfair/vsm-ios/actions/workflows/lint.yml)
[![CI](https://github.com/wayfair/vsm-ios/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/wayfair/vsm-ios/actions/workflows/ci.yml)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.0-4baaaa.svg)](CODE_OF_CONDUCT.md)
[![Maintainer](https://img.shields.io/badge/Maintainer-Wayfair-7F187F)](https://wayfair.github.io)

# VSM for Apple Platforms

VSM is a reactive architecture that is unidirectional, highly type-safe, behavior-driven, and clean. This open-source swift package framework allows for easily building features in VSM on all publicly available Apple platforms: iOS, iPadOS, macOS, tvOS, visionOS, watchOS

## Overview

VSM stands for both "View State Model" and "Viewable State Machine". The first definition describes how a feature in VSM is structured, the second definition illustrates how information flows.

![VSM Architecture Diagram](Sources/VSM/Documentation.docc/Resources/vsm-diagram.png))

In VSM, the **View** renders the **State**. Each state may provide a **Model**. Each model contains the data and actions available in a given state. Each action in a model returns one or more new states. Any state changes will update the view.

## Learning Resources

- The [VSM Documentation](https://wayfair.github.io/vsm-ios/documentation/vsm/) contains a complete framework reference, guides, and other learning resources
- Open the [Demo App](Demos/Shopping) to see many different working examples of how to build features using the VSM pattern

## Brief Introduction

The following are code excerpts of a feature that shows a blog entry from a data repository.

### State Definition

The state is usually defined as an enum or a struct and represents the states that the view can have. Each state contains a model that provides the data and actions to the view.

```swift
enum BlogEntryViewState {
    case initialized(loaderModel: LoaderModeling)
    case loading(errorModel: ErrorModeling?)
    case loaded(blogModel: BlogModeling)
}
```

### Model Definition

The discrete models provide the data for a given view state and implement the business logic within the actions. Actions return one or more new states.

```swift
struct LoaderModel {
    func load() -> some Publisher<BlogArticleViewState, Never> {
        ...
    }
}

struct ErrorModel {
    var message: String
    func retry() -> some Publisher<BlogArticleViewState, Never> {
        ...
    }
}

struct BlogModel {
    var title: String
    var body: String
    func refresh() -> some Publisher<BlogArticleViewState, Never> {
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
                $state.observe(loaderModel.load())
            }
        case .loading(errorModel: let errorModel):
            ...
        case .loaded(blogModel: let blogModel)
            ...
            Button("Reload") {
                $state.observe(blogModel.refresh())
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
