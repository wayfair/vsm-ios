//
//  StateSequence.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

import Foundation

/// Emits multiple `State`s as an `AsyncSequence`
///
/// Use `StateSequence` with ``AsyncStateContainer`` to emit a series of states from a single action.
/// Create one with either a mix of a synchronous first state and async remainder closures
/// (see ``init(first:rest:)``), or with all-async closures (see ``init(_:)``).
///
/// ## Example
///
/// ```swift
/// func load() -> StateSequence<ExampleViewState> {
///     StateSequence({ .loading }, { await .loaded(getData()) })
/// }
/// ```
public struct StateSequence<State: Sendable>: AsyncSequence, AsyncIteratorProtocol {
    public typealias Element = State
    
    /// An optional synchronous closure that produces the first state immediately.
    /// When non-nil, `AsyncStateContainer` will apply this state inline (before creating a Task)
    /// to eliminate the run loop delay between calling `observe` and the first state change.
    let synchronousFirst: State?
    
    /// The remaining async closures to be executed after the optional synchronous first closure.
    let remainingClosures: [@Sendable () async -> State]
    
    /// All closures flattened into a single async sequence for the iterator path.
    /// If `synchronousFirst` is set, it is wrapped as an async closure and prepended here,
    /// so `next()` can simply drain this array without any consumed-flag bookkeeping.
    private var iterator: IndexingIterator<[@Sendable () async -> State]>
    
    /// Creates a `StateSequence` where the first state is applied synchronously and the
    /// remaining closures run asynchronously.
    ///
    /// Use this initializer when you want the first state change to be applied immediately—in
    /// the same run loop iteration as the call to ``AsyncStateContainer/observe(_:)-StateSequence``—
    /// rather than after a `Task` has been scheduled.
    ///
    /// This avoids a one-frame rendering gap that can occur with the all-async initializer
    /// (``init(_:)``): without a synchronous first state, SwiftUI may render one frame of the
    /// previous state before the first async closure executes, which can cause a brief visual
    /// flash or flicker when your view first appears.
    ///
    /// ## When to use this initializer
    ///
    /// Prefer `init(first:rest:)` when:
    /// - Your action immediately transitions to a transient state (e.g. `.loading`) before
    ///   performing async work.
    /// - A one-frame flash of the prior state would be visible or disruptive to the user.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func load() -> StateSequence<ExampleViewState> {
    ///     StateSequence(
    ///         first: .loading,
    ///         rest: { await self.fetchItems() }
    ///     )
    /// }
    /// ```
    ///
    /// Here, `.loading` is set synchronously before any `Task` is created, so the very first
    /// frame the view renders will already show the loading indicator. The `fetchItems()` call
    /// then runs asynchronously and emits the final state when complete.
    ///
    /// - Parameters:
    ///   - first: The first state value, applied synchronously before any async work begins.
    ///   - rest: Zero or more async closures that produce subsequent states in order.
    public init(first: State, rest: @Sendable () async -> State...) {
        self.synchronousFirst = first
        self.remainingClosures = rest
        self.iterator = rest.makeIterator()
    }
    
    /// Creates a `StateSequence` where all closures are async.
    ///
    /// Each closure is executed in order, and the resulting state is applied to the container
    /// as each closure completes. Because all closures are async, the first state change
    /// occurs after a `Task` has been scheduled, which means SwiftUI may render one frame of
    /// the previous state before the first closure executes.
    ///
    /// If this causes a visible flash or flicker when your view first appears, use
    /// ``init(first:rest:)`` instead to apply the first state synchronously.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func load() -> StateSequence<ExampleViewState> {
    ///     StateSequence(
    ///         { .loading },
    ///         { await self.fetchItems() }
    ///     )
    /// }
    /// ```
    ///
    /// - Parameter states: One or more async closures that produce states in order.
    public init(_ states: @Sendable () async -> State...) {
        self.synchronousFirst = nil
        self.remainingClosures = states
        self.iterator = states.makeIterator()
    }
    
    mutating public func next() async -> State? {
        guard !Task.isCancelled else { return nil }
        return await iterator.next()?()
    }

    public func makeAsyncIterator() -> Self { self }
}
