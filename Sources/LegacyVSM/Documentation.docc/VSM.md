# ``VSM``

An iOS framework for the VSM Architecture

## Overview

VSM is a reactive, unidirectional, type-safe, behavior-driven, clean architecture.

![VSM Overview Diagram](vsm-diagram.png)

This package provides helpful types for implementing VSM, such as the ``ViewState`` property wrapper (or the ``RenderedViewState`` property wrapper for UIKit views) which manages and renders the current `State`.

## Topics

### VSM Guides

- <doc:QuickstartGuide>
- <doc:ComprehensiveGuide>

### VSM Reference Articles

- <doc:ViewCommunication>
- <doc:ModelActions>
- <doc:ModelStyles>
- <doc:Navigation>
- <doc:ViewStateExtensions>

### VSM Guide Articles

- <doc:VSMOverview>
- <doc:StateDefinition>
- <doc:ViewDefinition-SwiftUI>
- <doc:ViewDefinition-UIKit>
- <doc:ModelDefinition>
- <doc:DataDefinition>
- <doc:UnitTesting>

### Primary Types

- ``ViewState``
- ``RenderedViewState``

### Supporting Types

- ``StateContainer``
- ``StateSequence``
- ``MutatingCopyable``

### Deprecated Types

- ``ViewStateRendering``
