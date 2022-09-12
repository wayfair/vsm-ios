# VSM Overview

An overview of the VSM architecture, framework, and pattern

## Overview

VSM stands for both "View State Model" and "Viewable State Machine". The first definition describes how a feature in VSM is structured, the second definition illustrates how information and actions flow.

## Structure

In VSM, the various responsibilities of a feature are divided into 3 concepts:

1. **View** - Displays the current state and invokes actions
1. **State** - Defines the states that a given view can have (ie. loading, loaded, error, editing, validating, saving, etc.)
1. **Model(s)** - Provides the data and actions available in a given state

The structure of your code should follow the above pattern, with a view code file, a view state code file, and a file for each model's implementation.

Optionally, due to the reactive nature of VSM, Observable Repositories are an excellent companion to VSM models in performing data operations (such as loading, saving, etc.) whose results can be forwarded to the view. These repositories can be shared between views for a powerful, yet safe approach to synchronizing the state of various views and data in the app.

![VSM Feature Structure Diagram](vsm-structure.jpg)

## Flow

In VSM, the view simply observes and renders the current state of a state machine. The actions are invoked by the view and emit at least one new state.

![VSM Feature Flow Diagram](vsm-flow.jpg)

Similar to other reactive architectures, VSM employs a "Unidirectional Data Flow" pattern, which means that the view cannot write directly to the state or the data. It can only affect the data and state by invoking the actions which are made available to the view. This is congruent with other modern architectures, such as Elm, React, MVI, The Composable Architecture, Redux, Source, and so on.

## Structure and Flow Combined

As we combine the structure and flow of VSM, you can see how each of the VSM components work together to facilitate the behaviors and flow of information. The ``StateContainer``, which is a crucial part of the VSM iOS framework, manages the relationship between the view and the states and models.

![VSM Overview Diagram](vsm-diagram.png)

> Important: _The **view** renders the **state**. Each **state** may provide a **model**. Each model contains the data and actions available in a given state. Each action in a model returns one or more new states. Any changes to state will update the view._

To reiterate the important point above, these models contain the data and actions that the view will use. Each model should be scoped to a specific state and should be as narrowly scoped as possible. (Think: Single-purpose models) If a VSM feature has only one state, then a single model can act as the state for that feature. You can have any number and combination of states and models. Together, these represent the functionality of your feature requirements.

In contrast, other architectures use a single "ViewModel" that contains the data and actions of _the entire feature_, often accessible in any state. This is a critically important distinction between VSM and other architectures. VSM provides additional safety by using the type-system to protect data and actions against unintended access. **Attempting to read data or call functions from the wrong state will result in a compiler error instead of a runtime error.**

> Tip: A view does not need to follow the VSM pattern if it has only one static state and contains no actions, observations, or other behavior. A simple view with accompanying static data model can be used without incurring the boilerplate of the VSM framework.

## Why VSM

There are many reasons why the VSM architecture is a strong choice for building native mobile apps. Here is a brief list of Pros and Cons that will be covered in more detail throughout the guide.

### Pros

- Fewer lines of code than most other architectures
- High type-safety
- Unidirectional data flow prevents unintentional state and data bugs
- No shared, mutable data or state
- Execution paths are highly deterministic
- Data and actions are protected from access in wrong states
- Encourages smaller, single-purpose, least-knowledge models
- Encourages engineers to split up complex functionality between multiple nested views, resulting in simpler feature code
- Intuitively encourages exhaustive error handling
- State & model definitions are a simple and clear description of the feature requirements (for ease of maintenance)
- Implementation code is easy to read
- Passively encourages "Shifting Left" via Behavior-driven Development principles

### Cons

- Inferring states, models, data, and actions from feature requirements can be challenging
- Like most other architectures, hanging execution paths within actions are possible
- Requires some data type translation for consumption by SwiftUI views

While VSM protects the developer at every step, like all architectures and patterns, discipline in adhering to the VSM best practices will ensure the best experience.

## Up Next

### Interpreting Feature Requirements

Now that you understand how VSM generally works, you can learn how to implement features using VSM in <doc:StateDefinition>.

#### Support this Project

If you find anything wrong with this guide, or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
