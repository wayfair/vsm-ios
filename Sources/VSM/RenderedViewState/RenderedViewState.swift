//
//  RenderedViewState.swift
//  
//
//  Created by Albert Bori on 12/23/22.
//

import Foundation

/// **(UIKit Only)** Manages the view state for a UIView or UIViewController. Automatically calls `render()` when the view state changes. Used in VSM features.
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
    
    let container: StateContainer<State>
    let wrapper: StateContainer<State>.Wrapper
    /// Tracks state changes for invoking `render` when the state changes
    let stateDidChangeSubscriber: AtomicStateChangeSubscriber<State> = .init()
    /// Implicitly used by UIKit views to automatically call the provided function when the state changes
    var render: (AnyObject, State) -> ()
    
    // MARK: - Encapsulating Properties

    public var wrappedValue: State {
        get { container.state }
    }

    public var projectedValue: StateContainer<State>.Wrapper {
        wrapper
    }
    
    // MARK: - Initializers
    
    /// **(UIKit only)** Instantiates the rendered view state with a custom state container.
    /// - Parameters:
    ///   - container: The state container that manages the view state.
    ///   - render: The function to call when the view state changes.
    public init<Parent: AnyObject>(container: StateContainer<State>, render: @escaping (Parent) -> () -> ()) {
        self.container = container
        self.wrapper = .init(container: container)
        let anyRender: (Any, State) -> () = { parent, state in
            guard let parent = parent as? Parent else { return }
            render(parent)()
        }
        self.render = anyRender
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
    
    // MARK: - Automatic Rendering

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
            wrapper
                .stateDidChangeSubscriber
                .subscribeOnce(to: wrapper.container.statePublisher) { [weak instance] newState in
                    guard let instance else { return }
                    wrapper.render(instance, newState)
                }
            return wrapper.wrappedValue
        }
    }
}
