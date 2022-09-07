# Building the State in VSM

A guide to translating feature requirements into VSM code

## Overview

The normal layered-pass approach to translating feature requirements into code is responsible for many bugs. The VSM architecture encourages a more careful examination of requirements upfront.

## The Status Quo

It is very common for engineers to do the following when implementing a new feature:

1. Skim the requirements and designs in the ticket
1. Implement a little bit of the view and the business logic
1. Run the app to see if that bit worked
1. Repeat until the engineer thinks they are done with all of the requirements

With this approach, the overall technical design of the feature's implementation suffers due to the lack of forethought that goes into translating the feature requirements as a whole into a good implementation in code. More importantly, this approach is responsible for many bugs that result from not understanding the entirety of the requirements before coding the feature. A good manual QA process may help shorten this gap, but gaining a better understanding of requirements before building the feature is the safest bet.

## Behavior-Driven Architecture

VSM aims to break the above tradition by encouraging engineers to define a representation of the feature requirements before any implementation (view or model) is developed. Of course, this can't be done without the engineer carefully studying the requirements and asking questions that clarify any ambiguity in the requirements themselves.

VSM encourages **Behavior-Driven Development** by requiring that every feature declare a view state type before implementing the view or business logic code. This view state describes all of the states that the view can have, and the data and actions associated with each state. This is done by using a mix of core Swift types (`enums` and `structs`) to describe the states, data, and actions.

The following example defines the view state for a VSM feature that allows a user to view, change, and save their username.

```swift
enum UserProfileViewState {
 case loaded(LoadedModel)
 case saving(SavingModel)

 struct LoadedModel {
    let username: String
    let saveUsername: (String) -> AnyPublisher<UserProfileViewState, Never>
 }

 struct SavingModel {
    let originalUsername: String
    let newUsername: String
    let cancel: () -> UserProfileViewState
 }
}
```

In VSM, the view can only see and draw the current view state.

For example, if the current state is `UserProfileViewState.loaded`, then the view can only access the `LoadedModel`'s `username` property and will only be able to call the `saveUsername()` function.

When `saveUsername()` is called, the action should output the `UserProfileViewState.saving` state to the view. At that time, `saveUsername()` will no longer be accessible to the view. Instead, only the `SavingModel`'s properties and `cancel()` function are available to the view.

If `cancel()` is called, the action should return the `loaded` state. If `cancel()` is not called, then the previous `saveUsername()` call is free to finish by emitting a final `.loaded` state after the username has been saved to the data source.

To reiterate:

> Important: The **`loaded(LoadedModel)`** and **`saving(SavingModel)`** states have separate models and those models have separate data and actions. This protects the functionality so that the view cannot call **`cancel()`** while in the **`loaded`** state, nor call **`save(username)`** while already in the **`saving`** state. The data between these models is also different because some data may need to be unique for each state.

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

States usually match up 1:1 with variations in the view. So, we can safely assume that we will need the following states: `loading`, `loadingError`, `editing`, `saving`, and `savingError`.

> Note: We will need to add an extra state called `initialized` to kick off the `load()` action when the view appears. `load()` will immediately return the `loading` state. This protects the `load()` action from accidentally being called from the wrong state.
>
> For example, in iOS, a view's `onAppear` handler can be called multiple times during a view's lifetime. By using the `initialized` state, we don't have to worry about the `load()` function being called multiple times even if `onAppear` is called multiple times before the data is finished loading.
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

If we translate the states from the above flow chart, our resulting view state `enum` looks like this:

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

Now that we have our states, we can define the models for each state with their associated data and actions. As you can see from the above chart, the `initialized` state will need a `load()` action, so we will define our model with a simple `struct` like so:

```swift
struct LoaderModel {
    let load: () -> AnyPublisher<UserProfileViewState, Never>
}
```

We want the `load()` function to emit two states. First, the `loading` state while the `UserData` loads, then the `editing` state when the loading is complete. To allow for this, we use a Combine Publisher that can send multiple `UserProfileViewState` values to the view.

The `load()` action is declared as a property of the struct instead of a function so that the implementation can be declared elsewhere (covered in <doc:ModelDefinition>). This makes it easier to read the feature definition, as well as easier to mock the various models when unit testing or using SwiftUI Previews.

The Publisher returned from `load()` uses the `Never` error type. This helps the compiler to enforce proper error handling by requiring the action to convert any Error type to a `UserProfileViewState`. For example, the code above infers that `load()` will convert any errors to the `loadingError` state.

To learn more about VSM's supported action types, see <doc:ModelActions>.

Next, we'll define the model for the `editing` state. As per the diagram, this will need the loaded `UserData` and the `save` action.

```swift
struct EditingModel {
    var data: UserData
    let saveUsername: (String) -> AnyPublisher<UserProfileViewState, Never>
}
```

The unique thing about this model from the previous example is that the `saveUsername` function expects a String parameter that represents the new username. The view will be responsible for passing the User Name textbox value to this function when it is called.

Finally, we'll use the same approach to build error models for the `loadingError` and `savingError` states. These models will need to provide an error message String and a `retry()` action for the user to press in case of error. For the `savingError`, an additional `UserData` property is needed for the view to display along with the error. The `savingError` model will also have a `cancel()` action that will allow the user to go back to editing.

```swift
struct LoadingErrorModel {
    let message: String
    let retry: () -> AnyPublisher<UserProfileViewState, Never>
}

struct SavingErrorModel {
    let data: UserData
    let message: String
    let retry: () -> AnyPublisher<UserProfileViewState, Never>
    let cancel: () -> AnyPublisher<UserProfileViewState, Never>
}
```

#### States Without Models

Some states do not require models.

For example, the `loading` state has no data to show, nor any actions to call. We will not provide a model for that state, as it will be managed by the `LoaderModel`.

```swift
case loading
```

The `saving` state _does_ have some associated data, but no actions. Instead of creating a custom model for it, we can just use the currently loaded `UserData`. The `EditingModel`'s `saveDisplayName()` action can manage the flow of the `saving` state.

```swift
case saving(UserData)
```

## The "Shape" of the Feature

If we put all of this together, the resulting VSM feature definition is as follows. This can be referred to as the "Shape of the Feature".

```swift
enum UserProfileViewState {
    case initialized(LoaderModel)
    case loading
    case loadingError(LoadingErrorModel)
    case editing(EditingModel)
    case saving(UserData)
    case savingError(SavingErrorModel)

    struct LoaderModel {
        let load: () -> AnyPublisher<UserProfileViewState, Never>
    }

    struct LoadingErrorModel {
        let message: String
        let retry: () -> AnyPublisher<UserProfileViewState, Never>
    }

    struct EditingModel {
        var data: UserData
        let saveUsername: (String) -> AnyPublisher<UserProfileViewState, Never>
    }
    
    struct SavingErrorModel {
        let data: UserData
        let message: String
        let retry: () -> AnyPublisher<UserProfileViewState, Never>
        let cancel: () -> AnyPublisher<UserProfileViewState, Never>
    }
}
```

As you can see from the above code, we now have a clear and simple picture of how the feature works and what the view will be able to see and do in any given state.

In contrast, many other architectures will tell you to put all of X in "this" bucket, and all of Y in "that" bucket. However, with VSM, the "Shape of the Feature" is entirely up to you and provides unprecedented type-safety for the entire feature. You'll find that as you implement features in VSM, the compiler will protect the business logic based on the above definition.

You have absolute creative freedom in how the feature requirements are modeled into Swift, as long as you follow some basic guidelines:

1. Your feature shape is contained within a single `ViewState` type
1. All actions that update the view _must_ return one or more of these `ViewState` values
1. Data and actions are not accessible outside of their intended states

### Simple Feature Shapes

While the above feature shape is a good design, it is a fairly complex example for VSM. There is an opportunity here to simplify further by separating some concerns across multiple smaller VSM components. To do this, look for a way to cleanly break the state into smaller, less complex type graphs. It also helps to consider how this feature shape will be interpreted by the view, then optimize for efficiency without sacrificing safety where possible.

The loading of `UserData` only happens once for the entire lifecycle of this feature. Therefore, the `initialized`, `loading`, and `loadingError` states can be split off to a parent view. Once loaded, the parent view can show the Editing View as its child, passing the `UserData` to it upon construction. If we follow this approach, we end up with two separate, but related VSM components, each with its own states, data, and actions.

As described above, the parent VSM component will have the following view state definition:

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

In the above example, the `UserData` loading states are extracted into their own view state. Instead of providing a model for the `loaded` state, we provide only the raw `UserData` value that can be used by the Loader View to hydrate the Editing View, as defined below:

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
        let saveDisplayName: (String) -> AnyPublisher<EditUserProfileViewState, Never>
    }

    struct ErrorModel {
        let message: String
        let retry: () -> AnyPublisher<EditUserProfileViewState, Never>
        let cancel: () -> AnyPublisher<EditUserProfileViewState, Never>
    }
}
```

Next, the editing functionality is moved into its own view state. This view state is shaped a little differently than the examples found earlier in this article. We chose a `struct` as the primary Swift type for our view state because `UserData` should be available to the Editing View in _every_ state. The view state also has an inner `EditingState` which describes various editing view states for the view.

This is a great example of how flexible the VSM states can be to help you solve problems, and how you don't always have to use an `enum` for your view state.

## Up Next

### Building the View

Now that we have covered how to describe the feature requirements in the view state, we can start assembling the view in <doc:ViewDefinition-SwiftUI> or <doc:ViewDefinition-UIKit>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
