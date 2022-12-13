import Combine

/// Conforms a SwiftUI or UIKit view to the VSM pattern.
///
/// Conforming a SwiftUI `View`, `UIView`, or `UIViewController` to ``ViewStateRendering`` aids in adoption of the VSM pattern.
/// This will provide the view with its own ``StateContainer`` by way of the ``container`` property.
/// Conformance also grants access to convenient State and Actions helpers, such as ``state``, ``bind(_:to:)-p7pn``, and ``observe(_:)-7vht3``.
///
/// SwiftUI Example
/// ```swift
/// struct UserProfileView: View, ViewStateRendering {
///     var container = StateContainer<UserProfileViewState>(state: .initialized(LoaderModel()))
///     var body: some View {
///         switch state {
///         case .initialized, .loading:
///             ProgressView()
///                 .onAppear {
///                     if case .initialized(let loaderModel) = state {
///                         observe(loaderModel.load())
///                     }
///                 }
///         case .loaded(let loadedModel):
///             Text(loadedModel.username)
///             Button("Reload") {
///                 observe(loadedModel.reload())
///             }
///         }
///     }
/// }
/// ```
///
/// UIKit Example
/// ```swift
/// class UserProfileViewController: UIViewController, ViewStateRendering {
///     var container = StateContainer<UserProfileViewState>(state: .initialized(LoaderModel()))
///     var stateSubscription: AnyCancellable?
///
///     lazy var loadingView: UIProgressView = UIProgressView()
///     lazy var usernameLabel: UILabel = UILabel()
///     lazy var reloadButton: UIButton = UIButton(primaryAction: .init(title: "Save", handler: { [weak self] _ in
///         if case .loaded(let loadedModel) = self?.state {
///             self?.observe(loadedModel.reload())
///         }
///     }))
///
///     override func viewDidLoad() {
///         super.viewDidLoad()
///         // < configure views here >
///         stateSubscription = container.$state.sink { [weak self] in self?.render(state: $0) }
///     }
///
///     override func viewDidAppear(_ animated: Bool) {
///         super.viewDidAppear(animated)
///         if case .initialized(let loaderModel) = state {
///             observe(loaderModel.load())
///         }
///     }
///
///     func render(state: ViewState) {
///         switch state {
///         case .initialized, .loading:
///             loadingView.isHidden.toggle()
///         case .loaded(let loadedModel):
///             usernameLabel.text = loadedModel.username
///             reloadButton.isHidden.toggle()
///         }
///     }
/// }
/// ```
public protocol ViewStateRendering {
    
    /// The type that represents your View's state.
    ///
    /// This type is usually an enum with associated `Model` values for complex views.
    /// For simpler views, this can be a `struct` or any value type.
    /// `class`es (including `ObservableObject`s are supported, but not recommended.
    associatedtype SomeViewState
    
    /// Contains the current `ViewState` value for rendering in the `View`.
    var container: StateContainer<SomeViewState> { get }
    
    /// UIKit Only - Renders the current state change.
    ///
    /// This is not required in Swift UI. Add `@StateObject` or `@ObservedObject` to the `container` property to automatically render state changes in a SwiftUI view.
    func render()
}

// MARK: - SwiftUI Extension

public extension ViewStateRendering where Self: View {
    
    /// This is not required in Swift UI. Add `@StateObject` or `@ObservedObject` to the `container` property to automatically render state changes in a SwiftUI view.
    func render() { /* no-op */ }
}

//MARK: - State Extension

public extension ViewStateRendering {
    
    /// Convenience accessor for the `StateContainer`'s `state` property.
    var state: SomeViewState {
        container.state
    }
}

// MARK: - Observe Extensions

public extension ViewStateRendering {
    
    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the state publisher emitted as a result of invoking some action
    func observe(_ stateChangePublisher: AnyPublisher<SomeViewState, Never>) {
        container.observe(stateChangePublisher)
    }

    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the state emitted as a result of invoking some asynchronous action
    func observe(_ awaitState: @escaping () async -> SomeViewState) {
        container.observe(awaitState)
    }
    
    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the states emitted as a result of invoking some asynchronous action that returns an asynchronous sequence
    func observe<StateSequence: AsyncSequence>(_ awaitStateSequence: @escaping () async -> StateSequence) where StateSequence.Element == SomeViewState {
        container.observe(awaitStateSequence)
    }

    /// Convenience accessor for the `StateContainer`'s `observe` function.
    /// Observes the state emitted as a result of invoking some synchronous action
    func observe(_ nextState: @autoclosure @escaping () -> SomeViewState) {
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
    func bind<Value>(_ stateKeyPath: KeyPath<SomeViewState, Value>, to observedSetter: @escaping (SomeViewState, Value) -> SomeViewState) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **This doesn't work when`ViewState` is an enum**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<SomeViewState, Value>, to observedSetter: @escaping (SomeViewState) -> (Value) -> SomeViewState) -> Binding<Value> {
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
    func bind<Value>(_ stateKeyPath: KeyPath<SomeViewState, Value>, to observedSetter: @escaping (SomeViewState, Value) async -> SomeViewState) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **Not intended for use when`ViewState` is an enum.**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<SomeViewState, Value>, to observedSetter: @escaping (SomeViewState) -> (Value) async -> SomeViewState) -> Binding<Value> {
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
    func bind<Value>(_ stateKeyPath: KeyPath<SomeViewState, Value>, to observedSetter: @escaping (SomeViewState, Value) -> AnyPublisher<SomeViewState, Never>) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **Not intended for use when`ViewState` is an enum.**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<SomeViewState, Value>, to observedSetter: @escaping (SomeViewState) -> (Value) -> AnyPublisher<SomeViewState, Never>) -> Binding<Value> {
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
        _ stateChangePublisherAction: @escaping @autoclosure () -> AnyPublisher<SomeViewState, Never>,
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
        _ stateChangePublisherAction: @escaping @autoclosure () ->  AnyPublisher<SomeViewState, Never>,
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
        _ stateChangeAsyncAction: @escaping () async -> SomeViewState,
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
        _ stateChangeAsyncAction: @escaping () async -> SomeViewState,
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
    ) where SomeAsyncSequence.Element == SomeViewState {
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
    ) where SomeAsyncSequence.Element == SomeViewState {
        container.observe(stateChangeAsyncSequenceAction, debounced: dueTime, identifier: identifier)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangeAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangeAction: @escaping @autoclosure () -> SomeViewState,
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
        _ stateChangeAction: @escaping @autoclosure () -> SomeViewState,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        container.observe(stateChangeAction(), debounced: dueTime, identifier: identifier)
    }
    
}
