# Building the View in VSM - UIKit

A guide to building a VSM view in SwiftUI or UIKit

## Overview

VSM is a reactive architecture and as such is a natural fit for SwiftUI, but it also works very well with UIKit with some minor differences.  This guide is written for UIKit. The SwiftUI guide can be found here: <doc:ViewDefinition-SwiftUI>

The purpose of the "View" in VSM is to render the current view state and provide the user access to the data and actions available in that state.

## View Structure

The basic structure of a UIKit VSM view is as follows:

```swift
import VSM

class UserProfileViewController: UIViewController, ViewStateRendering {
    var container: StateContainer<LoadUserProfileViewState>
    var stateSubscription: AnyCancellable?

    required init?(state: LoadUserProfileViewState, coder: NSCoder) {
        container = .init(state: state)
        super.init(coder: coder)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        stateSubscription = container.$state
            .sink { [weak self] newState in
                self?.render(newState)
            }
        super.viewDidLoad()
    }

    func render(state: VSMBasicExampleViewState) {
        // View configuration goes here
    }
}
```

We are required by the ``ViewStateRendering`` protocol to define a ``StateContainer`` property and specify what the view state's type will be. In these examples, we will use the `LoadUserProfileViewState` and `EditUserProfileViewState` types from <doc:StateDefinition> to build two related VSM views.

> Note: In the examples found in this article, we will be using Storyboards. As a result, you can see that we used a custom `NSCoder` initializer above. If you are using a code-first approach to UIKit, you can use whichever initialization mechanism is most appropriate.

In UIKit, we have to manually `sink` the state changes to a `render(state:)` function. This render function will be called any time the state changes and can be used to create, destroy, or configure views or components within the view controller. Make sure your reference to `self` is weak. Make sure that you subscribe to the state publisher after the view has been created (in `viewDidLoad()` or later) because the render function will be fired immediately and will crash if the `UIViewController`'s `view` property is not yet initialized.

## Displaying the State

The ``ViewStateRendering`` protocol provides a few properties and functions that help with displaying the current state, accessing the state data, and invoking actions.

The first of these members is the ``ViewStateRendering/state`` property, which reflects the current state of the view.

> Important: In UIKit, the ``StateContainer/state`` publisher will call `render(state:)` on the state's `willChange` event. Therefore, any evaluations of `self.state` will give you the previous state's value. If you want the current state, use the state parameter that is passed into the render function.

As a refresher, the following flow chart expresses the requirements that we wish to draw in the view.

![VSM User Flow Diagram Example](vsm-user-flow-example.jpg)

### Loading View

The resulting view state for the loading behavior of the flow chart (the left section of the state machine) is:

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

In UIKit, we simply write a switch statement within the `render(state:)` function to evaluate the current state and configure the views for each state.

Note that if you avoid using a `default` case in your switch statement, the compiler will enforce any future changes to the shape of your feature. This is good because it will help you avoid bugs when maintaining the feature.

The resulting `render(state:)` function implementation takes this shape:

```swift
@IBOutlet weak var loadingView: UIActivityIndicatorView!
@IBOutlet weak var contentView: UIView!
@IBOutlet weak var errorView: UIView!
@IBOutlet weak var errorLabel: UILabel!
@IBOutlet weak var retryButton: UIButton!

func render(_ state: LoadUserProfileViewState) {
    switch state {
    case .initialized, .loading:
        errorView.isHidden = true
        loadingView.isHidden = false
        if !loadingView.isAnimating {
            loadingView.startAnimating()
        }
    case .loadingError(let errorModel):
        errorView.isHidden = false
        errorLabel.text = errorModel.message
    case .loaded(let userData):
        errorView.isHidden = true
        loadingView.stopAnimating()
        loadingView.isHidden = true
        let editProfileViewController = UIStoryboard(name: "Main", bundle: nil)
            .instantiateViewController(
                identifier: "EditUserProfileViewController",
                creator: { coder in
                    EditUserProfileViewController(userData: userData, coder: coder)
                })
        editProfileViewController.willMove(toParent: self)
        
        editProfileViewController.view.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(editProfileViewController.view)
        NSLayoutConstraint.activate([
            editProfileViewController.view.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            editProfileViewController.view.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            editProfileViewController.view.widthAnchor.constraint(equalTo: contentView.widthAnchor),
            editProfileViewController.view.heightAnchor.constraint(equalTo: contentView.heightAnchor)
        ])
        addChild(editProfileViewController)
        
        editProfileViewController.didMove(toParent: self)
    }
}
```

Unlike SwiftUI, UIKit views persist in memory. Instead of rebuilding the views for each state, we created these views once in the Storyboard and connected them to the view controller via `@IBOutlet`s.

You can see above that we configured all the views for each state, ensuring that we covered every case by resetting the visibility of other views, even if those views are unrelated to the current state.

The `initialized` and `loading` case hides all other views before showing the loading view. Then, if the loading view isn't already animating, the animation is started.

The `loadingError` case shows the error view on top of all of the content and sets the error label appropriately.

The `loaded` state, however, does build and configure a new view because it will only ever be called once and it needs to pass data into the editing view which requires `UserData` for initialization. The loaded state also stops and hides the loading indicator and the error view (if previously shown).

> Note: If a new view _must_ be repeatedly rebuilt due to state changes, be sure to properly clear the previous views, like so:

```swift
contentView.subviews.forEach { $0.removeFromSuperview() }
children.forEach { child in
    child.willMove(toParent: nil)
    child.removeFromParent()
    child.didMove(toParent: nil)
}
```

### Editing View

If we go back up to the feature's flow chart and translate the editing behavior (the right section of the state machine) to a view state, we come up with the following view state:

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

The following code renders each of the states for `EditUserProfileViewState` by configuring the corresponding views:

```swift
@IBOutlet weak var usernameTextField: UITextField!
@IBOutlet weak var saveButton: UIButton!
@IBOutlet weak var loadingView: UIActivityIndicatorView!
@IBOutlet weak var errorView: UIView!
@IBOutlet weak var errorLabel: UILabel!
@IBOutlet weak var retryButton: UIButton!
@IBOutlet weak var cancelButton: UIButton!

func render(_ state: EditUserProfileViewState) {
    switch state.editingState {
    case .editing:
        errorView.isHidden = true
        loadingView.stopAnimating()
        loadingView.isHidden = true
        usernameTextField.text = state.data.username
    case .saving:
        errorView.isHidden = true
        loadingView.isHidden = false
        loadingView.startAnimating()
    case .savingError(let errorModel):
        errorView.isHidden = false
        errorLabel.text = errorModel.message
    }
}
```

As in our first example, you can see that the various views are connected to the Storyboard via `@IBOutlet`s and are configured in each state.

## Calling the Actions

Now that we have our view states rendering correctly, we need to wire up the various actions in our views so that they are appropriately and safely invoked by the environment or the user.

VSM's ``ViewStateRendering`` protocol provides a critically important function called ``ViewStateRendering/observe(_:)-7vht3``. This function updates the current state with all view states emitted by the action parameter, as they are emitted in real-time.

It is called like so:

```swift
observe(someState.someAction())
// or
observe(someState.someAction)
```

The only way to update the current view state is to use the `observe(_:)` function.

When `observe(_:)` is called, it cancels any existing Combine publisher subscriptions or Swift Concurrency tasks and ignores view state updates from any previously called actions. This prevents future view state corruption from previous actions and frees up device resources.

Actions that do not need to update the current state do not need to be called with the `observe(_:)` function. However, if you attempt to call an action that should update the current state without using `observe(_:)`, the compiler will give you the following warning:

**_Result of call to function returning 'AnyPublisher<LoadUserProfileViewState, Never>' is unused_**

This is a helpful reminder in case you forget to wrap an action call with `observe(_:)`.

> Note: The `observe(_:)` function has many overloads that provide support for several action shapes, including synchronous actions, Swift Concurrency actions, and Combine Publisher actions. For more information, see <doc:ModelActions>.

### Loading View Actions

There are two actions that we want to configure in the `LoadUserProfileView`. The `load()` action in the `initialized` view state and the `retry()` action for the `loadingError` view state. We want the `load()` call to only happen once for the view's lifetime, so we'll attach it to the `viewDidAppear` delegate method. Since the retry button is created by the Storyboard, the `retry()` action will be configured on the button in a special `setUpViews()` function.

```swift
override func viewDidLoad() {
    // ...   
    setUpViews()
    // ...
}

override func viewDidAppear(_ animated: Bool) {
    if case .initialized(let loaderModel) = state {
        observe(loaderModel.load())
    }
    super.viewDidAppear(animated)
}

func setUpViews() {
    retryButton.addAction(
        UIAction(
            title: "Retry",
            handler: { [weak self] action in
                guard let strongSelf = self else { return }
                if case .loadingError(let errorModel) = strongSelf.state {
                    strongSelf.observe(errorModel.retry())
                }
            }
        ),
        for: .touchUpInside
    )
}
```

### Editing View Actions

In the editing view, there are three actions that we need to call: The `editing` view state's `saveUsername()` action and the `savingError` view state's `retry()` and `cancel()` actions. We'll place these in a `setUpViews()` function and call it just like we did in the `LoadProfileViewController` as well.

```swift
func setUpViews() {
    saveButton.addAction(
        UIAction(
            title: "Save",
            handler: { [weak self] action in
                guard let strongSelf = self else { return }
                if case .editing(let editingModel) = strongSelf.state.editingState {
                    strongSelf.observe(
                        editingModel.saveUsername(strongSelf.usernameTextField.text ?? "")
                    )
                }
            }
        ),
        for: .touchUpInside
    )
    
    retryButton.addAction(
        UIAction(
            title: "Retry",
            handler: { [weak self] action in
                guard let strongSelf = self else { return }
                if case .savingError(let errorModel) = strongSelf.state.editingState {
                    strongSelf.observe(errorModel.retry())
                }
            }
        ),
        for: .touchUpInside
    )
    
    cancelButton.addAction(
        UIAction(
            title: "Cancel",
            handler: { [weak self] action in
                guard let strongSelf = self else { return }
                if case .savingError(let errorModel) = strongSelf.state.editingState {
                    strongSelf.observe(errorModel.cancel())
                }
            }
        ),
        for: .touchUpInside
    )
}
```

You can see that based on the type-system constraints, _these actions can never be called from the wrong state_, and the feature code indicates this very clearly.

> Note: There is a special observe overload ``ViewStateRendering/observe(_:debounced:file:line:)-7ihyy`` which includes a `debounced` property. This allows us to avoid calling an action too many times when tied to user input that may be triggered rapidly, like typing in a text field. It will only call the action a maximum of once per second (or whatever time delay is given).

## View Construction

What's the best way to construct a VSM component? Through the UIKit view or view controller's initializer. As passively enforced by the UIKit API, every feature's true API access point is the initializer of the feature's view. Required dependencies and data are passed to the initializer to initiate the feature's behavior.

A VSM view's initializer can take either of two approaches (or both, if desired):

- Subservient: The parent is responsible for passing in the view's initial view state (and its associated model)
- Encapsulated: The view encapsulates its view state kickoff point (and associated model), only requiring that the parent provide dependencies needed by the view or the models.

The subservient initializer has one downside when compared to the encapsulated approach, in that it requires any parent view to have some knowledge of the inner workings of the view in question.

### Loading View Initializers

The initializers for the `LoadUserProfileViewController` are as follows:

```swift
// Subservient
required init?(state: LoadUserProfileViewState, coder: NSCoder) {
    container = .init(state: state)
    super.init(coder: coder)
}

// Encapsulated
required init?(state: LoadUserProfileViewState, coder: NSCoder) {
    let loaderModel = LoadUserProfileViewState.LoaderModel(userId: 1)
    let state = .initialized(loaderModel)
    container = .init(state: state)
    super.init(coder: coder)
}
```

### Editing View Initializers

The initializers for the `EditUserProfileViewController` are as follows:

```swift
// Subservient
init?(state: EditUserProfileViewState, coder: NSCoder) {
    container = .init(state: state)
    super.init(coder: coder)
}

// Encapsulated
init?(userData: UserData, coder: NSCoder) {
    let savingModel = EditUserProfileViewState.EditingModel(userData: userData)
    let state = EditUserProfileViewState(data: userData, editingState: .editing(savingModel))
    container = .init(state: state)
    super.init(coder: coder)
}
```

## Iterative View Development

The best approach to building features in VSM is to start with defining the view state, then move straight to building the view. Rely on mocked states and example/demo apps where possible to visualize each state. Postpone implementing the feature's business logic for as long as possible until you are confident that you have the right feature shape and view code.

The reason for recommending this approach to VSM development is that VSM implementations are tightly coupled with and enforced by the feature shape (via the type system and compiler). By defining the view state and view code, it gives you time to explore the edge cases of the feature without having to significantly refactor the models and business logic.

## Up Next

### Building the Models

Now that we have discovered how to build views, and we have built each view and previewed all the states using mocks, we can start implementing the business logic in the models in <doc:ModelDefinition>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
