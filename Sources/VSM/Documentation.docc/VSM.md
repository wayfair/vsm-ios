# ``VSM``

An iOS framework for the VSM Architecture

## Overview

VSM is a reactive, unidirectional, type-safe, behavior-driven, clean architecture.

![VSM Overview Diagram](vsm-diagram.png)

This package provides helpful types for implementing VSM, such as the ``StateContainer`` type which manages the current `State`. `UIViews`, `UIViewControllers`, or SwiftUI `Views` that conform to ``ViewStateRendering`` can easily react to changes in `State` by rendering the current `State`.

## Topics

### Guides

- <doc:QuickstartGuide>
- <doc:ComprehensiveGuide>

### Reference Articles

- <doc:ViewCommunication>
- <doc:ModelActions>
- <doc:ModelStyles>
- <doc:Navigation>
- <doc:ViewStateExtensions>

### Guide Articles

- <doc:VSMOverview>
- <doc:StateDefinition>
- <doc:ViewDefinition-SwiftUI>
- <doc:ViewDefinition-UIKit>
- <doc:ModelDefinition>
- <doc:DataDefinition>
- <doc:UnitTesting>

### Primary Types

- ``ViewStateRendering``
- ``StateContainer``

### Supporting Types

- ``StateSequence``
- ``MutatingCopyable``
