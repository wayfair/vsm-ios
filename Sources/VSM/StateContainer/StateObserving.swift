//
//  StateObserving.swift
//
//
//  Created by Albert Bori on 1/26/23.
//

import Combine
import Foundation

/// Provides functions for observing an action for potentially new states
public protocol StateObserving<State> {
    associatedtype State
    
    /// Observes the state publisher emitted as a result of invoking some action
    func observe(_ statePublisher: AnyPublisher<State, Never>)

    /// Observes the state emitted as a result of invoking some synchronous action
    func observe(_ nextState: State)
    
    /// Observes the state emitted as a result of invoking some asynchronous action
    func observeAsync(_ nextState: @escaping () async -> State)
    
    /// Observes the states emitted as a result of invoking some asynchronous action that returns an asynchronous sequence
    func observeAsync<StateSequence: AsyncSequence>(_ stateSequence: @escaping () async -> StateSequence) where StateSequence.Element == State
    
    // MARK: - Debounce
    
    /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - statePublisher: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ statePublisher: @escaping @autoclosure () ->  AnyPublisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ nextState: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
    
    /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observeAsync(
        _ nextState: @escaping () async -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
    
    /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateSequence: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observeAsync<SomeAsyncSequence: AsyncSequence>(
        _ stateSequence: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) where SomeAsyncSequence.Element == State
}

public extension StateObserving {
        
    /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - statePublisher: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ statePublisher: @escaping @autoclosure () -> AnyPublisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        observe(statePublisher(), debounced: dueTime, identifier: HashedIdentifier(file, line))
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ nextState: @escaping () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        observe(nextState(), debounced: dueTime, identifier: HashedIdentifier(file, line))
    }
    
    /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observeAsync(
        _ nextState: @escaping () async -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        observeAsync(nextState, debounced: dueTime, identifier: HashedIdentifier(file, line))
    }
    
    /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateSequence: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observeAsync<SomeAsyncSequence: AsyncSequence>(
        _ stateSequence: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) where SomeAsyncSequence.Element == State {
        observeAsync(stateSequence, debounced: dueTime, identifier: HashedIdentifier(file, line))
    }
}
