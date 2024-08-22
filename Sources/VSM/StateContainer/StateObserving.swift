//
//  StateObserving.swift
//
//
//  Created by Albert Bori on 1/26/23.
//

import Combine
import Foundation

/// Provides functions for observing VSM actions to render new states on the view.
public protocol StateObserving<State> {
    associatedtype State
    
    /// Renders the states emitted by the publisher on the view.
    /// - Parameter statePublisher: The view state publisher to be observed for rendering the current view state
    func observe(_ statePublisher: some Publisher<State, Never>)
    
    /// Renders the next state on the view.
    /// - Parameter nextState: The next view state to render.
    func observe(_ nextState: State)
    
    /// Renders an asynchronous sequence states returned on the view.
    /// - Parameter stateSequence: A sequence of states to render.
    func observe<SomeAsyncSequence: AsyncSequence>(_ stateSequence: SomeAsyncSequence) where SomeAsyncSequence.Element == State
    
    /// Asynchronously renders the next state on the view.
    /// - Parameter nextState: An async closure that returns the next state to render.
    func observeAsync(_ nextState: @escaping () async -> State)
    
    @MainActor
    func waitFor(_ nextState: @escaping () async -> State) async -> Void
    
    /// Calls an async closure that returns an asynchronous sequence of states. Those states are rendered by the view in the order received.
    /// - Parameter stateSequence: An async closure that returns a sequence of states.
    func observeAsync<SomeAsyncSequence: AsyncSequence>(_ stateSequence: @escaping () async -> SomeAsyncSequence) where SomeAsyncSequence.Element == State
    
    // MARK: - Debounce
    
    /// Renders the states emitted by the publisher on the view.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
    /// - Parameters:
    ///   - statePublisher: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: (optional) The identifier for grouping actions for debouncing
    func observe(
        _ statePublisher: @escaping @autoclosure () -> some Publisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
    
    /// Renders the next state on the view.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: (optional) The identifier for grouping actions for debouncing
    func observe(
        _ nextState: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
    
    /// Renders an asynchronous sequence of states returned on the view.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
    /// - Parameters:
    ///   - stateSequence: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: (optional) The identifier for grouping actions for debouncing
    func observe<SomeAsyncSequence: AsyncSequence>(
        _ stateSequence: SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) where SomeAsyncSequence.Element == State
    
    /// Asynchronously renders the next state on the view.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: (optional) The identifier for grouping actions for debouncing
    func observeAsync(
        _ nextState: @escaping () async -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    )
    
    /// Calls an async closure that returns an asynchronous sequence of states. Those states are rendered by the view in the order received.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
    /// - Parameters:
    ///   - stateSequence: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: (optional) The identifier for grouping actions for debouncing
    func observeAsync<SomeAsyncSequence: AsyncSequence>(
        _ stateSequence: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) where SomeAsyncSequence.Element == State
}

public extension StateObserving {
    
    /// Renders the states emitted by the publisher on the view.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
    /// - Parameters:
    ///   - statePublisher: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ statePublisher: @escaping @autoclosure () -> some Publisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        observe(statePublisher(), debounced: dueTime, identifier: HashedIdentifier(file, line))
    }
    
    /// Renders the next state on the view.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ nextState: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        observe(nextState(), debounced: dueTime, identifier: HashedIdentifier(file, line))
    }
    
    /// Renders the sequence of asynchronous states returned on the view.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
    /// - Parameters:
    ///   - stateSequence: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe<SomeAsyncSequence: AsyncSequence>(
        _ stateSequence: SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) where SomeAsyncSequence.Element == State {
        observe(stateSequence, debounced: dueTime, identifier: HashedIdentifier(file, line))
    }
    
    /// Asynchronously renders the next state on the view.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
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
    
    /// Calls an async closure that returns an asynchronous sequence of states. Those states are rendered by the view in the order received.
    /// Calls to this function are debounced to prevent excessive execution from noisy events.
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

struct HashedIdentifier: Hashable {
    let uniqueValues: [AnyHashable]
    
    /// Prevents accidental key collisions between auto-generated identifiers and manually generated identifiers
    private static let uniqueKey: AnyHashable = UUID()
    
    init(_ values: AnyHashable ...) {
        uniqueValues = [Self.uniqueKey] + values
    }
}
