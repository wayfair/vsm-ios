import Combine

/// Convenience protocol for encouraging the core VSM pattern
public protocol ViewStateRendering {
    
    /// The type that represents your View's state. Usually an enum with associated values of type `StateModel` for complex views.
    associatedtype ViewState
    
    /// Contains the actual `State` value for converting to something displayable
    var container: StateContainer<ViewState> { get }
}

//MARK: - State Extension

public extension ViewStateRendering {
    
    /// Convenience accessor for the `StateContainer`'s `state` property.
    var state: ViewState {
        container.state
    }
}

// MARK: - Observe Extensions

public extension ViewStateRendering {
    
    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the state publisher emitted as a result of invoking some action
    func observe(_ stateChangePublisher: AnyPublisher<ViewState, Never>) {
        container.observe(stateChangePublisher)
    }

    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the state emitted as a result of invoking some asynchronous action
    func observe(_ awaitState: @escaping () async -> ViewState) {
        container.observe(awaitState)
    }
    
    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the states emitted as a result of invoking some asynchronous action that returns an asynchronous sequence
    func observe<StateSequence: AsyncSequence>(_ awaitStateSequence: @escaping () async -> StateSequence) where StateSequence.Element == ViewState {
        container.observe(awaitStateSequence)
    }

    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the state emitted as a result of invoking some synchronous action
    func observe(_ nextState: @autoclosure @escaping () -> ViewState) {
        container.observe(nextState)
    }
}

// MARK: - Binding Extensions

#if canImport(SwiftUI)

import SwiftUI

// MARK: - Synchronous Observed Binding Extensions

public extension ViewStateRendering where Self: View {
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`ViewState` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<ViewState, Value>, to observedSetter: @escaping (ViewState, Value) -> ViewState) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **This doesn't work when`ViewState` is an enum**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<ViewState, Value>, to observedSetter: @escaping (ViewState) -> (Value) -> ViewState) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
}

// MARK: - Asynchronous Observed Binding Extensions

public extension ViewStateRendering where Self: View {
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`ViewState` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<ViewState, Value>, to observedSetter: @escaping (ViewState, Value) async -> ViewState) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **Not intended for use when`ViewState` is an enum.**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<ViewState, Value>, to observedSetter: @escaping (ViewState) -> (Value) async -> ViewState) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
}

// MARK: - ViewState-Publishing Observed Binding Extensions

public extension ViewStateRendering where Self: View {
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`ViewState` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<ViewState, Value>, to observedSetter: @escaping (ViewState, Value) -> AnyPublisher<ViewState, Never>) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **Not intended for use when`ViewState` is an enum.**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<ViewState, Value>, to observedSetter: @escaping (ViewState) -> (Value) -> AnyPublisher<ViewState, Never>) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
}

#endif

// MARK: Observe Debounce Extensions

public extension ViewStateRendering {
    
    /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangePublisherAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangePublisherAction: @escaping @autoclosure () -> AnyPublisher<ViewState, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        container.observe(stateChangePublisherAction(), debounced: dueTime, file: file, line: line)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangePublisherAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangePublisherAction: @escaping @autoclosure () ->  AnyPublisher<ViewState, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        container.observe(stateChangePublisherAction(), debounced: dueTime, identifier: identifier)
    }
    
    /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangeAsyncAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangeAsyncAction: @escaping () async -> ViewState,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        container.observe(stateChangeAsyncAction, debounced: dueTime, file: file, line: line)
    }
    
    /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangeAsyncAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangeAsyncAction: @escaping () async -> ViewState,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        container.observe(stateChangeAsyncAction, debounced: dueTime, identifier: identifier)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangeAsyncSequenceAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe<SomeAsyncSequence: AsyncSequence>(
        _ stateChangeAsyncSequenceAction: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) where SomeAsyncSequence.Element == ViewState {
        container.observe(stateChangeAsyncSequenceAction, debounced: dueTime, file: file, line: line)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangeAsyncSequenceAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe<SomeAsyncSequence: AsyncSequence>(
        _ stateChangeAsyncSequenceAction: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) where SomeAsyncSequence.Element == ViewState {
        container.observe(stateChangeAsyncSequenceAction, debounced: dueTime, identifier: identifier)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangeAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangeAction: @escaping @autoclosure () -> ViewState,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        container.observe(stateChangeAction(), debounced: dueTime, file: file, line: line)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangeAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangeAction: @escaping @autoclosure () -> ViewState,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        container.observe(stateChangeAction(), debounced: dueTime, identifier: identifier)
    }
    
}
