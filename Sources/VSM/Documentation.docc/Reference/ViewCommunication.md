# Communicating Between Views - VSM Reference

A quick guide on how to facilitate communication between views

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
struct ProfileView: View, ViewStateRendering {
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

struct ChangePasswordView: View, ViewStateRendering {
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

However, there may be instances where `UIViews` and `UIViewControllers` should be able to communicate bidirectionally. This can be done by passing closures between the views, or by creating publishers on the views that emit changes in view state, events, or view-specific information. It is critical to ensure that `self` is captured weakly in any circular reference patterns, such as with closures or publisher `sink` calls.

One example of this would be if a `UITabBarController` needed to be notified when the first of its children appeared so that it could then trigger a modal to display.

```swift
final class TabBarController: UITabBarController, ViewStateRendering {
    ...
    var subscriptions: Set<AnyCancellable> = []

    func viewDidLoad() {
        super.viewDidLoad()

        let tabViewController = TabViewController()

        tabViewController.eventPublisher
            .filter { event in event == TabViewEvent.tabAppeared }
            .sink { [weak self] _ in
                self?.present(SignInViewController(), animated: true, completion: nil)
            }
            .store(in: &subscriptions)

        viewControllers = [
            tabViewController
        ]
    }
}

final class TabViewController: UIViewController, ViewStateRendering {
    ...
    private var eventSubject = PassthroughSubject<TabViewEvent, Never>()
    var eventPublisher: AnyPublisher<TabViewEvent, Never> { eventSubject.eraseToAnyPublisher() }

    var viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        eventSubject.send(TabViewEvent.tabAppeared)
    }
}
```

In this example, the `TabViewController` exposes an event publisher which notifies any subscribers when its `viewDidAppear` function is called. The `TabBarController` observes this publisher and is able to react to its `.tabAppeared` event by showing the `SignInViewController`. While this example may be a little contrived, it shows how views can communicate various view concerns with each other in UIKit.

## Feature Communication

Another type of communication between VSM views is when a feature needs to communicate some sort of information, state, or dependencies to another VSM feature directly. This is simply done by passing the static data directly into the view's initializer. The only acceptable kinds of data for this type of communication is static, immutable data. This is most commonly the data required to prime the feature for operation.

For example, if we have a feature that loads the user info that is required by the user profile editor view, we can express that like so:

### SwiftUI

```swift
struct LoadUserView: View, ViewStateRendering {
    ...
    let dependencies: Dependencies

    var body: some View {
        HStack {
            switch state {
            case .initialized, .loading:
                ...
            case .loadingError(let errorModel):
                ...
            case .loaded(let userData):
                EditUserProfileView(dependencies: dependencies, userData: userData)
            }
        }
    }
}
```

### UIKit

```swift
final class LoadUserViewController: UIViewController, ViewStateRendering {
    ...
    let dependencies: Dependencies

    func render(_ state: LoadUserProfileViewState) {
        switch state {
        case .initialized, .loading:
            ...
        case .loadingError(let errorModel):
            ...
        case .loaded(let userData):
            let editProfileViewController = EditProfileViewController(
                dependencies: dependencies,
                userData: userData
            )
            contentView.addSubview(editProfileViewController.view)
            addChild(editProfileViewController)
            ...
        }
    }
}
```

## Data Communication

This category encompasses the majority of the feature communication scenarios. Any communication between views that does not belong in <doc:ViewCommunication#View-Communication> or <doc:ViewCommunication#Feature-Communication> falls into the this final category.

The approach for handling this type of communication is simple. Instead of trying to communicate _through_ the views, you should instead share observable repositories between the views in question. This way each corresponding VSM feature has access to the same data and can be configured to update the view or run processes when the state of that shared data changes.

These repositories can have actions that can modify or refresh the shared data, which will automatically notify the interested VSM features without having to explicitly communicate between views. These repositories can also be interdependent by configuring the repositories to observe each other and trigger any behaviors necessary as a result of a change in a repository's state or data.

For more information on how to build shared, reactive, observable data repositories, see <doc:DataDefinition>.
