# ``VSM``

An iOS framework for the VSM Architecture

## Overview

VSM is a reactive, unidirectional, type-safe, behavior-driven, clean architecture.

![VSM Overview Diagram](vsm-diagram.png)

This package provides helpful types for implementing VSM, such as the ``StateContainer`` type which manages the current `State`. `UIViews`, `UIViewControllers`, or SwiftUI `Views` that conform to ``ViewStateRendering`` can easily react to changes in `State` by rendering the current `State`.

## Topics

### Guides

- <doc:ComprehensiveGuide>
- <doc:QuickstartGuide>

### Primary Types

- ``ViewStateRendering``
- ``StateContainer``

### Supporting Types

- ``StateSequence``
- ``MutatingCopyable``
