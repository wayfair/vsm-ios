//
//  RenderedViewState.swift
//
//
//  Created by Albert Bori on 12/23/22.
//

#if canImport(UIKit)
import Combine
import Foundation
import OSLog

/// **(UIKit Only)** Manages the view state for a UIView or UIViewController in VSM. Automatically calls `render()` when the view state changes.
///
/// This property wrapper encapsulates a view's state property with an underlying `StateContainer` to provide the current view state .
/// A subset of `StateContainer` members are available through the `$` prefix, such as `observe(...)` and `bind(...)`.
///
/// **Deprecation Notice**
///
/// This property wrapper is deprecated starting with iOS 26.0, iPadOS 26.0, macOS 26.0, tvOS 26.0, visionOS 2.0, and Mac Catalyst 26.0.
/// Apple introduced native property observation tracking for `UIViewController` and `UIView` in iOS 26, making this wrapper unnecessary.
///
/// **Migration**
///
/// Migrate to the ``ViewState`` property wrapper instead, which leverages Apple's native observation tracking.
/// Replace your `render()` method with an override of the `updateProperties()` method, which provides the same functionality
/// but uses Apple's built-in observation system.
///
/// For more information about Apple's observation tracking implementation, see:
/// - [Updating Views Automatically with Observation Tracking](https://developer.apple.com/documentation/uikit/updating-views-automatically-with-observation-tracking)
/// - [WWDC 2025: What's new in UIKit](https://developer.apple.com/videos/play/wwdc2025/243/) (session 243, starting at 10:21)
///
/// **Usage**
///
/// Decorate your view state property with this property wrapper.
///
/// Direct Initialization Example:
///
/// ```swift
/// class MyViewController: UIViewController {
///     @RenderedViewState var state: MyViewState
///
///     init(state: MyViewState) {
///         _state = .init(wrappedValue: state, render: Self.render)
///         super.init(bundle: nil, nib: nil)
///     }
///
///     func render() {
///         if state.someValue {
///             ...
///             $state.observe(state.someAction())
///         }
///     }
/// }
/// ```
///
/// Implicit Initialization Example:
///
/// ```swift
/// class MyViewController: UIViewController {
///     @RenderedViewState(render: MyViewController.render)
///     var state: MyViewState = MyViewState()
///
///     func render() {
///         if state.someValue {
///             ...
///             $state.observe(state.someAction())
///         }
///     }
/// }
/// ```
///
/// ## Debugging
///
/// You can enable debug logging to trace state changes in the Console. This is useful during development
/// to understand when and how your view's state is changing. Logging is disabled by default.
///
/// To enable logging, set `loggingEnabled` to `true`:
///
/// ```swift
/// class MyViewController: UIViewController {
///     @RenderedViewState(render: MyViewController.render, loggingEnabled: true)
///     var state: MyViewState = .initialized(.init())
///
///     func render() {
///         // ...
///     }
/// }
/// ```
///
/// When enabled, you'll see debug messages in the Console showing state transitions, which can help
/// diagnose unexpected behavior or verify that actions are triggering the correct state changes.
@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macOS, introduced: 14.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(tvOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(visionOS, introduced: 1.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macCatalyst, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(watchOS, unavailable, message: "watchOS only uses SwiftUI, so this UIKit-specific property wrapper is not available")
@MainActor
@propertyWrapper
public struct RenderedViewState<State> {
    
    let renderedContainer: RenderedContainer
    
    // MARK: Encapsulating Properties

    public var wrappedValue: State {
        get { projectedValue.container.state }
    }

    public var projectedValue: RenderedContainer {
        get { renderedContainer }
    }
    
    // MARK: Initializers
    
    /// **(UIKit only)** Instantiates the rendered view state with an initial value.
    ///
    /// - Warning: This property wrapper is deprecated starting with iOS 26.0. Use ``ViewState`` instead and override `updateProperties()` to replace your `render()` method.
    ///
    /// Example:
    ///
    /// ```swift
    /// class MyViewController: UIViewController {
    ///     @RenderedViewState var state: MyViewState
    ///
    ///     init(state: MyViewState) {
    ///         _state = .init(wrappedValue: state, render: Self.render)
    ///         super.init(bundle: nil, nib: nil)
    ///     }
    ///
    ///     func render() {
    ///         if state.someValue {
    ///             ...
    ///             $state.observe(state.someAction())
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameters:
    ///   - wrappedValue: The view state to be managed by the state container.
    ///   - render: The function to call when the view state _did change_.
    ///   - subsystem: The subsystem identifier for logging (defaults to "com.wayfair.vsm").
    ///   - loggingEnabled: When `true`, enables debug logging of state changes to the Console. Defaults to `false`.
    public init<Parent>(
        wrappedValue: State,
        render: @escaping (Parent) -> () -> (),
        subsystem: String = "com.wayfair.vsm",
        loggingEnabled: Bool = false
    )
    where Parent: AnyObject {
        let observedViewType = String(describing: Parent.self)
        let anyRender: (AnyObject, State) -> () = { parent, state in
            guard let parent = parent as? Parent else { return }
            render(parent)()
        }
        
        self.renderedContainer = RenderedContainer(
            container: AsyncStateContainer(
                state: wrappedValue,
                logger: OSLog(subsystem: subsystem, category: observedViewType),
                loggingEnabled: loggingEnabled
            ),
            render: anyRender
        )
    }
    
    public init<Parent>(
        wrappedValue: State,
        render: @escaping (Parent) -> (State) -> (),
        subsystem: String = "com.wayfair.vsm",
        loggingEnabled: Bool = false
    )
    where Parent: AnyObject {
        let observedViewType = String(describing: Parent.self)
        let anyRender: (AnyObject, State) -> () = { parent, state in
            guard let parent = parent as? Parent else { return }
            render(parent)(state)
        }
        
        self.renderedContainer = RenderedContainer(
            container: AsyncStateContainer(
                state: wrappedValue,
                logger: OSLog(subsystem: subsystem, category: observedViewType),
                loggingEnabled: loggingEnabled
            ),
            render: anyRender
        )
    }
    
    // MARK: Automatic Rendering

    /// Automatically calls `render()` when the state changes on any class that has a property decorated with this property wrapper. (Intended for UIKit only)
    ///
    /// For the behavior to take effect, the property's parent type must be a `class` that provides a `render` value on initialization and will usually be some sort of `UIView` or `UIViewController` subclass.
    /// This is helpful for implementing VSM with **UIKit** views and view controllers in that it handles the "auto-updating" behavior that comes implicitly with SwiftUI.
    ///
    /// Maintenance Note: The Swift runtime automatically calls this subscript each time the wrapped property is accessed.
    /// It can be called many, many times. Any operations within the subscript must be performant, thread-safe, and duplication-resistant.
    public static subscript<ParentClass>(
        _enclosingInstance instance: ParentClass,
        wrapped wrappedKeyPath: KeyPath<ParentClass, State>,
        storage storageKeyPath: KeyPath<ParentClass, RenderedViewState<State>>
    ) -> State
    where ParentClass: AnyObject & Sendable {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            wrapper.projectedValue.startRendering(on: instance)
            return wrapper.wrappedValue
        }
    }
}

// MARK: - RenderedViewState

@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macOS, introduced: 14.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(tvOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(visionOS, introduced: 1.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macCatalyst, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(watchOS, unavailable, message: "watchOS only uses SwiftUI, so this UIKit-specific property wrapper is not available")
public extension RenderedViewState {
    /// Provides functions for observing and rendering state changes in UIKit views and view controllers
    ///
    /// - Warning: This type is deprecated starting with iOS 26.0. Use ``ViewState`` instead, which leverages Apple's native observation tracking.
    @MainActor
    struct RenderedContainer {
        /// The wrapped state container for managing changes in state
        let container: AsyncStateContainer<State>
        /// Implicitly used by UIKit views to automatically call the provided function when the state changes
        let render: (AnyObject, State) -> Void
        
        /// Subscribes a UIKit view or view controller to render each state change. If not called, rendering will automatically start when the `state` property is first accessed.
        ///
        /// This function provides an option to control when the view begins rendering the current and subsequent states.
        /// This can be especially important for views that inherently progress state by rendering the current state.
        /// Directly calling the `render()` function on a view before the state rendering subscription is started will call the `render()` function twice.
        /// Use this function to prevent that scenario.
        ///
        /// If the view or view controller accesses the `state` property in any of the early view lifecycle events (`viewDidLoad`, etc.), then calling this function is usually not necessary.
        ///
        /// Note that calling this function after accessing the `state` will have no effect.
        /// Also, calling this function additional times will have no effect.
        /// - Parameter view: The view on which to subscribe
        @MainActor
        public func startRendering<View>(on view: View) where View : AnyObject, View: Sendable {
            _ = withObservationTracking {
                container.state
            } onChange: {
                Task { @MainActor in
                    render(view, container.state)
                }
            }

        }
        
        /// Represents the event type for a rendering subscription
        enum SubscriptionEvent {
            case didSet, willSet
        }
    }
}

// MARK: - Observation API Pass-throughs

@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macOS, introduced: 14.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(tvOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(visionOS, introduced: 1.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macCatalyst, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(watchOS, unavailable, message: "watchOS only uses SwiftUI, so this UIKit-specific property wrapper is not available")
extension RenderedViewState.RenderedContainer {
    
    /// Immediately updates the container's state to the provided value.
    ///
    /// This method cancels any ongoing state observations and synchronously updates the state
    /// on the main thread. Use this method when you have a state value ready and want to
    /// update immediately without any asynchronous work.
    ///
    /// - Parameter nextState: The new state value to set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// class ExampleViewController: UIViewController {
    ///     @RenderedViewState(render: ExampleViewController.render)
    ///     var state: ExampleViewState = .initialized(.init())
    ///     
    ///     func render() {
    ///         switch state {
    ///         case .loaded(let model):
    ///             // Configure UI for loaded state
    ///             resetButton.addAction(UIAction { [weak self] _ in
    ///                 self?.$state.observe(.initialized(.init()))
    ///             }, for: .touchUpInside)
    ///         // ... other cases
    ///         }
    ///     }
    /// }
    /// ```
    public func observe(_ nextState: State) {
        container.observe(nextState)
    }
    
    /// Observes and updates the state using an asynchronous closure.
    ///
    /// This method executes the provided closure asynchronously to produce the next state.
    /// The closure can run on any thread based on Swift's concurrency model, but the resulting
    /// state change is guaranteed to occur on the main thread. The method returns immediately
    /// without waiting for the closure to complete.
    ///
    /// - Parameter nextStateClosure: An async closure that produces the next state value.
    ///
    /// ## Example
    ///
    /// First, define a state model with an async action:
    ///
    /// ```swift
    /// struct ErrorViewStateModel: Sendable {
    ///     let error: Error
    ///     private let repository: ItemRepository
    ///     
    ///     func retry() async -> ExampleViewState {
    ///         do {
    ///             let items = try await repository.fetchItems()
    ///             return .loaded(LoadedViewStateModel(items: items, repository: repository))
    ///         } catch {
    ///             return .error(ErrorViewStateModel(error: error, repository: repository))
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// Then observe the action in your view controller:
    ///
    /// ```swift
    /// class ExampleViewController: UIViewController {
    ///     @RenderedViewState(render: ExampleViewController.render)
    ///     var state: ExampleViewState = .error(ErrorViewStateModel())
    ///     
    ///     func render() {
    ///         switch state {
    ///         case .error(let model):
    ///             retryButton.addAction(UIAction { [weak self] _ in
    ///                 self?.$state.observe { await model.retry() }
    ///             }, for: .touchUpInside)
    ///         // ... other cases
    ///         }
    ///     }
    /// }
    /// ```
    public func observe(_ nextStateClosure: sending @escaping () async -> State) {
        container.observe(nextStateClosure)
    }
    
    /// Refreshes the state using an async closure, suspending until complete.
    ///
    /// Designed for pull-to-refresh in UIKit. Suspends until the state has been
    /// produced and applied, so the refresh indicator remains visible until completion.
    public func refresh(state nextStateClosure: sending @escaping () async -> State) async {
        await container.refresh(state: nextStateClosure)
    }
    
    /// Observes and updates the state through a sequence of state values.
    ///
    /// This method consumes a `StateSequence` that produces multiple state values over time.
    /// Each state value is applied to the container as it becomes available from the sequence.
    /// Any ongoing observation is cancelled before the new one begins.
    ///
    /// The timing of the first state depends on how the `StateSequence` was created:
    /// - `@StateSequenceBuilder` with plain `State` values before `Next`: first state is applied synchronously
    /// - Array literal or variadic `StateSequence(_:)`: first state is applied asynchronously after a `Task` is scheduled
    ///
    /// - Parameter stateSequence: A `StateSequence` that produces a series of state values.
    ///
    /// ## Example
    ///
    /// First, define a state model that returns a `StateSequence`:
    ///
    /// ```swift
    /// struct InitializedViewStateModel: Sendable {
    ///     private let repository: ItemRepository
    ///     
    ///     func load() -> StateSequence<ExampleViewState> {
    ///         StateSequence(
    ///             first: .loading,
    ///             rest: { await self.fetchItems() }
    ///         )
    ///     }
    ///     
    ///     @concurrent
    ///     private func fetchItems() async -> ExampleViewState {
    ///         do {
    ///             let items = try await repository.fetchItems()
    ///             return .loaded(LoadedViewStateModel(items: items, repository: repository))
    ///         } catch {
    ///             return .error(ErrorViewStateModel(error: error, retry: { await self.fetchItems() }))
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// Then observe the sequence in your view controller:
    ///
    /// ```swift
    /// class ExampleViewController: UIViewController {
    ///     @RenderedViewState(render: ExampleViewController.render)
    ///     var state: ExampleViewState = .initialized(InitializedViewStateModel())
    ///     
    ///     override func viewWillAppear(_ animated: Bool) {
    ///         super.viewWillAppear(animated)
    ///         if case .initialized(let model) = state {
    ///             $state.observe(model.load())
    ///         }
    ///     }
    ///     
    ///     func render() {
    ///         switch state {
    ///         case .loading:
    ///             activityIndicator.startAnimating()
    ///         case .loaded(let model):
    ///             activityIndicator.stopAnimating()
    ///             // Configure UI with model.items
    ///         // ... other cases
    ///         }
    ///     }
    /// }
    /// ```
    public func observe(_ stateSequence: sending StateSequence<State>) {
        container.observe(stateSequence)
    }
        
    /// Observes and updates the state from a generic `AsyncSequence` that never throws.
    ///
    /// This method consumes any `AsyncSequence` whose element type is `State` and failure type
    /// is `Never`. The most common type that satisfies this constraint is `AsyncStream`. Any
    /// ongoing observation is cancelled before the new one begins.
    ///
    /// Generic `AsyncSequence` observation is fully asynchronous, including the first element.
    /// For initial load flows that must show loading in the first frame, prefer
    /// `observe(_ stateSequence:)` with a `StateSequence` built via `@StateSequenceBuilder`.
    ///
    /// - Parameter sequence: Any `AsyncSequence` that emits `State` values with `Failure` type of `Never`.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    public func observe(_ sequence: some AsyncSequence<State, Never>) {
        container.observe(sequence)
    }
    
    /// **(Legacy — unsafe)** Observes a publisher, applying `firstState` synchronously.
    /// Works with any `State` type. See ``AsyncStateContainer/observeLegacyUnsafe(_:firstState:)``
    /// for safety details regarding non-Sendable mutable reference types.
    public func observeLegacyUnsafe(_ publisher: some Publisher<State, Never>, firstState: State) {
        container.observeLegacyUnsafe(publisher, firstState: firstState)
    }
    
    /// **(Legacy — unsafe)** Observes a publisher, consuming all emissions asynchronously (hops).
    /// Works with any `State` type. See ``AsyncStateContainer/observeLegacyAsyncUnsafe(_:)``
    /// for safety details regarding non-Sendable mutable reference types.
    public func observeLegacyAsyncUnsafe(_ publisher: some Publisher<State, Never>) {
        container.observeLegacyAsyncUnsafe(publisher)
    }
    
    /// **(Legacy — unsafe, blocking)** Observes a publisher using a lock to capture the first
    /// emission synchronously. Works with any `State` type. Briefly blocks the calling thread.
    /// Uses `@unchecked Sendable` internally. Intended for deletion once callers adopt `Sendable`.
    /// See ``AsyncStateContainer/observeLegacyBlockingUnsafe(_:)`` for full details.
    public func observeLegacyBlockingUnsafe(_ publisher: some Publisher<State, Never>) {
        container.observeLegacyBlockingUnsafe(publisher)
    }
}

// MARK: - Sendable-Only Pass-throughs

extension RenderedViewState.RenderedContainer where State: Sendable {
    
    /// `@Sendable` overload — preferred by the compiler when `State: Sendable`.
    public func observe(_ nextStateClosure: @escaping @Sendable () async -> State) {
        container.observe(nextStateClosure)
    }
    
    /// `@Sendable` overload of `refresh(state:)`.
    public func refresh(state nextStateClosure: @escaping @Sendable () async -> State) async {
        await container.refresh(state: nextStateClosure)
    }
    
    /// **(Legacy — safe)** Observes a publisher, applying `firstState` synchronously.
    /// Requires `State: Sendable`. No lock, no hop.
    public func observeLegacy(_ publisher: some Publisher<State, Never>, firstState: State) {
        container.observeLegacy(publisher, firstState: firstState)
    }
    
    /// **(Legacy — safe)** Observes a publisher, consuming all emissions asynchronously (hops).
    /// Requires `State: Sendable`.
    public func observeLegacyAsync(_ publisher: some Publisher<State, Never>) {
        container.observeLegacyAsync(publisher)
    }
    
    /// **(Legacy)** Observes a publisher using a lock to capture the first emission synchronously.
    /// Requires `State: Sendable`. Briefly blocks the calling thread.
    public func observeLegacyBlocking(_ publisher: some Publisher<State, Never>) {
        container.observeLegacyBlocking(publisher)
    }
}
#endif
