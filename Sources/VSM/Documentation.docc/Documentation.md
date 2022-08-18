# ``VSM``

An iOS framework for the VSM Architecture

## Overview

VSM is a unidirectional, type-safe, behavior-driven, clean architecture.

VSM stands for View State Model. The View observes and renders the State. Each State may provide a Model. Each Model contains the Data and Actions available in the given State. Each Action in a Model returns one or more new States. State changes cause the View to update.

![VSM Overview Diagram](vsm-diagram.png)

This package provides helpful types for implementing VSM, such as the ``StateContainer`` type which manages the current `State`. `UIViews`, `UIViewControllers`, or SwiftUI `Views` that conform to ``ViewStateRendering`` can easily react to changes in `State` by rendering the current `State`.
