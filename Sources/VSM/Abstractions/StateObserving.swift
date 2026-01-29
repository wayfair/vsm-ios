//
//  StateObserving.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

#if canImport(Observation)
import AsyncAlgorithms
@preconcurrency import Combine
import Foundation

/// Protocol abstraction for `AsyncStateContainer`'s public API.
///
/// This protocol defines the contract for state observation methods that can be called on
/// `AsyncStateContainer` instances. It is used internally to provide a clear interface
/// boundary and enable potential future testing or alternative implementations.
///
/// ## Maintainer Notes
///
/// - All methods must be called from a `@MainActor` context due to the protocol's
///   `@MainActor` requirement
/// - The protocol excludes initialization methods as those are implementation-specific
/// - When adding new public observation methods to `AsyncStateContainer`, ensure they
///   are also added to this protocol to maintain consistency
/// - This protocol is internal and not part of the public API - it exists solely for
///   internal architecture and maintainability purposes
@MainActor
public protocol StateObserving<State> {
    associatedtype State: Sendable
    
    // MARK: - Observe Single State Change Functions
    
    /// Immediately updates the container's state to the provided value.
    ///
    /// Cancels any ongoing state observations and synchronously updates the state on the main thread.
    func observe(_ nextState: State)
    
    /// Observes and updates the state using an asynchronous closure.
    ///
    /// Executes the provided closure asynchronously to produce the next state. The closure can run
    /// on any thread, but the resulting state change is guaranteed to occur on the main thread.
    func observe(_ nextStateClosure: @escaping @Sendable () async -> State)
    
    /// Refreshes the state using an asynchronous closure, suspending until complete.
    ///
    /// Executes the provided closure asynchronously to produce the next state, suspending the caller
    /// until the state has been produced and applied. Designed for pull-to-refresh functionality.
    func refresh(state nextState: @escaping @Sendable () async -> State) async
    
    // MARK: - Observe Sequence of State Changes Functions
    
    /// Observes and updates the state through a sequence of state values.
    ///
    /// Consumes a `StateSequence` that produces multiple state values over time. Each state value
    /// is applied as it becomes available from the sequence.
    func observe(_ stateSequence: StateSequence<State>)
    
    /// Observes and updates the state from an `AsyncStream`.
    ///
    /// Consumes an `AsyncStream` that emits state values over time. Each state value is applied
    /// as it becomes available from the stream.
    func observe(_ stream: AsyncStream<State>)
    
    /// Observes and updates the state from a generic `AsyncSequence` that never throws.
    ///
    /// Consumes any `AsyncSequence` whose element type is `State` and failure type is `Never`.
    /// Each state value is applied as it becomes available from the sequence.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    func observe<SomeAsyncSequence: AsyncSequence>(_ sequence: SomeAsyncSequence)
    where SomeAsyncSequence.Element == State, SomeAsyncSequence.Failure == Never
    
    /// Observes and updates the state from a Combine `Publisher`.
    ///
    /// Consumes a Combine `Publisher` that emits state values over time. Each state value is applied
    /// as it becomes available from the publisher. Exists for ease of migration from VSM to AsyncVSM.
    func observe(_ publisher: some Publisher<State, Never>)
    
    // MARK: - Observe Sequence of State Changes Functions (Debounced)
    
    /// Observes and updates the state through a debounced sequence of state values.
    ///
    /// Consumes a `StateSequence` that produces multiple state values over time. The sequence is
    /// debounced, meaning rapid state changes will be throttled - only the most recent state value
    /// will be applied after a quiescence period has elapsed.
    func observe(_ stateSequence: StateSequence<State>, debounced duration: Duration)
    
    /// Observes and updates the state from a debounced `AsyncStream`.
    ///
    /// Consumes an `AsyncStream` that emits state values over time. The stream is debounced, meaning
    /// rapid state changes will be throttled - only the most recent state value will be applied
    /// after a quiescence period has elapsed.
    func observe(_ stream: AsyncStream<State>, debounced duration: Duration)
    
    /// Observes and updates the state from a debounced generic `AsyncSequence` that never throws.
    ///
    /// Consumes any `AsyncSequence` whose element type is `State` and failure type is `Never`.
    /// The sequence is debounced, meaning rapid state changes will be throttled - only the most
    /// recent state value will be applied after a quiescence period has elapsed.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    func observe<SomeAsyncSequence: AsyncSequence & Sendable>(
        _ sequence: SomeAsyncSequence,
        debounced duration: Duration
    ) where SomeAsyncSequence.Element == State, SomeAsyncSequence.Failure == Never
    
    /// Observes and updates the state from a debounced Combine `Publisher`.
    ///
    /// Consumes a Combine `Publisher` that emits state values over time. The publisher's values are
    /// debounced, meaning rapid state changes will be throttled - only the most recent state value
    /// will be applied after a quiescence period has elapsed. Exists for ease of migration from VSM to AsyncVSM.
    func observe(_ publisher: some Publisher<State, Never>, debounced duration: Duration)
}

#endif
