# Communicating Between Views

A quick guide on how to facilitate communication between Views in VSM

## Overview

There are many different ways and reasons to communicate data and events between views. This is an ever-present need. VSM breaks these view communication needs into three categories: View Communication, Feature Communication, and Data Communication.

## View Communication

The view communication category encapsulates all concerns that directly involve the view and its direct sibling views. These concerns include:

- Animation states and information (i.e., `isAnimating`, `delay: 0.25`, etc.)
- Navigation states and information (i.e., `isPresenting` or `presentedData: Binding<SomeData>`)
- User input states and information (i.e., `TextField("Username", text: user.$username`)
- View events and information (i.e., `onAppear` behavior, etc.)

### SwiftUI

In the above situations, SwiftUI views should communicate with each other using `@State` or `@Binding` properties which are passed along to each other through each view's initializers. These data points should refrain from being passed too far from the source view. If you find yourself needing to share the same `@Binding` across many views, consider using the approach found in <doc:ViewCommunication#Data-Communication> instead.

For example, if you have a presented modal that needs to be able to close itself, you would write:

```swift
struct ProfileView: View {
    ...
    @State var changePasswordIsPresented = false
    
    var body: some View {
        HStack {
            ...
        }
        .fullscreenCover(isPresented: $changePasswordIsPresented) {
            ChangePasswordView(isPresented: $changePasswordIsPresented)
        }
    }
}

struct ChangePasswordView: View {
    ...
    @Binding var isPresented: Bool

    var body: some View {
        ...
        Button("Close") {
            isPresented = false
        }
    }    
}
```

### UIKit

In UIKit, data binding behavior is not as easily accessible as it is in SwiftUI. That being said, the UIKit APIs are a little more flexible in that the above example wouldn't require anything be passed between the views in question because each view can get at the state of the view hierarchy and act directly upon it.

However, there may be instances where `UIViews` and `UIViewControllers` should be able to communicate bidirectionally. This can be done by passing closures between the views. It is critical to ensure that `self` is captured weakly in any circular reference patterns involving closures.

One example of this would be if a `UITabBarController` needed to be notified when the first of its children appeared so that it could then trigger a modal to display.

```swift
final class TabBarController: UITabBarController {
    ...
    func viewDidLoad() {
        super.viewDidLoad()

        let tabViewController = TabViewController(onTabAppeared: { [weak self] in
            self?.present(SignInViewController(), animated: true, completion: nil)
        })

        viewControllers = [
            tabViewController
        ]
    }
}

final class TabViewController: UIViewController {
    ...
    private let onTabAppeared: () -> Void

    init(onTabAppeared: @escaping () -> Void) {
        self.onTabAppeared = onTabAppeared
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        onTabAppeared()
    }
}
```

In this example, the `TabViewController` accepts a closure on initialization which it calls when its `viewDidAppear` function is invoked. The `TabBarController` provides that closure and is able to react to the event by showing the `SignInViewController`. While this example may be a little contrived, it shows how views can communicate various view concerns with each other in UIKit.

## Feature Communication

Another type of communication between VSM views is when a feature needs to communicate some sort of information, state, or dependencies to another VSM feature directly. This is simply done by passing the static data directly into the view's initializer. The only acceptable kinds of data for this type of communication is static, immutable data. This is most commonly the data required to prime the feature for operation.

When one feature launches a child feature, it is also responsible for forwarding any dependencies that child feature requires. A clean way to handle this is for the parent feature's `Dependencies` type to compose the child's `Dependencies` as a nested property, so that all required dependencies flow from a single root object. The parent then passes the appropriate subset along when transitioning to the loaded state.

For example, if we have a feature that loads the user info required by the user profile editor view, we can express that like so:

### SwiftUI

```swift
struct LoadUserView: View {
    @ViewState var state: LoadUserViewState
    let dependencies: LoadUserViewState.Dependencies

    init(dependencies: LoadUserViewState.Dependencies) {
        self.dependencies = dependencies
        _state = .init(wrappedValue: .initialized(.init(dependencies: dependencies)))
    }

    var body: some View {
        HStack {
            switch state {
            case .initialized, .loading:
                ...
            case .loadingError(let errorModel):
                ...
            case .loaded(let userData):
                // The parent forwards the child's dependency subset,
                // which it already owns as part of its own Dependencies type.
                EditUserProfileView(
                    userData: userData,
                    dependencies: dependencies.editUserProfile
                )
            }
        }
    }
}
```

In this example, `LoadUserViewState.Dependencies` composes `EditUserProfileView`'s dependencies as a nested property (`editUserProfile`). This keeps the dependency graph explicit and traceable from the root of the feature tree.

### UIKit

**iOS 18+ (using @ViewState):**

```swift
final class LoadUserViewController: UIViewController {
    @ViewState var state: LoadUserViewState
    let dependencies: LoadUserViewState.Dependencies

    init(dependencies: LoadUserViewState.Dependencies) {
        self.dependencies = dependencies
        _state = .init(wrappedValue: .initialized(.init(dependencies: dependencies)))
        super.init(nibName: nil, bundle: nil)
    }

    override func updateProperties() {
        super.updateProperties()

        switch state {
        case .initialized, .loading:
            ...
        case .loadingError(let errorModel):
            ...
        case .loaded(let userData):
            // The parent forwards the child's dependency subset,
            // which it already owns as part of its own Dependencies type.
            let editProfileViewController = EditProfileViewController(
                userData: userData,
                dependencies: dependencies.editUserProfile
            )
            contentView.addSubview(editProfileViewController.view)
            addChild(editProfileViewController)
            ...
        }
    }
}
```

> Note: For iOS 17, use `@RenderedViewState(render: Self.render)` and replace `updateProperties()` with `render()`, removing the `super.updateProperties()` call. See <doc:ViewDefinition-UIKit> for full details.

## Data Communication

This category encompasses the majority of the feature communication scenarios. Any communication between views that does not belong in <doc:ViewCommunication#View-Communication> or <doc:ViewCommunication#Feature-Communication> falls into this final category.

The approach for handling this type of communication is simple. Instead of trying to communicate _through_ the views, you should instead share observable repositories between the views in question. This way each corresponding VSM feature has access to the same data and can be configured to update the view or run processes when the state of that shared data changes.

These repositories can have actions that can modify or refresh the shared data, which will automatically notify the interested VSM features without having to explicitly communicate between views. These repositories can also be interdependent by configuring the repositories to observe each other and trigger any behaviors necessary as a result of a change in a repository's state or data.

For more information on how to build shared, reactive, observable data repositories, see <doc:DataDefinition>.
