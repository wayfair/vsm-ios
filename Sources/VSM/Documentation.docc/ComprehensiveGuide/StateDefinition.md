# Building the State in VSM

A guide to translating feature requirements into VSM code

## Overview

Often, engineers begin developing features without fully understanding the feature requirements. This approach is responsible for many bugs. The VSM architecture encourages a more careful examination of requirements before implementing them.

## The Status Quo

It is very common for engineers to do the following when implementing a new feature:

1. Skim the requirements and designs in the ticket
1. Implement a little bit of the view and the business logic
1. Run the app to see if that bit worked
1. Repeat until the engineer thinks they are done with all of the requirements

With this approach, the overall technical design of the feature's implementation suffers due to the lack of forethought that goes into translating the feature requirements as a whole into a good implementation in code. More importantly, this approach is responsible for many bugs that result from not understanding the entirety of the requirements before coding the feature. A good manual QA process may help shorten this gap, but gaining a better understanding of requirements before building the feature is the safest bet.

## Behavior-Driven Architecture

VSM aims to break the above tradition by encouraging engineers to describe the feature's requirements in code before writing any implementation code (view or model). Of course, the engineer can't do this without carefully studying the feature's requirements and asking questions that clarify any ambiguity.

VSM encourages **Behavior-driven Development** by requiring that every feature declare a View State type before implementing the view or business logic code. This View State describes all the states the view can have and the data and actions associated with each state. We accomplish this by using a mix of core Swift types (enums and structs) to describe the requirements.

The following example defines the view state for a VSM feature that allows users to view, change, and save their usernames.

```swift
enum UserProfileViewState {
    case loaded(LoadedModeling)
    case saving(SavingModeling)
}

protocol LoadedModeling {
    let username: String
    func saveUsername(_ username: String) -> AnyPublisher<UserProfileViewState, Never>
}

protocol SavingModeling {
    let originalUsername: String
    let newUsername: String
    func cancel() -> AnyPublisher<UserProfileViewState, Never>
}
```

In VSM, the view can only see and draw the current view state.

In the code above, the compiler prohibits the view from calling the cancel function if the user is in the `loaded` state. Conversely, the compiler prohibits the view from reaching the `saveUsername` function if the user is in the `saving` state. The same goes for the properties. For example, the view will not be able to access the `newUsername` property if the user is in the `loaded` state.

To reiterate:

> Important: The "loaded" and "saving" states have separate models with unique data and actions each. The view can only access the model of the current state

## Defining States and Models

Translating requirements into abstract types in code can be a bit challenging at first. By using the right process, it can quickly become second nature.

### Extracting the Concepts from the Feature Requirements

The best way to build features in VSM is to carefully read the requirements and translate those requirements into a flow chart. While this step is not required, it will help you more easily identify the states, data, and actions that a feature needs.

Consider the following requirements.

```gherkin
Feature: Load and Edit User Profile
Scenario: User navigates to the User Profile Editor
  Given I am logged in
  When I tap "Edit Profile"
  Then I should see the Loading Screen
  Then I should see the Editing Screen
Scenario: User Navigates to the User Profile Editor Without Internet
  Given I am logged in
  And I am not connected to the internet
  When I tap "Edit Profile"
  Then I should see the Loading Screen
  Then I should see the Error Screen
  When I reconnect to the internet
  And I tap "Retry"
  Then I should see the Loading Screen
  Then I should see the Editing Screen
Scenario: User Saves Username
  Given I am logged in
  And I tapped "Edit Profile"
  When I change my Display Name
  And I tap "Save"
  Then I should see the Saving Screen
  Then I should see the Editing Screen
  And I should see the new Display Name
Scenario: User Saves Username Without Internet
  Given I am logged in
  And I tapped "Edit Profile"
  When I change my Display Name
  And I lose connection to the internet
  And I tap "Save"
  Then I should see the Saving Screen
  Then I should see the Error Screen
  When I reconnect to the internet
  And I tap "Retry"
  Then I should see the Saving Screen
  Then I should see the Editing Screen
  And I should see the new Display Name
```

After careful study, you may produce a flow chart that looks something like this:

![VSM User Flow Diagram Example](vsm-user-flow-example.jpg)

### Converting Flow Diagrams to Enums and Structs

With the above diagram, it becomes much easier to infer which states, data, and actions should exist for this feature.

#### Determining the States

States usually match up 1:1 with variations in the view. So, we can safely assume that we will need the following states: loading, loading-error, editing, saving, and saving-error.

> Note: We will need to add an extra state called "initialized" to kick off the `load()` action when the view appears. `load()` will immediately return the `loading` state. This protects the `load()` action from accidentally being called from the wrong state.
>
> For example, in SwiftUI, a view’s `onAppear` handler (`viewDidAppear` in UIKit) can be called multiple times during a view’s lifetime. The "initialized" state will prevent the `load()` function from being called multiple times even if `onAppear` is called numerous times even before the data finishes loading.
>
> ```swift
> someView.onAppear {
>     if case .initialized(let loadingModel) = state {
>         observe(loadingModel.load())
>     }
> }
> ```
>
> **This approach to protecting actions by state will guarantee that scenarios like these will never produce unexpected results.**

The resulting state flow diagram may look something like this:

![VSM State Flow Diagram Example](vsm-state-flow-example.jpg)

If we translate the states from the above flow chart, our resulting view state enum looks like this:

```swift
enum UserProfileViewState {
    case initialized  // This is our default state when constructing the view
    case loading      // Represents the Loading View
    case loadingError // Represents the Loading Error View
    case editing      // Represents the Editing View
    case saving       // Represents the Saving View
    case savingError  // Represents the Saving Error View
}
```

#### Defining the Models

Now that we have our states, we can define the models for each state with their associated data and actions. As you can see from the above chart, the "initialized" state will need a `load()` action. So, we will define our model with a simple protocol like so:

```swift
protocol LoaderModeling {
    func load() -> AnyPublisher<UserProfileViewState, Never>
}
```

We want the `load()` function to emit two states. First, the "loading" state while the user data loads, then the "editing" state when the loading is complete. To allow this, we use a Combine Publisher that can send multiple `UserProfileViewState` values to the view.

The Publisher returned from `load()` uses the `Never` error type. The compiler then requires the engineer to implement proper error handling by converting any `Error` type into a `UserProfileViewState` type. For example, the code above infers that `load()` will return the `loadingError` state if it encounters any errors.

To learn more about VSM's supported action types, see <doc:ModelActions>.

Next, we'll define the model for the "editing" state. As per the diagram, this state will need the loaded user data and the "save" action.

```swift
protocol EditingModeling {
    var data: UserData
    func saveUsername(_ username: String) -> AnyPublisher<UserProfileViewState, Never>
}
```

The unique thing about this model from the previous example is that the `saveUsername` function expects a String parameter representing the new username. The view code will pass the text from the Username field to this function.

Finally, we'll use the same approach to build error models for the `loadingError` and `savingError` states. These models will need to provide an error message String and a `retry()` action for the user to press in case of an error. For the `savingError`, an additional user data property is needed for the view to display along with the error. The `savingError` model will also have a `cancel()` action that will allow the user to go back to editing.

```swift
protocol LoadingErrorModeling {
    let message: String
    func retry() -> AnyPublisher<UserProfileViewState, Never>
}

protocol SavingErrorModeling {
    let data: UserData
    let message: String
    func retry() -> AnyPublisher<UserProfileViewState, Never>
    func cancel() -> AnyPublisher<UserProfileViewState, Never>
}
```

#### States Without Models

Some states do not require models.

For example, the `loading` state has no data to show, nor any actions to call. We will not provide a model for that state, as it will be managed by the `LoaderModel`.

```swift
case loading
```

The saving state _does_ have some associated data, but no actions. Instead of creating a custom model for it, we can use the currently loaded user data. The `EditingModel`'s `saveDisplayName()` action can manage the flow of the saving state.

```swift
case saving(UserData)
```

## The "Shape" of the Feature

If we put all of this together, the resulting VSM feature definition is as follows. This can be referred to as the "Shape of the Feature".

```swift
enum UserProfileViewState {
    case initialized(LoaderModeling)
    case loading
    case loadingError(LoadingErrorModeling)
    case editing(EditingModeling)
    case saving(UserData)
    case savingError(SavingErrorModeling)
}

protocol LoaderModeling {
    func load() -> AnyPublisher<UserProfileViewState, Never>
}

protocol LoadingErrorModeling {
    let message: String
    func retry() -> AnyPublisher<UserProfileViewState, Never>
}

protocol EditingModeling {
    var data: UserData
    func saveUsername(_ username: String) -> AnyPublisher<UserProfileViewState, Never>
}

protocol SavingErrorModeling {
    let data: UserData
    let message: String
    func retry() -> AnyPublisher<UserProfileViewState, Never>
    func cancel() -> AnyPublisher<UserProfileViewState, Never>
}
```

As you can see from the above code, we now have a clear and straightforward picture of how the feature works and what the View can see and do in any given state.

In contrast, many other architectures will tell you, "Put all of X in 'this' bucket, and all of Y in 'that' bucket." However, with VSM, the "Shape of the Feature" is entirely up to you and provides unprecedented type safety for the entire feature. You'll find that as you implement features in VSM, the compiler will protect the business logic based on the above definition.

You have absolute creative freedom in how the feature requirements are modeled into Swift, as long as you follow some basic guidelines:

1. The ViewState contains your entire feature shape
1. All actions that directly update the View must return one or more of these ViewState values
1. Data and actions are not accessible outside of their intended states

### Simple Feature Shapes

While the above feature shape is a good design, it is a somewhat complex example for VSM. There is an opportunity to simplify it further by separating some concerns across multiple smaller VSM components. To do this, look for a way to cleanly break the state into smaller, less complex type graphs. It also helps to consider how the View will use this feature shape and optimize for efficiency without sacrificing safety where possible.

The user data load only happens once for the entire lifecycle of this feature. Therefore, we can split off the `initialized`, `loading`, and `loadingError` states to a parent view. Once loaded, the parent view can show the Editing View as its child, passing the `UserData` to it upon construction. If we follow this approach, we end up with two separate but related VSM components, each with its states, data, and actions.

As described above, the parent VSM component will have the following view state definition:

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

In the above example, we extract the states that manage the loading of `UserData` into a separate view state. Instead of providing a model for the `loaded` state, we provide only the raw `UserData` value that can be used by the Loader View to hydrate the Editing View, as defined below:

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
    func saveUsername(_ username: String) -> AnyPublisher<EditUserProfileViewState, Never>
}

protocol SavingErrorModeling {
    let message: String
    func retry() -> AnyPublisher<EditUserProfileViewState, Never>
    func cancel() -> AnyPublisher<EditUserProfileViewState, Never>
}
```

Here, we moved the editing functionality into a separate view state. The shape of this view state is different than the examples found earlier in this article. We chose a struct as the primary Swift type for our view state because the user data should be available to the Editing View in _every_ state. The view state also has an inner `EditingState` which describes various editing view states that the View will need.

These differences in "Feature Shapes" are an excellent example of how the flexibility of VSM states can help you solve problems. You don't always have to use an enum for your view state. You can use whichever combination of enums and structs best describe the feature's requirements.

## Up Next

### Building the View

Now that we have covered how to describe the feature requirements in the view state, we can start assembling the view in <doc:ViewDefinition-SwiftUI> or <doc:ViewDefinition-UIKit>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
