//
//  StateContaining.swift
//  
//
//  Created by Albert Bori on 1/23/23.
//

import Combine
import Foundation
import SwiftUI

/// Combines commonly used state management protocols into a single protocol
public protocol StateContaining<State>: StateObserving, StateBinding, StatePublishing { }

/// Provides a state publisher for observation
public protocol StatePublishing<State> {
    associatedtype State
    /// Publishes the State changes on the main thread
    var publisher: AnyPublisher<State, Never> { get }
}

/// Provides functions for observing an action for potentially new states
public protocol StateObserving<State> {
    associatedtype State
    
    /// Observes the state publisher emitted as a result of invoking some action
    func observe(_ stateChangePublisher: AnyPublisher<State, Never>)

    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the state emitted as a result of invoking some asynchronous action
    func observe(_ awaitState: @escaping () async -> State)
    
    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the states emitted as a result of invoking some asynchronous action that returns an asynchronous sequence
    func observe<StateSequence: AsyncSequence>(_ awaitStateSequence: @escaping () async -> StateSequence) where StateSequence.Element == State

    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the state emitted as a result of invoking some synchronous action
    func observe(_ nextState: @autoclosure @escaping () -> State)
    
    // MARK: - Debounce
    
    /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangePublisherAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangePublisherAction: @escaping @autoclosure () ->  AnyPublisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
    
    /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangeAsyncAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangeAsyncAction: @escaping () async -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
    
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
    ) where SomeAsyncSequence.Element == State
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangeAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangeAction: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
}

public extension StateObserving {
    
    /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangePublisherAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangePublisherAction: @escaping @autoclosure () -> AnyPublisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        observe(stateChangePublisherAction(), debounced: dueTime, identifier: DebounceIdentifier(defaultId: UUID(), file: file, line: line))
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
    ) where SomeAsyncSequence.Element == State {
        observe(stateChangeAsyncSequenceAction, debounced: dueTime, identifier: DebounceIdentifier(defaultId: UUID(), file: file, line: line))
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangeAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangeAction: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        observe(stateChangeAction, debounced: dueTime, identifier: DebounceIdentifier(defaultId: UUID(), file: file, line: line))
    }
}

public protocol StateBinding<State> {
    associatedtype State
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`ViewState` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> State) -> Binding<Value>
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **This doesn't work when`ViewState` is an enum**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> State) -> Binding<Value>
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`ViewState` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> AnyPublisher<State, Never>) -> Binding<Value>
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **Not intended for use when`ViewState` is an enum.**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> AnyPublisher<State, Never>) -> Binding<Value>
}
