# Building the View in VSM - UIKit

A guide to building a VSM view in UIKit

## Overview

VSM is a reactive architecture and as such is a natural fit for SwiftUI, but it also works very well with UIKit with some minor differences.  This guide is written for UIKit. The SwiftUI guide can be found here: <doc:ViewDefinition-SwiftUI>

The purpose of the "View" in VSM is to render the current view state and provide the user access to the data and actions available in that state.

In the examples found in this article, we will be using Storyboards. The code-first approach to UIKit can also be used by changing how you initialize your UIView or UIViewController.

## View Structure

The basic structure of a UIKit VSM view is as follows:

```swift
import VSM

class UserProfileViewController: UIViewController {
    @RenderedViewState var state: LoadUserProfileViewState

    required init?(state: LoadUserProfileViewState, coder: NSCoder) {
        _state = .init(wrappedValue: state, render: Self.render)
        super.init(coder: coder)
    }

    ...

    func render() {
        // View configuration goes here
    }
}
```

To turn any UIView or UIViewController into a "VSM View", define a property that holds our current state and decorate it with the `@RenderedViewState` property wrapper. `@RenderViewState` is designed for UIKit and will not work in SwiftUI. (See <doc:ViewDefinition-SwiftUI> for more information.)

**The `@RenderedViewState` property wrapper updates the view every time the state changes**. `@RenderedViewState` requires a `render` _function type_ parameter to call when the state changes. You must define this function in your UIView or UIViewController.

To kick off this automatic rendering, you must choose an appropriate UIView or UIViewController lifecycle event (`viewDidLoad`, `viewWillAppear`, etc.) and apply one of these two approaches:

#### Auto-Render - Option A

Automatic rendering will begin simply by accessing the `state` property. In VSM, it is common to begin your view's state journey by observing an action early in the view's lifecycle.

Example

```swift
func viewDidLoad() {
    super.viewDidLoad()
    if case .initialized(let loaderModel) = state {
        $state.observe(loaderModel.load())
    }
}
```

#### Auto-Render - Option B

Call `$state.startRendering(on: self)` at any point after initialization. This won't progress your state, but it will cause the automatic rendering to begin. This is most commonly used when the view's state journey is begun by some user action (e.g. tapping a button) and not a view lifecycle event.

Example

```swift
func viewDidLoad() {
    super.viewDidLoad()
    $state.startRendering(on: self)
}
```

> Warning: If you fail to implement one of the above auto-render approaches, the `render` function will never be called and the view state will be inert.

## Displaying the State

As a refresher, the following flow chart expresses the requirements that we wish to draw in the view.

![VSM User Flow Diagram Example](vsm-user-flow-example.jpg)

### Loading View

The resulting view state for the loading behavior of the flow chart (the left section of the state machine) is:

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
    let message: String
    func retry() -> AnyPublisher<LoadUserProfileViewState, Never>
}
```

In UIKit, we write a switch statement within the `render()` function to evaluate the current state and configure the views for each state.

Note that if you avoid using a `default` case in your switch statement, the compiler will enforce any future changes to the shape of your feature. This is good because it will help you avoid bugs when maintaining the feature.

The resulting `render()` function implementation takes this shape:

```swift
@IBOutlet weak var loadingView: UIActivityIndicatorView!
@IBOutlet weak var contentView: UIView!
@IBOutlet weak var errorView: UIView!
@IBOutlet weak var errorLabel: UILabel!
@IBOutlet weak var retryButton: UIButton!

func render() {
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
}

protocol EditingModeling {
    func save(username: String) -> AnyPublisher<EditUserProfileViewState, Never>
}

protocol SavingErrorModeling {
    let message: String
    func retry() -> AnyPublisher<EditUserProfileViewState, Never>
    func cancel() -> AnyPublisher<EditUserProfileViewState, Never>
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

func render() {
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

VSM's ``ViewState`` property wrapper provides a critically important function called ``StateObserving/observe(_:)-31ocs`` through its projected value (`$`). This function updates the current state with all view states emitted by an action, as they are emitted in real-time.

It is called like so:

```swift
$state.observe(someState.someAction())
```

The only way to update the current view state is to use the `RenderedViewState`'s `observe(_:)` function.

When `observe(_:)` is called, it cancels any existing Combine publisher subscriptions or Swift Concurrency tasks and ignores view state updates from any previously called actions. This prevents future view state corruption from previous actions and frees up device resources.

Actions that do not need to update the current state do not need to be called with the `observe(_:)` function. However, if you attempt to call an action that should update the current state without using `observe(_:)`, the compiler will give you the following warning:

**_Result of call to function returning 'AnyPublisher<LoadUserProfileViewState, Never>' is unused_**

This is a helpful reminder in case you forget to wrap an action call with `observe(_:)`.

> Note: The `observe(_:)` function has many overloads that provide support for several action shapes, including synchronous actions, Swift Concurrency actions, and Combine Publisher actions. For more information, see <doc:ModelActions>.

### Loading View Actions

There are two actions that we want to call in the `LoadUserProfileView`. The `load()` action in the `initialized` view state and the `retry()` action for the `loadingError` view state. We want the `load()` call to only happen once for the view's lifetime, so we'll attach it to the `viewDidAppear` delegate method. Since the retry button is created by the Storyboard, the `retry()` action will be configured on the button in a special `setUpViews()` function.

```swift
override func viewDidLoad() {
    ...  
    setUpViews()
    ...
}

override func viewDidAppear(_ animated: Bool) {
    if case .initialized(let loaderModel) = state {
        $state.observe(loaderModel.load())
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
                    strongSelf.$state.observe(errorModel.retry())
                }
            }
        ),
        for: .touchUpInside
    )
}
```

### Editing View Actions

In the editing view, there are three actions that we need to call: The `editing` view state's `save(username:)` action and the `savingError` view state's `retry()` and `cancel()` actions. We'll place these in a `setUpViews()` function and call it just like we did in the `LoadProfileViewController` as well.

```swift
func setUpViews() {
    saveButton.addAction(
        UIAction(
            title: "Save",
            handler: { [weak self] action in
                guard let strongSelf = self else { return }
                if case .editing(let editingModel) = strongSelf.state.editingState {
                    strongSelf.$state.observe(
                        editingModel.save(username: strongSelf.usernameTextField.text ?? "")
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
                    strongSelf.$state.observe(errorModel.retry())
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
                    strongSelf.$state.observe(errorModel.cancel())
                }
            }
        ),
        for: .touchUpInside
    )
}
```

You can see that based on the type-system constraints, _these actions can never be called from the wrong state_, and the feature code indicates this very clearly.

> Note: There is a special observe overload ``StateObserving/observe(_:debounced:file:line:)-8vbf2`` which includes a `debounced` property. This allows us to avoid calling an action too many times when tied to user input that may be triggered rapidly, like typing in a text field. It will only call the action a maximum of once per second (or whatever time delay is given).

## View Construction

What's the best way to construct a VSM component? Through the UIKit view or view controller's initializer. As passively enforced by the UIKit API, every feature's true API access point is the initializer of the feature's view. Required dependencies and data are passed to the initializer to initiate the feature's behavior.

A VSM view's initializer can take either of two approaches (or both, if desired):

- Dependent: The parent is responsible for passing in the view's initial view state (and its associated model)
- Encapsulated: The view encapsulates its view state kickoff point (and associated model), only requiring that the parent provide dependencies needed by the view or the models.

The "Dependent" initializer has one downside when compared to the encapsulated approach, in that it requires any parent view to have some knowledge of the inner workings of the view in question.

### Loading View Initializers

The initializers for the `LoadUserProfileViewController` are as follows:

"Dependent" Approach

```swift
// LoadUserProfileViewController Code
required init?(state: LoadUserProfileViewState, coder: NSCoder) {
    _state = .init(wrappedValue: state, render: Self.render)
    super.init(coder: coder)
}

// Parent View Code
let loaderModel = LoadUserProfileViewState.LoaderModel(userId: someUserId)
let state = .initialized(loaderModel)
LoadUserProfileViewController(state: state, coder: coder)
```

"Encapsulated" Approach

```swift
// LoadUserProfileViewController Code
required init?(userId: Int, coder: NSCoder) {
    let loaderModel = LoadUserProfileViewState.LoaderModel(userId: userId)
    let state = .initialized(loaderModel)
    _state = .init(wrappedValue: state, render: Self.render)
    super.init(coder: coder)
}

// Parent View Code
LoadUserProfileViewController(userId: someUserId, coder: coder)
```

### Editing View Initializers

The initializers for the `EditUserProfileViewController` are as follows:

"Dependent" Approach

```swift
// EditUserProfileViewController Code
init?(state: EditUserProfileViewState, coder: NSCoder) {
    _state = .init(wrappedValue: state, render: Self.render)
    super.init(coder: coder)
}

// Parent View Code
let savingModel = EditUserProfileViewState.EditingModel(userData: someUserData)
let state = EditUserProfileViewState(data: userData, editingState: .editing(savingModel))
EditUserProfileViewController(state: state, code: coder)
```

"Encapsulated" Approach

```swift
// EditUserProfileViewController Code
init?(userData: UserData, coder: NSCoder) {
    let savingModel = EditUserProfileViewState.EditingModel(userData: userData)
    let state = EditUserProfileViewState(data: userData, editingState: .editing(savingModel))
    _state = .init(wrappedValue: state, render: Self.render)
    super.init(coder: coder)
}

// Parent View Code
EditUserProfileViewController(userData: someUserData, code: coder)
```

## Synchronize View Logic

All business logic belongs in VSM models and associated repositories. However, there are cases where some logic, pertaining exclusively to view matters, is appropriately placed within the view, managed by the view, and coordinated with the view state. The few areas where this practice is acceptable are:

- Navigating between views (See <doc:Navigation>)
- Receiving/streaming user input
- Animating the view

### Comparing State Changes

VSM provides additional tools for assisting in some of this view-centric logic for UIKit views. One such tool is the ability to compare the current view state against the future view state when rendering. To do this, simply add a view state parameter to the `render(...)` function. By adding a view state property to the render function, VSM will call the render function on the `state` property's `willSet` event instead of the `didSet` event.

Example

```swift
func render(_ newState: MyViewState) {
    if state.saveProgress < newState.saveProgress) {
        animateSaveProgress(from: state.saveProgress, to: newState.saveProgress)
    }
}
```

In the above example, the `state` view property still contains the previous view state value, while the parameter passed into the `render(_ newState: MyViewState)` function contains the new view state _just before the `state` property is changed to the new value_. This allows you to perform any logic or operations that require a comparison of the current and future states.

### Will-Set / Did-Set Publishers

The ``RenderedViewState/RenderedContainer/willSetPublisher`` and ``RenderedViewState/RenderedContainer/didSetPublisher`` publishers provide another tool for supporting view-centric logic. These publishers can be used to observe and respond to changes in view state as desired. These publishers are guaranteed to send the new value on the main thread.

Example

```swift
class MyViewController: UIViewController {
    @RenderedViewState var state: MyViewState
    private var stateSubscriptions: Set<AnyCancellable> = []
    ...
    override func viewDidLoad() {
        super.viewDidLoad()
        $state.willSetPublisher
            .sink { newState in
                print(">>> will set: \(newState)"
            }
            .store(in: &stateSubscriptions)
        $state.didSetPublisher
            .sink { newState in
                print(">>> did set: \(newState)"
            }
            .store(in: &stateSubscriptions)
    }
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
