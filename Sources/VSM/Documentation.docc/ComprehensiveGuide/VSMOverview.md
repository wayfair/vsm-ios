# VSM Overview

An overview of the VSM architecture, framework, and pattern

## Overview

VSM stands for both "View State Model" and "Viewable State Machine". The first definition describes how a feature in VSM is structured, the second definition illustrates how information and actions flow.

### Structure

In VSM, the various responsibilities of a feature are divided into 3 concepts:

1. **View** - Displays the current State and invokes Actions
1. **State** - Defines what states a given view can have (ie. loading, loaded, error, editing, validating, saving, etc.)
1. **Model(s)** - Declare what Data and Actions are available in a given State and provides an implementation for the Actions

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

In contrast, other architectures use a single ViewModel that contains the Data and Actions of _the entire feature_, often accessible in any State. This is a critically important distinction between VSM and other architectures. VSM provides additional safety by using the type-system to protect Data and Actions against unintended access. Attempting to read data where it shouldn't be read, or call functions where they shouldn't be called will result in a compiler error.

### Up Next

Now that you understand how the VSM generally works, take a look at how to start implementing features using VSM in <doc:FeatureRequirements>.
