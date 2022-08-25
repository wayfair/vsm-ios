# VSM Overview

An overview of the VSM architecture, framework, and pattern

## Overview

VSM stands for both "View State Model" and "Viewable State Machine". The first definition describes how a feature in VSM is structured, the second definition illustrates how information and actions flow.

### Structure

In VSM, the various responsibilities of a feature are divided into 3 concepts:

1. **View** - Displays the current State and invokes Actions
1. **State** - Defines the states that a given view can have (ie. loading, loaded, error, editing, validating, saving, etc.)
1. **Model(s)** - Provides the Data and Actions available in a given State

The structure of your code should follow the above pattern, with a View code file, a ViewState code file, and a file for each Model's implementation.

Optionally, due to the reactive nature of VSM, Observable Repositories are an excellent companion to VSM Models in performing data operations (such as loading, saving, etc.) whose results can be forwarded to the View.

![VSM Feature Structure Diagram](vsm-structure.jpg)

### Flow

In VSM, the View simply observes and renders the current State of a State Machine. The Actions are invoked by the View and emit at least one new State.

![VSM Feature Flow Diagram](vsm-flow.jpg)

Similar to other Elm-based architectures, VSM operates by a "Unidirectional Data Flow" pattern, which means that the View cannot write directly to the State or the Data. It can only affect the Data and State by invoking the Actions which are made available to the View. This is congruent with other modern architectures, such as React, MVI, The Composable Architecture, Redux, and so on.

### Structure and Flow Combined

As we combine the structure and flow of VSM, you can see how each of the VSM components work together to facilitate the behaviors and flow of information. The ``StateContainer``, which is a crucial part of the VSM iOS framework, manages the relationship between the View and the States and Models.

![VSM Overview Diagram](vsm-diagram.png)

> Important: _The **View** renders the **State**. Each **State** may provide a **Model**. Each Model contains the Data and Actions available in the given State. Each Action in a Model returns one or more new States. State changes update the View._

To reiterate the important point above, these Models contain the Data and Actions that the View will use. Each Model should be scoped to a specific State and should be as narrowly scoped as possible. (Think: Single-purpose Models) You can have any number and combination of States and Models. Together, these represent the functionality of your feature requirements.

In contrast, other architectures use a single ViewModel that contains the Data and Actions of _the entire feature_, often accessible in any State. This is a critically important distinction between VSM and other architectures. VSM provides additional safety by using the type-system to protect Data and Actions against unintended access. **Attempting to read data or call functions from the wrong state will result in a compiler error instead of a runtime error.**

## Why VSM

There are many reasons why the VSM architecture is a strong choice for building native mobile apps. Here is a brief list of Pros and Cons that will be covered in more detail throughout the guide.

### Pros

- Fewer lines of code than most other architectures
- High type-safety
- Unidirectional data flow prevents unintentional state and data bugs
- No shared, mutable data or state
- Execution paths are highly deterministic
- Data and Actions are protected from access in wrong States in both the View and the Models
- Encourages smaller, single-purpose, least-knowledge Models
- Encourages engineers to split up complex functionality between multiple nested Views, resulting in simpler feature code
- Encourages exhaustive error handling
- State & Model definitions are a simple and clear description of the feature requirements (for ease of maintenance)
- Implementation code is easy to read
- Passively encourages "Shifting Left" via Behavior-Driven Development

### Cons

- Defining States, Models, and Actions from feature requirements can be challenging
- Like most other architectures, hanging execution paths within Actions are possible
- Requires some data type translation for consumption by SwiftUI views

## Up Next

### Interpreting Feature Requirements

Now that you understand how VSM generally works, you can learn how to implement features using VSM in <doc:FeatureRequirements>.

#### Support this Project

If you find anything wrong with this guide, or have suggestions on how to improve it, feel free to [create an issue in our GitHub repo](https://github.com/wayfair-incubator/vsm-ios/issues/new/choose).
