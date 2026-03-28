//
//  StateSequence.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

import Foundation

/// A sequence of state values emitted over time, conforming to `AsyncSequence`.
///
/// `StateSequence` is the primary mechanism in VSM for producing multiple state changes from
/// a single action. When observed by an ``AsyncStateContainer``, each state in the sequence
/// is applied to the container in declared order as it becomes available.
///
/// ## Creating a StateSequence
///
/// There are three ways to create a `StateSequence`:
///
/// ### 1. Using `@StateSequenceBuilder` (recommended)
///
/// The ``StateSequenceBuilder`` result-builder DSL provides the most expressive syntax and
/// supports synchronous first-state timing. Plain `State` values placed before any `Next { ... }`
/// expression are applied **synchronously** by the container, avoiding a one-frame flash:
///
/// ```swift
/// @StateSequenceBuilder
/// func load() -> StateSequence<MyViewState> {
///     MyViewState.loading                  // applied synchronously
///     Next { await fetchData() }           // applied after async work completes
/// }
/// ```
///
/// The builder also supports `if`/`else` branching, multiple `Next` steps, and mixed
/// sync/async states. See ``StateSequenceBuilder`` for full details.
///
/// ### 2. Using array-literal syntax
///
/// The `ExpressibleByArrayLiteral` conformance lets you return an array of closures directly.
/// All closures are treated as asynchronous:
///
/// ```swift
/// func load() -> StateSequence<MyViewState> {
///     [
///         { .loading },
///         { await fetchData() }
///     ]
/// }
/// ```
///
/// ### 3. Using the variadic initializer
///
/// Pass async closures directly to ``init(_:)``:
///
/// ```swift
/// func load() -> StateSequence<MyViewState> {
///     StateSequence(
///         { .loading },
///         { await fetchData() }
///     )
/// }
/// ```
///
/// ## Synchronous vs. Asynchronous First State
///
/// The choice of creation method determines whether the first state is applied synchronously
/// or asynchronously by ``AsyncStateContainer``:
///
/// | Creation method | First state timing |
/// |---|---|
/// | `@StateSequenceBuilder` with plain `State` values before `Next` | **Synchronous** — applied inline before a `Task` is created |
/// | Array literal (`[{ ... }, { ... }]`) | Asynchronous — applied inside a `Task` |
/// | Variadic initializer (`StateSequence({ ... }, { ... })`) | Asynchronous — applied inside a `Task` |
///
/// For your view's initial observation (typically in `onAppear`), prefer `@StateSequenceBuilder`
/// to ensure the first state (e.g., `.loading`) appears on the very first frame:
///
/// ```swift
/// // In your SwiftUI view:
/// .onAppear {
///     $state.observe(model.load())  // .loading is visible immediately
/// }
/// ```
///
/// For user-initiated actions on an already-visible view (button taps, pull-to-refresh),
/// the async forms are fine since a brief scheduling delay is imperceptible.
///
/// ## Cancellation
///
/// `StateSequence` respects Swift's cooperative cancellation. If the parent `Task` is
/// cancelled, iteration stops and no further states are emitted.
///
/// - SeeAlso: ``StateSequenceBuilder``, ``AsyncStateContainer``, ``First``, ``Next``
public struct StateSequence<State: Sendable>: AsyncSequence, AsyncIteratorProtocol {
    public typealias Element = State
    
    /// Closures that produce state values synchronously.
    ///
    /// When a `StateSequence` is created via ``StateSequenceBuilder``, plain `State` values
    /// that appear before any ``Next`` expression are stored here. The ``AsyncStateContainer``
    /// applies these inline on the current call stack before creating a `Task`.
    let synchronousStateActions: [@Sendable () -> State]
    
    /// Closures that produce state values asynchronously.
    ///
    /// These closures are executed sequentially inside a `Task` by the ``AsyncStateContainer``.
    /// Each closure runs after the previous one completes, and the resulting state is applied
    /// to the container on the main thread.
    let states: [@Sendable () async -> State]
    
    /// Internal iterator over the synchronous closures.
    ///
    /// Drives the first portion of `AsyncIteratorProtocol` conformance. The `next()` method
    /// drains this iterator before moving on to the async closures.
    private var syncIterator: IndexingIterator<[@Sendable () -> State]>

    /// Internal iterator over the async closures.
    ///
    /// Drives the `AsyncIteratorProtocol` conformance. The `next()` method drains this
    /// iterator sequentially, executing each closure and returning its result.
    private var iterator: IndexingIterator<[@Sendable () async -> State]>

    /// Creates a `StateSequence` from a variadic list of async closures.
    ///
    /// All closures are treated as asynchronous. When observed by an ``AsyncStateContainer``,
    /// they execute sequentially inside a `Task`.
    ///
    /// - Parameter states: One or more async closures, each producing the next state value.
    ///
    /// ## Example
    ///
    /// ```swift
    /// func load() -> StateSequence<MyViewState> {
    ///     StateSequence(
    ///         { .loading },
    ///         { await fetchData() }
    ///     )
    /// }
    /// ```
    public init(_ states: @Sendable () async -> State...) {
        self.synchronousStateActions = []
        self.states = states
        syncIterator = self.synchronousStateActions.makeIterator()
        iterator = states.makeIterator()
    }

    /// Creates a `StateSequence` with separate synchronous and asynchronous state actions.
    ///
    /// This initializer is used internally by ``StateSequenceBuilder/buildFinalResult(_:)``
    /// to construct sequences that have synchronous first states. You typically won't call
    /// this directly—use `@StateSequenceBuilder` or the variadic ``init(_:)`` instead.
    ///
    /// - Parameters:
    ///   - synchronousStates: Closures that produce state values synchronously. Applied inline
    ///     by the ``AsyncStateContainer`` before any `Task` is created.
    ///   - states: Closures that produce state values asynchronously. Executed sequentially
    ///     inside a `Task`.
    public init(synchronousStates: [@Sendable () -> State], states: [@Sendable () async -> State]) {
        self.synchronousStateActions = synchronousStates
        self.states = states
        syncIterator = synchronousStates.makeIterator()
        iterator = states.makeIterator()
    }

    /// Returns the next state in the sequence, or `nil` if the sequence is exhausted or cancelled.
    ///
    /// This method first yields any synchronous states, then executes async closures
    /// sequentially and returns their results. If the current `Task` has been cancelled,
    /// returns `nil` immediately without executing the closure.
    mutating public func next() async throws -> State? {
        guard !Task.isCancelled else { return nil }
        if let syncAction = syncIterator.next() {
            return syncAction()
        }
        return await iterator.next()?()
    }
    
    public func makeAsyncIterator() -> Self { self }
}

/// Allows creating a ``StateSequence`` using array-literal syntax.
///
/// This conformance lets you return an array of async closures directly from a function
/// that returns ``StateSequence``, without needing the ``StateSequenceBuilder`` DSL or
/// calling an initializer explicitly.
///
/// > Important: All closures in an array literal are treated as **asynchronous**, even if the
/// > closure body is synchronous. This means the first state is applied inside a `Task`, not
/// > inline on the current call stack. If you need the first state applied synchronously
/// > (e.g., to avoid a one-frame flash on initial `onAppear`), use the ``StateSequenceBuilder``
/// > instead.
///
/// ## Basic usage
///
/// Return an array of closures that each produce the next state:
///
/// ```swift
/// func load() -> StateSequence<MyViewState> {
///     [
///         { .loading },
///         { await fetchData() }
///     ]
/// }
/// ```
///
/// ## Mixing synchronous and async closures
///
/// You can freely mix closures that do synchronous work with closures that `await`.
/// All closures execute in declared order:
///
/// ```swift
/// func load() -> StateSequence<MyViewState> {
///     [
///         { .loading },
///         { await fetchBasicData() },
///         { .loaded(.init(count: 2)) },
///         { await fetchDetailedData() },
///     ]
/// }
/// ```
///
/// ## Shared reload actions via protocols
///
/// Array-literal syntax works well for protocol extensions that share actions across
/// multiple state models:
///
/// ```swift
/// protocol CartReloadable: Sendable {
///     var dependencies: CartLoadedModel.Dependencies { get }
/// }
///
/// extension CartReloadable {
///     func reloadCart() -> StateSequence<CartViewState> {
///         [
///             { .loading },
///             { await getCartProducts() }
///         ]
///     }
/// }
/// ```
extension StateSequence: ExpressibleByArrayLiteral {
    public init(arrayLiteral elements: @Sendable () async -> State...) {
        self.init(synchronousStates: [], states: elements)
    }
}
