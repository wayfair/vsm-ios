//
//  StateSequenceBuilder.swift
//  VSM
//
//  Created by Bill Dunay on 3/17/26.
//

import Foundation

/// A type that provides a synchronous action for producing a state value.
///
/// Conform to `SyncStateProviding` to create custom helper types that can be used
/// inside a ``StateSequenceBuilder`` block. The builder recognizes conforming types
/// and classifies their output as **synchronous**, meaning the state is applied
/// inline on the current call stack before any `Task` is created.
///
/// VSM ships with ``First`` as a built-in conforming type. You can create your own
/// conforming types for specialized synchronous state production if needed.
///
/// ## Example
///
/// ```swift
/// struct Immediate<State>: SyncStateProviding {
///     let action: @Sendable () -> State
/// }
///
/// @StateSequenceBuilder
/// func load() -> StateSequence<MyState> {
///     Immediate { .loading }
///     Next { await fetchData() }
/// }
/// ```
///
/// - SeeAlso: ``AsyncStateProviding``, ``First``, ``StateSequenceBuilder``
public protocol SyncStateProviding {
    associatedtype State
    
    var action: () -> State { get }
}

/// A type that provides an asynchronous action for producing a state value.
///
/// Conform to `AsyncStateProviding` to create custom helper types that can be used
/// inside a ``StateSequenceBuilder`` block. The builder recognizes conforming types
/// and classifies their output as **asynchronous**, meaning the state is produced
/// inside a `Task` and applied after the async work completes.
///
/// VSM ships with ``Next`` as a built-in conforming type. You can create your own
/// conforming types for specialized asynchronous state production if needed.
///
/// ## Example
///
/// ```swift
/// struct Deferred<State>: AsyncStateProviding {
///     let action: @Sendable () async -> State
/// }
///
/// @StateSequenceBuilder
/// func load() -> StateSequence<MyState> {
///     MyState.loading
///     Deferred { await fetchData() }
/// }
/// ```
///
/// - SeeAlso: ``SyncStateProviding``, ``Next``, ``StateSequenceBuilder``
public protocol AsyncStateProviding {
    associatedtype State
    
    var action: () async -> State { get }
}

/// A result builder that constructs a ``StateSequence`` from a declarative list of
/// state values and asynchronous state-producing closures.
///
/// `StateSequenceBuilder` provides a Swift result-builder DSL for defining multi-step
/// state transitions. It separates states into **synchronous** and **asynchronous** categories,
/// which directly controls timing behavior when observed by an ``AsyncStateContainer``:
///
/// - **Synchronous states** (plain `State` values or ``SyncStateProviding`` conformers like ``First``)
///   are applied inline on the current call stack, in the same run-loop iteration as the call
///   to `observe()`. This ensures the view renders the new state immediately without a one-frame delay.
///
/// - **Asynchronous states** (``AsyncStateProviding`` conformers like ``Next``) are executed inside
///   a `Task` and applied after the async work completes.
///
/// > Important: Once an asynchronous expression appears in the builder block, all subsequent
/// > expressions—even plain `State` values—are treated as asynchronous to preserve declared order.
/// > Place synchronous states **before** any `Next { ... }` expressions to get synchronous application.
///
/// ## Declaring a StateSequence
///
/// Annotate a function with `@StateSequenceBuilder` and return ``StateSequence``:
///
/// ### Synchronous first state, then async work
///
/// This is the most common pattern. The first state (e.g., `.loading`) is applied synchronously
/// so SwiftUI renders it immediately, then async work produces the final state:
///
/// ```swift
/// @StateSequenceBuilder
/// func load() -> StateSequence<MyViewState> {
///     MyViewState.loading
///     Next { await fetchData() }
/// }
/// ```
///
/// ### Multiple synchronous states
///
/// All states are applied synchronously in order. Only the last state will be visible to the user
/// since all are applied in the same run-loop iteration:
///
/// ```swift
/// @StateSequenceBuilder
/// func resetAndLoad() -> StateSequence<MyViewState> {
///     MyViewState.idle
///     MyViewState.loading
///     MyViewState.loaded(cachedData)
/// }
/// ```
///
/// ### Multiple async states
///
/// All states are produced asynchronously and applied in declared order:
///
/// ```swift
/// @StateSequenceBuilder
/// func loadInStages() -> StateSequence<MyViewState> {
///     Next { await fetchBasicProfile() }
///     Next { await fetchFullProfile() }
///     Next { await fetchRecommendations() }
/// }
/// ```
///
/// ### Mixed synchronous and asynchronous states
///
/// Synchronous states before the first `Next` are applied immediately. Once a `Next` appears,
/// all subsequent states (including plain values) execute asynchronously to preserve order:
///
/// ```swift
/// @StateSequenceBuilder
/// func load() -> StateSequence<MyViewState> {
///     MyViewState.loading                        // sync: applied immediately
///     Next { await fetchItems() }                // async: runs in a Task
///     MyViewState.loaded(.init(count: 3))        // async: queued after fetchItems()
///     Next { await fetchRecommendations() }      // async: queued after the above
/// }
/// ```
///
/// ### Conditional states with `if`/`else`
///
/// The builder supports `if`/`else` branching to conditionally include states:
///
/// ```swift
/// @StateSequenceBuilder
/// func load(onMainThread: Bool) -> StateSequence<MyViewState> {
///     MyViewState.loading
///
///     if onMainThread {
///         Next { await loadOnMain() }
///     } else {
///         Next { await loadOnBackground() }
///     }
/// }
/// ```
///
/// ### Real-world example: Cart loading
///
/// From the Shopping demo app, the cart uses `@StateSequenceBuilder` to show a loading
/// indicator immediately while fetching cart products asynchronously:
///
/// ```swift
/// struct CartLoaderModel: Sendable {
///     let dependencies: Dependencies
///
///     @StateSequenceBuilder
///     func loadCart() -> StateSequence<CartViewState> {
///         CartViewState.loading
///         Next { await getCartProducts() }
///     }
///
///     @concurrent
///     private func getCartProducts() async -> CartViewState {
///         do {
///             let cart = try await dependencies.cartRepository.getCartProducts()
///             if cart.products.isEmpty {
///                 return .loadedEmpty(CartLoadedEmptyModel(dependencies: dependencies))
///             }
///             return .loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
///         } catch {
///             return .loadingError(CartLoadingErrorModel(
///                 message: "Failed to load cart: \(error)",
///                 retry: { await getCartProducts() }
///             ))
///         }
///     }
/// }
/// ```
///
/// ## Synchronous Timing Guarantee
///
/// When you place plain `State` values before any `Next { ... }` expression, those states are
/// classified as synchronous and applied inline by ``AsyncStateContainer/observe(_:)-2ybjv``
/// before a `Task` is created. This means:
///
/// ```swift
/// // In a SwiftUI view:
/// $state.observe(model.load())
/// // container.state is already .loading here — no await needed
/// ```
///
/// This eliminates the one-frame flash that would otherwise occur if `.loading` were applied
/// inside a `Task`.
///
/// - SeeAlso: ``StateSequence``, ``First``, ``Next``, ``AsyncStateContainer``
@resultBuilder
public struct StateSequenceBuilder {
    
    /// An intermediate container used during result-builder evaluation.
    ///
    /// `Container` accumulates synchronous and asynchronous state-producing actions as the
    /// builder processes each expression. It is not intended for direct use—the builder's
    /// ``buildFinalResult(_:)`` method converts it into a ``StateSequence``.
    public struct Container<State> {
        let syncActions: [() -> State]
        let asyncActions: [() async -> State]
    }
    
    /// Converts a plain `State` value into a synchronous container expression.
    ///
    /// This overload is marked `@_disfavoredOverload` so that types conforming to
    /// ``SyncStateProviding`` or ``AsyncStateProviding`` are preferred when they match.
    /// Plain state values are classified as synchronous and will be applied inline
    /// on the current call stack.
    @_disfavoredOverload
    public static func buildExpression<State>(_ expression: State) -> Container<State> {
        .init(syncActions: [{ expression }], asyncActions: [])
    }
    
    /// Converts an ``AsyncStateProviding`` conformer (e.g., ``Next``) into an asynchronous container expression.
    public static func buildExpression<Provider: AsyncStateProviding>(_ expression: Provider) -> Container<Provider.State> {
        .init(syncActions: [], asyncActions: [expression.action])
    }
    
    /// Converts a ``SyncStateProviding`` conformer (e.g., ``First``) into a synchronous container expression.
    public static func buildExpression<Provider: SyncStateProviding>(_ expression: Provider) -> Container<Provider.State> {
        .init(syncActions: [expression.action], asyncActions: [])
    }
    
    /// Combines multiple container components into a single container, preserving declared order.
    ///
    /// Synchronous actions that appear before any asynchronous action remain synchronous.
    /// Once an asynchronous action is encountered, all subsequent actions (including synchronous ones)
    /// are promoted to asynchronous to guarantee they execute in the declared order.
    public static func buildBlock<State>(_ components: Container<State>...) -> Container<State> {
        var finalSyncActions: [() -> State] = []
        var finalAsyncActions: [() async -> State] = []
        for component in components {
            if finalAsyncActions.isEmpty {
                finalSyncActions += component.syncActions
                finalAsyncActions += component.asyncActions
            } else {
                let mappedSyncActions: [() async -> State] = component.syncActions.map { syncAction in
                    { syncAction() }
                }
                finalAsyncActions += mappedSyncActions + component.asyncActions
            }
        }
        
        return .init(syncActions: finalSyncActions, asyncActions: finalAsyncActions)
    }
    
    /// Supports the first branch of an `if`/`else` statement in the builder.
    public static func buildEither<State>(first component: Container<State>) -> Container<State> {
        component
    }

    /// Supports the second branch of an `if`/`else` statement in the builder.
    public static func buildEither<State>(second component: Container<State>) -> Container<State> {
        component
    }

    /// Supports optional expressions (e.g., `if` without `else`) in the builder.
    ///
    /// When the condition is `false`, an empty container is returned, contributing no states
    /// to the final sequence.
    public static func buildOptional<State>(_ component: Container<State>?) -> Container<State> {
        component ?? .init(syncActions: [], asyncActions: [])
    }

    /// Converts the accumulated ``Container`` into a ``StateSequence``.
    ///
    /// This is called automatically by the Swift compiler as the final step of the result
    /// builder, producing the ``StateSequence`` that is returned from the annotated function.
    public static func buildFinalResult<State>(_ component: Container<State>) -> StateSequence<State> {
        StateSequence(synchronousStates: component.syncActions, states: component.asyncActions)
    }
}

/// A helper type for declaring synchronous state values inside a ``StateSequenceBuilder`` block.
///
/// `First` wraps a synchronous closure that produces a state value. When used in a
/// ``StateSequenceBuilder``, the state is classified as synchronous and applied inline
/// on the current call stack before any `Task` is created.
///
/// In most cases, you can use a plain `State` value directly instead of wrapping it in `First`.
/// Use `First` when you need to compute the state value lazily via a closure rather than
/// providing it as a literal.
///
/// ## Example
///
/// ```swift
/// @StateSequenceBuilder
/// func load() -> StateSequence<MyViewState> {
///     First { .loading }
///     Next { await fetchData() }
/// }
/// ```
///
/// This is equivalent to using a plain state value:
///
/// ```swift
/// @StateSequenceBuilder
/// func load() -> StateSequence<MyViewState> {
///     MyViewState.loading
///     Next { await fetchData() }
/// }
/// ```
///
/// - SeeAlso: ``Next``, ``SyncStateProviding``, ``StateSequenceBuilder``
public struct First<State>: SyncStateProviding {
    public let action: () -> State
    
    /// Creates a synchronous state provider with the given closure.
    ///
    /// - Parameter action: A closure that synchronously produces a state value.
    public init(action: @escaping () -> State) {
        self.action = action
    }
}

/// A helper type for declaring asynchronous state-producing closures inside a ``StateSequenceBuilder`` block.
///
/// `Next` wraps an asynchronous closure that produces a state value. When used in a
/// ``StateSequenceBuilder``, the state is classified as asynchronous and executed inside
/// a `Task`. The resulting state is applied to the ``AsyncStateContainer`` after the
/// async work completes.
///
/// ## Example
///
/// ```swift
/// @StateSequenceBuilder
/// func load() -> StateSequence<MyViewState> {
///     MyViewState.loading
///     Next { await fetchData() }
/// }
/// ```
///
/// ### Multiple async steps
///
/// Chain multiple `Next` expressions to define a multi-step async pipeline.
/// Each step runs after the previous one completes:
///
/// ```swift
/// @StateSequenceBuilder
/// func loadInStages() -> StateSequence<MyViewState> {
///     MyViewState.loading
///     Next { await fetchBasicData() }
///     Next { await fetchDetailedData() }
/// }
/// ```
///
/// ### Using `@concurrent` for background execution
///
/// Pair `Next` with `@concurrent` methods to run async work off the main thread:
///
/// ```swift
/// struct LoaderModel: Sendable {
///     @StateSequenceBuilder
///     func load() -> StateSequence<MyViewState> {
///         MyViewState.loading
///         Next { await fetchOnBackground() }
///     }
///
///     @concurrent
///     private func fetchOnBackground() async -> MyViewState {
///         // Runs on a background thread
///         let data = try? await api.fetch()
///         return .loaded(data ?? .empty)
///     }
/// }
/// ```
///
/// - SeeAlso: ``First``, ``AsyncStateProviding``, ``StateSequenceBuilder``
public struct Next<State>: AsyncStateProviding {
    public let action: () async -> State
    
    /// Creates an asynchronous state provider with the given closure.
    ///
    /// - Parameter action: An async closure that produces a state value.
    public init(action: @escaping () async -> State) {
        self.action = action
    }
}
