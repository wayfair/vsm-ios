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
@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macOS, introduced: 14.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(tvOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(visionOS, introduced: 1.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macCatalyst, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(watchOS, unavailable, message: "watchOS only uses SwiftUI, so this UIKit-specific property wrapper is not available")
@MainActor
@propertyWrapper
public struct RenderedViewState<State: Sendable> {
    
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
    public init<Parent>(
        wrappedValue: State,
        render: @escaping (Parent) -> () -> (),
        subsystem: String = "com.wayfair.vsm"
    )
    where Parent: AnyObject & Sendable {
        let observedViewType = String(describing: Parent.self)
        let anyRender: (AnyObject, State) -> () = { parent, state in
            guard let parent = parent as? Parent else { return }
            render(parent)()
        }
        
        self.renderedContainer = RenderedContainer(
            container: AsyncStateContainer(
                state: wrappedValue,
                logger: OSLog(subsystem: subsystem, category: observedViewType)
            ),
            render: anyRender
        )
    }
    
    public init<Parent>(
        wrappedValue: State,
        render: @escaping (Parent) -> (State) -> (),
        subsystem: String = "com.wayfair.vsm"
    )
    where Parent: AnyObject & Sendable {
        let observedViewType = String(describing: Parent.self)
        let anyRender: (AnyObject, State) -> () = { parent, state in
            guard let parent = parent as? Parent else { return }
            render(parent)(state)
        }
        
        self.renderedContainer = RenderedContainer(
            container: AsyncStateContainer(
                state: wrappedValue,
                logger: OSLog(subsystem: subsystem, category: observedViewType)
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
    struct RenderedContainer: Sendable, StateObserving {
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

// Forwards protocol member calls to underlying state container
@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(iOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macOS, introduced: 14.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(tvOS, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(visionOS, introduced: 1.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(macCatalyst, introduced: 17.0, deprecated: 26.0, renamed: "ViewState", message: "iOS 26 supports property observation in UIViewControllers and UIViews. Use @ViewState instead and override the updateProperties method which will replace your render method.")
@available(watchOS, unavailable, message: "watchOS only uses SwiftUI, so this UIKit-specific property wrapper is not available")
extension RenderedViewState.RenderedContainer {
    public func observe(_ nextState: State) {
        container.observe(nextState)
    }
    
    public func observe(_ nextStateClosure: @escaping @Sendable () async -> State) {
        container.observe(nextStateClosure)
    }
    
    public func refresh(state nextState: @escaping @Sendable () async -> State) async {
        await container.refresh(state: nextState)
    }
    
    public func observe(_ stateSequence: StateSequence<State>) {
        container.observe(stateSequence)
    }
    
    public func observe(_ stream: AsyncStream<State>) {
        container.observe(stream)
    }
    
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    public func observe<SomeAsyncSequence>(_ sequence: SomeAsyncSequence)
    where SomeAsyncSequence: AsyncSequence,
          SomeAsyncSequence.Element == State,
          SomeAsyncSequence.Failure == Never {
        container.observe(sequence)
    }
    
    public func observe(_ publisher: some Publisher<State, Never>) {
        container.observe(publisher)
    }
    
    public func observe(_ stateSequence: StateSequence<State>, debounced duration: Duration) {
        container.observe(stateSequence, debounced: duration)
    }
    
    public func observe(_ stream: AsyncStream<State>, debounced duration: Duration) {
        container.observe(stream, debounced: duration)
    }
    
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    public func observe<SomeAsyncSequence>(_ sequence: SomeAsyncSequence, debounced duration: Duration)
    where SomeAsyncSequence : Sendable,
          SomeAsyncSequence : AsyncSequence,
          State == SomeAsyncSequence.Element,
          SomeAsyncSequence.Failure == Never {
        container.observe(sequence, debounced: duration)
    }
    
    public func observe(_ publisher: some Publisher<State, Never>, debounced duration: Duration) {
        container.observe(publisher, debounced: duration)
    }
}
#endif
