# LegacyVSM

An iOS framework for the VSM Architecture

## Overview

VSM is a reactive, unidirectional, type-safe, behavior-driven, clean architecture.

![VSM Overview Diagram](vsm-diagram.png)

This package provides helpful types for implementing VSM, such as the ``LegacyViewState`` property wrapper (or the ``LegacyRenderedViewState`` property wrapper for UIKit views) which manages and renders the current `State`.

> Important: LegacyVSM exists to support a gradual move from Combine-based stateful workflows to Swift structured concurrency, which is the model used by VSM 2.0.
>
> If you are upgrading to version 2.0 of VSM, you are on a migration path: treat LegacyVSM as a bridge while you move existing VSM state machines off Combine and onto structured concurrency (async/await, tasks, and actors) in line with the modern VSM APIs.

For a step-by-step migration guide, see [Migrating from VSM 1.x (LegacyVSM) to VSM 2.0](https://wayfair.github.io/vsm-ios/documentation/vsm/migrationfromlegacyvsm) in the hosted **VSM** documentation.

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

- ``LegacyViewState``
- ``LegacyRenderedViewState``

### Supporting Types

- ``StateContainer``
- ``StateSequence``
- ``MutatingCopyable``

### Deprecated Types

- ``ViewStateRendering``
