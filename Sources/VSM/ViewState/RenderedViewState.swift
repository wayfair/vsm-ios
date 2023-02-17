//
//  RenderedViewState.swift
//
//
//  Created by Albert Bori on 12/23/22.
//

import Foundation
import Combine

/// **(UIKit Only)** Manages the view state for a UIView or UIViewController in VSM. Automatically calls `render()` when the view state changes.
///
/// This property wrapper encapsulates a view's state property with an underlying `StateContainer` to provide the current view state .
/// A subset of `StateContainer` members are available through the `$` prefix, such as `observe(...)` and `bind(...)`.
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
@available(iOS 14.0, *)
@propertyWrapper
public struct RenderedViewState<State> {
    
    let renderedContainer: RenderedContainer<State>
    
    // MARK: Encapsulating Properties

    public var wrappedValue: State {
        get { projectedValue.container.state }
    }

    public var projectedValue: RenderedContainer<State> {
        get { renderedContainer }
    }
    
    // MARK: Initializers
    
    /// **(UIKit only)** Instantiates the rendered view state with a custom state container.
    /// - Parameters:
    ///   - container: The state container that manages the view state.
    ///   - render: The function to call when the view state changes.
    public init<Parent: AnyObject>(container: StateContainer<State>, render: @escaping (Parent) -> () -> ()) {
        let anyRender: (Any, State) -> () = { parent, state in
            guard let parent = parent as? Parent else { return }
            render(parent)()
        }
        renderedContainer = RenderedContainer(container: container, render: anyRender)
    }
    
    /// **(UIKit only)** Instantiates the rendered view state with an initial value.
    ///
    /// Example:
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
    ///   - render: The function to call when the view state changes.
    public init<Parent: AnyObject>(
        wrappedValue: State,
        render: @escaping (Parent) -> () -> ()
    ) {
        self.init(container: StateContainer(state: wrappedValue), render: render)
    }
    
    // MARK: Automatic Rendering

    /// Automatically calls `render()` when the state changes on any class that has a property decorated with this property wrapper. (Intended for UIKit only)
    ///
    /// For the behavior to take effect, the property's parent type must be a `class` that provides a `render` value on initialization and will usually be some sort of `UIView` or `UIViewController` subclass.
    /// This is helpful for implementing VSM with **UIKit** views and view controllers in that it handles the "auto-updating" behavior that comes implicitly with SwiftUI.
    ///
    /// Maintenance Note: The Swift runtime automatically calls this subscript each time the wrapped property is accessed.
    /// It can be called many, many times. Any operations within the subscript must be performant, thread-safe, and duplication-resistant.
    public static subscript<ParentClass: AnyObject>(
        _enclosingInstance instance: ParentClass,
        wrapped wrappedKeyPath: KeyPath<ParentClass, State>,
        storage storageKeyPath: KeyPath<ParentClass, RenderedViewState<State>>
    ) -> State {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            wrapper.projectedValue.startRendering(on: instance)
            return wrapper.wrappedValue
        }
    }
}

// MARK: - RenderedViewState (StateRendering & Other Conformances)

/// Provides functions for rendering state changes in UIKit views and view controllers
@available(iOS 14.0, *)
public protocol StateRendering {
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
    func startRendering<View: AnyObject>(on view: View)
}

@available(iOS 14.0, *)
public extension RenderedViewState {
    /// Provides functions for observing and rendering state changes in UIKit views and view controllers
    struct RenderedContainer<State>: StateRendering {
        /// The wrapped state container for managin changes in state
        let container: StateContainer<State>
        /// Implicitly used by UIKit views to automatically call the provided function when the state changes
        let render: (AnyObject, State) -> Void
        /// Tracks state changes for invoking `render` when the state changes
        let stateDidChangeSubscriber: AtomicStateChangeSubscriber<State> = .init()
        
        public func startRendering<View>(on view: View) where View : AnyObject {
            stateDidChangeSubscriber
                .subscribeOnce(to: container.publisher) { [weak view] newState in
                    guard let view else { return }
                    render(view, newState)
                }
        }
    }
}

// Forwards protocol member calls to underlying state container
@available(iOS 14.0, *)
extension RenderedViewState.RenderedContainer: StateObserving & StatePublishing {
    
    // MARK: StatePublishing
    // For more information about these members, view the protocol definition
    
    public var publisher: AnyPublisher<State, Never> {
        container.publisher
    }
    
    // MARK: StateObserving Implementation - Observe
    // For more information about these members, view the protocol definition
    
    public func observe(_ statePublisher: AnyPublisher<State, Never>) {
        container.observe(statePublisher)
    }
    
    public func observe(_ nextState: State) {
        container.observe(nextState)
    }
    
    public func observeAsync(_ nextState: @escaping () async -> State) {
        container.observeAsync(nextState)
    }
    
    public func observeAsync<StateSequence: AsyncSequence>(
        _ stateSequence: @escaping () async -> StateSequence
    ) where StateSequence.Element == State {
        container.observeAsync(stateSequence)
    }
    
    // MARK: StateObserving Implementation - Debounce
    // For more information about these members, view the protocol definition
    
    public func observe(
        _ statePublisher: @escaping @autoclosure () ->  AnyPublisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        container.observe(statePublisher(), debounced: dueTime, identifier: identifier)
    }
    
    public func observe(
        _ nextState: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        container.observe(nextState(), debounced: dueTime, identifier: identifier)
    }
    
    public func observeAsync(
        _ nextState: @escaping () async -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        container.observeAsync(nextState, debounced: dueTime, identifier: identifier)
    }
    
    public func observeAsync<SomeAsyncSequence: AsyncSequence>(
        _ stateSequence: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) where SomeAsyncSequence.Element == State {
        container.observeAsync(stateSequence, debounced: dueTime, identifier: identifier)
    }
}
