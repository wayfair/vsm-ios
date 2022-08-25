# Interpreting Feature Requirements

A guide to translating feature requirements into VSM code

## Overview

The normal layered-pass approach to translating feature requirements into code is responsible for many bugs. The VSM architecture encourages a more careful examination of requirements upfront.

### The Status Quo

It is very common for engineers to do the following when implementing a new feature:

1. Skim the requirements and designs in the ticket
1. Implement a little bit of the view and the business logic
1. Run the app to see if that bit worked
1. Repeat until the engineer thinks they are done with all of the requirements

With this approach, the overall technical design of the feature's implementation suffers due to the lack of forethought that goes into translating the feature requirements as a whole into a good implementation in code. More importantly, this approach is responsible for many bugs that result from not understanding the entirety of the requirements before coding the feature. A good manual QA process may help shorten this gap, but gaining a better understanding of requirements before building the feature is the safest bet.

### Behavior-Driven Architecture

VSM aims to break the above tradition by encouraging engineers to define a representation of the feature requirements before any implementation (View or Model) is developed. Of course, this can't be done without the engineer carefully studying the requirements and asking questions that clarify any ambiguity in the requirements themselves.

VSM encourages **Behavior-Driven Development** by requiring that every feature declare a `ViewState` type before implementing the View or Business Logic code. This `ViewState` describes all of the States that the View can have, and the Data and Actions associated with each State. This is done by using a mix of core Swift types (`enums` and `structs`) to describe the States, Data, and Actions.

The following example defines the ViewState for a VSM feature that allows a user to view, change, and save their username.

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

In VSM, the View can only see and draw the current `ViewState`.

For example, if the current State is `UserProfileViewState.loaded`, then the View can only access the `LoadedModel`'s `username` property and will only be able to call the `saveUsername(...)` function.

When `saveUsername(...)` is called, the Action should output the `UserProfileViewState.saving` State to the View. At that time, `saveUsername(...)` will no longer be accessible to the View. Instead, only the `SavingModel`'s properties and `cancel()` function are available to the View.

If `cancel()` is called, the Action should return the `loaded` State. If `cancel()` is not called, then the previous `saveUsername(...)` call is free to finish by emitting a final `.loaded` State after the username has been saved to the data source.

To reiterate:

> Important: The **`loaded(LoadedModel)`** and **`saving(SavingModel)`** States have separate Models and those Models have separate Data and Actions. This protects the functionality so that the View cannot call **`cancel()`** while in the **`loaded`** State, nor call **`save(username)`** while already in the **`saving`** State. The Data between these Models is also different because some Data may need to be unique for each State.

## Defining States and Models

Translating requirements into abstract types in code can be a bit challenging at first. By using the right process, it can quickly become second nature.

### Extracting the Concepts from the Feature Requirements

The best way to build features in VSM is to carefully read the requirements and translate those requirements into a flow chart. This will help you more easily identify the States, Data, and Actions that a feature needs.

Consider the following requirements.

```gherkin
Feature: Load and Edit User Profile
Scenario: User navigates to the User Profile Editor
  Given I am logged in
  When I tap "Edit Profile"
  Then I should see the Loading Screen
  Then I should see the Editing Screen
Scenario: User navigates to the User Profile Editor without internet
  Given I am logged in
  And I am not connected to the internet
  When I tap "Edit Profile"
  Then I should see the Loading Screen
  Then I should see the Error Screen
Scenario: User refreshes the user profile editor
  Given I am logged in
  And I tapped "Edit Profile"
  When I tap "Refresh"
  Then I should see the Reloading Screen
  Then I should see the Editing Screen
Scenario: User saves username
  Given I am logged in
  And I tapped "Edit Profile"
  When I change my Display Name
  And I tap "Save"
  Then I should see the Saving Screen
  Then I should see the Editing Screen
  And I should see the new Display Name
```

After careful study, you may produce a flow chart that looks something like this:

![VSM User Flow Diagram Example](vsm-user-flow-example.jpg)

### Converting Flow Diagrams to Enums and Structs

With the above diagram, it becomes much easier infer which States, Data, and Actions should exist for this feature.

#### Determining the States

States usually match up 1:1 with variations in the View. So, we can safely assume that we will need the following states: `loading`, `error`, `editing`, `reloading`, and `saving`. 

> Note: We will need to add an extra State called `initialized` to kick off the `load()` Action. This protects the `load()` Action from accidentally being called in the wrong State.

The resulting diagram looks like this:

![VSM State Flow Diagram Example](vsm-state-flow-example.jpg)

If we translate the states from the above flow chart, our resulting States `enum` looks like this:

```swift
enum UserProfileViewState {
  case initialized  // This is our default state when constructing the View
  case loading    // Represents the Loading View
  case loadingError  // Represents the Error View
  case editing    // Represents the Editing View
  case reloading   // Represents the Reloading View
  case saving     // Represents the Saving View
}
```

#### Defining the Models

Now that we have our States, we can define the Models for each State with their associated Data and Actions. As you can see from the above chart, the `initialized` state will need a User Id property and a `load()` action, so we will define our module with a simple `struct` like so:

```swift
struct LoaderModel {
  let userId: Int
  let load: () -> AnyPublisher<UserProfileViewState, Never>
}
```

We want the `load()` function to emit two States. First, the `loading` State while the `UserData` loads, then the `editing` State when the loading is complete. To allow for this, we use a Combine Publisher that can send multiple `UserProfileViewState` values to the View.

The `load()` Action is declared as a property of the struct instead of a function so that the implementation can be declared elsewhere (covered in <doc:ModelDefinition>). This makes it easier to read the feature definition, as well as easier to mock the various Models when unit testing or using SwiftUI Previews.

The Publisher returned from `load()` uses the `Never` error type. This helps the compiler to enforce proper error handling by requiring the Action to convert any Error type to a `UserProfileViewState`. The code above infers that `load()` will convert any errors to the `loadingError` State.

Next, we'll define the Model for the `editing` state. As per the diagram, this will need the loaded `UserData` and two Actions: `reload` and `save`.

```swift
struct EditingModel {
  var data: UserData
  let reload: () -> AnyPublisher<UserProfileViewState, Never>
  let saveDisplayName: (String) -> AnyPublisher<UserProfileViewState, Never>
}
```

The unique thing about this Model from the previous example is that the `saveDisplayName` function expects a String parameter that represents the new username. The View will be responsible for passing the User Name textbox value to this function when it is called.

Finally, we'll use the same approach to build an `ErrorModel` for the `loadingError` State. This model will need to provide an error message String and a `retry()` Action for the user to press in case of error.

```swift
struct ErrorModel {
  let message: String
  let retry: () -> AnyPublisher<UserProfileViewState, Never>
}
```

#### States Without Models

Some States do not require Models.

For example, the `loading` State has no data to show, nor any Actions to call. We will not provide a Model for that State, as it will be managed by the `LoaderModel`. 

The `saving` and `reloading` States _do_ have some associated Data, but no Actions. Instead of creating a custom Model for each, we can just use the currently loaded `UserData`. The `EditingModel`'s Actions (`reload()` and `saveDisplayName()`, respectively) can manage the flow of those States.

```swift
  case reloading(UserData)
  case saving(UserData)
```

#### The "Shape" of the Feature

If we put all of this together, the resulting VSM feature definition is as follows. This can be referred to as the "Shape of the Feature".

```swift
enum UserProfileViewState {
  case initialized(LoaderModel)
  case loading
  case loadingError(ErrorModel)
  case editing(EditingModel)
  case reloading(UserData)
  case saving(UserData)

  struct EditingModel {
    var data: UserData
    let reload: () -> AnyPublisher<UserProfileViewState, Never>
    let saveDisplayName: (String) -> AnyPublisher<UserProfileViewState, Never>
  }

  struct ErrorModel {
    let message: String
    let retry: () -> AnyPublisher<UserProfileViewState, Never>
  }
}
```

As you can see from the above code, we now have a clear and simple picture of how the feature works and what View will be able to see and do in any given State.

In contrast, many other architectures will tell you to put all of X in "this" bucket, and all of Y in "that" bucket. However, with VSM, the "Shape of the Feature" is entirely up to you and provides unprecedented type-safety for the entire feature.

You have absolute creative freedom in how the feature requirements are modeled into Swift, as long as you follow some basic guidelines:

1. Your feature shape is contained within a single `ViewState` type
1. All Actions that update the View _must_ return one or more of these `ViewState` values
1. Data and Actions are not accessible outside of their intended States

#### Simple Feature Shapes

While the above feature shape is a good design, it is a fairly complex example for VSM. There is an opportunity here to simplify further by separating some concerns across multiple smaller VSM components. To do this, look for a way to cleanly break the State into smaller, less complex type graphs.

Considering that loading the `UserData` only happens once for the entire lifecycle of this feature. The `initialized`, `loading`, and `loadingError` States can be split off to a parent View. Once loaded, the parent View can show the Editing View as its child, passing the `UserData` to it upon construction. If we follow this approach, we end up with two separate, but related VSM components, each with their own States, Data, and Actions.

As described above, the parent VSM component will have the following ViewState definition:

```swift
enum LoadUserProfileViewState {
  case initialized(LoaderModel)
  case loading
  case loadingError(ErrorModel)
  case loaded(UserData)

  struct LoaderModel {
    let userId: Int
    let load: () -> AnyPublisher<LoadUserProfileViewState, Never>
  }

  struct ErrorModel {
    let message: String
    let retry: () -> AnyPublisher<LoadUserProfileViewState, Never>
  }
}
```

In the above example, the `loading` and `loadingError` concepts are separated from the editing functionality. Instead of providing a Model for the `loaded` State, we provide only the raw `UserData` value that can be used by the Loader View to hydrate the Editing View, as defined below:

```swift
struct EditUserProfileViewState {
  var data: UserData
  var state: EditingState

  enum EditingState {
    case editing(EditingModel)
    case saving
    case reloading
  }

  struct EditingModel {
    let reload: () -> AnyPublisher<EditUserProfileViewState, Never>
    let saveDisplayName: (String) -> AnyPublisher<EditUserProfileViewState, Never>
  }
}
```

The above `ViewState` is shaped a little differently than the examples found earlier in this article. We chose a `struct` as the primary Swift type for our `ViewState` because `UserData` should exist in _every_ State of the Editing View. We then have an inner `EditingState` that describes various Editing View States.

This is a great example of how flexible the VSM States can be to help you solve problems, and how you don't always have to use an `enum` for your `ViewState`.

## Further Reading

- TODO: Describe different Action types: Single value (async or sync), AsyncSequence<ViewState>, void result, etc.

## Up Next

### Building the View

Now that we have covered how to describe the feature requirements in the `ViewState`, we can start assembling the View in <doc:ViewDefinition>.

#### Support this Project

If you find anything wrong with this guide or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
