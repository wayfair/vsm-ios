//
//  ViewStateStore.swift
//  VSM
//
//  Lives in Sources/VSM because AsyncStateContainer's initializer is internal.
//

#if canImport(SwiftUI)
import Foundation
import OSLog
import SwiftUI

/// Owns ``AsyncStateContainer`` instances on behalf of child views that live inside lazy containers
/// (`LazyVStack`, `LazyVGrid`, `List`).
///
/// SwiftUI may discard the `@State` storage of rows that scroll out of a lazy container. A child that
/// uses ``ViewState`` loses its container when that happens and restarts from its initial state. Keeping
/// the containers in a store owned by an ancestor outside the lazy container means a re-created row
/// receives the same container, still in whatever state it had reached.
///
/// Containers are keyed by the child's state type plus an id taken from the row's data. Use the same
/// stable id the `ForEach` uses. Never use an array index or a value generated during rendering.
///
/// The store is intentionally not `@Observable`. Each container is already observable, so a child's
/// state change invalidates only that child. Observing the store would add a path to invalidate the
/// parent, and inserting containers while `ForEach` builds its rows would mutate tracked state
/// mid-update.
///
/// ```swift
/// struct ProductFeedView: View {
///     @ViewState var state: ProductFeedViewState = .initialized(.init())
///     @State private var rowStates = ViewStateStore()
///
///     var body: some View {
///         // ...
///         LazyVStack {
///             ForEach(products) { product in
///                 ProductCardView(container: rowStates.container(
///                     for: product.id,
///                     initialState: .initialized(.init(productID: product.id))
///                 ))
///             }
///         }
///         .onChange(of: products.map(\.id), initial: true) { _, ids in
///             rowStates.retainOnly(ids)
///         }
///     }
/// }
/// ```
@MainActor
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
public final class ViewStateStore {
    private struct Key: Hashable {
        let stateType: ObjectIdentifier
        let id: AnyHashable
    }

    private var containers: [Key: AnyObject] = [:]

    public init() {}

    /// The number of containers currently retained.
    public var count: Int { containers.count }

    /// Returns the retained container for `id`, creating it on first access.
    ///
    /// `initialState` and the logging configuration are used only when no container exists for the key,
    /// so building state models here costs nothing on later body passes.
    ///
    /// - Parameters:
    ///   - id: A stable identifier from the row's data, usually the same id `ForEach` uses.
    ///   - initialState: The state a newly created container starts in.
    ///   - subsystem: The subsystem identifier for logging (defaults to "com.wayfair.vsm").
    ///   - observedViewType: The child view type, used as the logging category.
    ///   - loggingEnabled: Enables debug logging of this container's state changes.
    ///   - signpostsEnabled: Enables Instruments signposts for this container's transitions.
    public func container<ID: Hashable, State>(
        for id: ID,
        initialState: @autoclosure () -> State,
        subsystem: String = "com.wayfair.vsm",
        observedViewType: Any.Type? = nil,
        loggingEnabled: Bool = false,
        signpostsEnabled: Bool = false
    ) -> AsyncStateContainer<State> {
        let key = Key(stateType: ObjectIdentifier(State.self), id: AnyHashable(id))
        if let existing = containers[key] as? AsyncStateContainer<State> {
            return existing
        }

        // Mirrors ViewState.init(wrappedValue:) so hosted containers log and trace the same way.
        var category = "VSM View"
        if let observedViewType {
            category = String(describing: observedViewType)
        }
        let container = AsyncStateContainer(
            state: initialState(),
            logger: OSLog(subsystem: subsystem, category: category),
            loggingEnabled: loggingEnabled,
            signpostsEnabled: signpostsEnabled
        )
        containers[key] = container
        return container
    }

    /// Releases every container whose id is not in `ids`, across all state types.
    ///
    /// A released container deinits once nothing else references it, which cancels its running
    /// observation. Pass the same id values used with ``container(for:initialState:subsystem:observedViewType:loggingEnabled:signpostsEnabled:)``,
    /// including any composite key type.
    public func retainOnly<ID: Hashable>(_ ids: some Sequence<ID>) {
        let keep = Set(ids.map { AnyHashable($0) })
        containers = containers.filter { keep.contains($0.key.id) }
    }

    /// Releases the container for one id and state type, so the next access starts from a fresh initial state.
    public func removeContainer<ID: Hashable, State>(for id: ID, as stateType: State.Type) {
        containers[Key(stateType: ObjectIdentifier(stateType), id: AnyHashable(id))] = nil
    }

    /// Releases every container.
    public func removeAll() {
        containers.removeAll()
    }
}

/// A property wrapper for a view whose ``AsyncStateContainer`` is owned by an ancestor, such as a
/// ``ViewStateStore``.
///
/// It exposes the same surface as ``ViewState``: `state` is the current value and `$state` is the
/// container, so `$state.observe(...)` and `$state.bind(...)` are unchanged. Unlike ``ViewState``, it
/// holds the container in a plain stored property with no SwiftUI `@State`, so there is nothing for
/// SwiftUI to discard when a lazy container drops the row.
///
/// Observation still works: reading `state` in `body` reads ``AsyncStateContainer/state``, which the
/// Observation framework tracks per container instance.
///
/// ```swift
/// struct ProductCardView: View {
///     @HostedViewState var state: ProductCardViewState
///
///     init(container: AsyncStateContainer<ProductCardViewState>) {
///         _state = HostedViewState(container: container)
///     }
///
///     var body: some View {
///         switch state {
///         case .initialized(let loaderModel):
///             ProgressView()
///                 .onAppear { $state.observe(loaderModel.load()) }
///         case .loaded(let loadedModel):
///             Text(loadedModel.title)
///         }
///     }
/// }
/// ```
///
/// > Important: Never create the container inside the child, for example in a default argument or
/// > `init`. View structs are rebuilt on every parent body pass, so the child would get a new state
/// > machine each time. The container must come from an owner that outlives the view.
@MainActor
@propertyWrapper
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
public struct HostedViewState<State> {
    public let container: AsyncStateContainer<State>

    public init(container: AsyncStateContainer<State>) {
        self.container = container
    }

    public var wrappedValue: State {
        container.state
    }

    public var projectedValue: AsyncStateContainer<State> {
        container
    }
}
#endif
