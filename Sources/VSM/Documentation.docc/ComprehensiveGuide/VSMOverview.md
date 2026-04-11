# VSM Overview

An overview of the VSM architecture, framework, and pattern

## Overview

VSM stands for both "View State Model" and "Viewable State Machine". The first definition describes how a feature in VSM is structured, the second definition illustrates how information and actions flow.

## Structure

In VSM, the various responsibilities of a feature are divided into 3 concepts:

1. **View** - Displays the current state and invokes actions
1. **State** - Defines the states that a given view can have (ie. loading, loaded, error, editing, validating, saving, etc.)
1. **Model(s)** - Provides the data and actions available in a given state

The structure of your code should follow the above pattern, with a view code file and a view state code file. State models are typically defined within extensions of the state type to keep them namespaced to the specific view's state machine. For sufficiently complex models, they may be separated into their own files.

### Separation of Concerns

VSM enforces a strict separation between **view concerns** and **business logic concerns**, encouraging you to think about each view in your application as a state machine.

**View concerns** deal with keeping the view up to date and capturing user interactions. These are managed using the view layer's native state management (such as SwiftUI's `@State` and `@Binding`). Examples include:

- Tracking text changes in a TextField as the user types
- Managing the current value of a Slider within its range
- Toggling between view modes (such as entering or exiting "editing mode")
- Capturing a button tap to signal that the user wants to submit form data

**Business logic concerns** deal with operations that produce results or modify persistent data. These are managed through VSM's state models and their actions. Examples include:

- Loading data from a persistent database or remote API
- Saving form field values into a persistent store
- Validating user input after they finish typing (the view signals completion, business logic validates and returns success or error state)
- Processing data transformations or complex calculations

By thinking of each view as a state machine, VSM naturally guides you to define discrete states that represent meaningful points in your business logic flow. Each state exposes only the actions that are valid for that particular state, preventing invalid operations and ensuring type-safe transitions.

Thanks to the reactive nature of VSM, data sources are an excellent companion to VSM models in performing data operations (such as loading, saving, etc.) and managing the state of data. A data source is a type that encapsulates interactions with a RESTful API, handles read/write operations to a database, or is itself a state machine concerned only with business logic. This data can then be forwarded to the view via async/await patterns and AsyncSequence types.

Data sources can also be shared between views to synchronize the state of various views and data in the app. While simple features may not need data sources, they are an excellent tool for complex features. You'll learn more about these later in the guide.

![VSM Feature Structure Diagram](vsm-structure.jpg)

## Flow

In VSM, the view simply observes and renders the current state of a state machine. The actions are invoked by the view and emit at least one new state.

![VSM Feature Flow Diagram](vsm-flow.jpg)

Similar to other reactive architectures, VSM employs a "Unidirectional Data Flow" pattern, which means that the view cannot write directly to the state or the data. It can only affect the data and state by invoking the actions which are made available to the view. This is congruent with other modern architectures, such as Elm, React, MVI, The Composable Architecture, Redux, Source, and so on.

This unidirectional flow maintains the separation of concerns between view and business logic. View concerns (like TextField text or Slider values) are managed locally by the view using its native state management. When the user signals intent—such as tapping a submit button—the view invokes an action on the current state model, passing any necessary view data. The business logic processes this data asynchronously, then returns one or more new states. The view observes these state changes through VSM's `@ViewState` or `@RenderedViewState` property wrapper and re-renders accordingly. This clean boundary ensures that business logic never directly manipulates the view, and the view never directly mutates business state.

## Structure and Flow Combined

As we combine the structure and flow of VSM, you can see how each of the VSM components work together to facilitate the behaviors and flow of information. The ``AsyncStateContainer``, which is a crucial part of the VSM iOS framework, manages the relationship between the view and the states and models using Swift's modern concurrency features.

![VSM Overview Diagram](vsm-diagram.png)

> Important: _The **view** renders the **state**. Each **state** may provide a **model**. Each model contains the data and actions available in a given state. Each action in a model returns one or more new states. Any changes to state will update the view._

To reiterate the important point above, these models contain the data and actions that the view will use. Each model should be scoped to a specific state and should be as narrowly scoped as possible. (Think: Single-purpose models) If a VSM feature has only one state, then a single model can act as the state for that feature. You can have any number and combination of states and models. Together, these represent the functionality of your feature requirements.

In contrast, other architectures use a single "ViewModel" that contains the data and actions of _the entire feature_, often accessible in any state. This is a critically important distinction between VSM and other architectures. VSM provides additional safety by using the type-system to protect data and actions against unintended access. **Attempting to read data or call functions from the wrong state will result in a compiler error instead of a runtime error.**

> Tip: A view does not need to follow the VSM pattern if it has only one static state and contains no actions, observations, or other behavior. A simple view with accompanying static data model can be used without incurring the boilerplate of the VSM framework.

## Concurrency and Thread Safety

VSM leverages Swift's modern concurrency features to provide a safe and efficient state management system:

- **AsyncStateContainer** uses `@MainActor` isolation to ensure all state changes occur on the main thread
- Actions can run on any thread using async/await, but state updates are always serialized on the main thread
- The framework supports ``StateSequence``, `AsyncStream`, and generic `AsyncSequence` types for multi-state transitions
- No locks or manual synchronization needed - Swift's actor model handles thread safety automatically
- VSM follows a never-throwing design philosophy: actions should handle errors internally and return appropriate error states rather than throwing errors, ensuring predictable state flow and exhaustive error handling

## Why VSM

There are many reasons why the VSM architecture is a strong choice for building native mobile apps. Here is a brief list of Pros and Cons that will be covered in more detail throughout the guide.

### Pros

- Fewer lines of code than most other architectures
- High type-safety
- Built on Swift's modern concurrency model (async/await, actors, Sendable)
- Thread-safe by default through @MainActor isolation
- No manual synchronization required
- Unidirectional data flow prevents unintentional state and data bugs
- No shared, mutable data or state
- Execution paths are highly deterministic
- Data and actions are protected from access in wrong states
- Encourages smaller, single-purpose, least-knowledge models
- Encourages engineers to split up complex functionality between multiple nested views, resulting in simpler feature code
- Intuitively encourages exhaustive error handling
- State & model definitions are a simple and clear description of the feature requirements (for ease of maintenance)
- Implementation code is easy to read
- Supports both SwiftUI (via `@ViewState`) and UIKit (via `@RenderedViewState`)
- Combine-based observation is available in **VSM 1.x**; **VSM 2.0** is async/`StateSequence`/`AsyncStream`-first (see <doc:DataDefinition>)
- Passively encourages "Shifting Left" via Behavior-driven Development principles

### Cons

- Inferring states, models, data, and actions from feature requirements can be challenging
- Like most other architectures, hanging execution paths within actions are possible
- Requires understanding of Swift's modern concurrency model (async/await, Sendable, actors)
- Non-`Sendable` state is supported; you must respect isolation and **`sending`** at call sites—add **`Sendable`** only when your design calls for it (Swift 6.2+ favors precise use, not blanket conformance)

While VSM protects the developer at every step, like all architectures and patterns, discipline in adhering to the VSM best practices will ensure the best experience.

## Up Next

### Interpreting Feature Requirements

Now that you understand how VSM generally works, you can learn how to implement features using VSM in <doc:StateDefinition>.

#### Support this Project

If you find anything wrong with this guide, or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
