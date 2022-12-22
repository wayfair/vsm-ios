//
//  ViewState.swift
//  
//
//  Created by Albert Bori on 11/18/22.
//

import Combine
import SwiftUI

/// Provides VSM functionality for a SwiftUI or UIKit view.
///
/// This property wrapper encapsulates a view's state property with an underlying `StateContainer` to provide the current view state .
/// A subset of `StateContainer` members are available through the `$` prefix, such as `observe(...)` and `bind(...)`.
///
/// **Usage*
///
/// Decorate your view state property with this property wrapper.
///
/// SwiftUI Example:
///
/// ```swift
/// struct MyView: View {
///     @ViewState var state: MyViewState
///
///     var body: some View {
///         Button(state.someValue) {
///             $state.observe(state.someAction())
///         }
///     }
/// }
/// ```
///
/// UIKit Example:
///
/// ```swift
/// class MyViewController: UIViewController {
///     @ViewState var state: MyViewState
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
@available(iOS 14.0, *)
@propertyWrapper
public struct ViewState<State>: DynamicProperty {
    
    // MARK: SwiftUI Properties
    
    /// Keeps track of the state container for value parent types (SwiftUI views)
    /// It is not used for UIKit views
    @StateObject private var valueTypeContainer: StateContainer<State>
    
    // MARK: UIKit Properties
    
    /// Keeps track of the state container for class parent types (UIKit views)
    /// It is not used for SwiftUI views
    private var referenceTypeContainer: StateContainer<State>
    /// Tracks state changes for invoking `render` when the state changes
    private var stateDidChangeSubscriber: AtomicStateChangeSubscriber<State> = .init()
    /// Implicitly used by UIKit views to automatically call the provided function when the state changes
    private var render: ((AnyObject, State) -> ())?
    /// Prevents runtime warnings related to using `@StateObject` when not attached to a SwiftUI view (ie, in UIKit views)
    private var isParentReferenceType: Bool { render != nil }
    
    // MARK: Wrapped Properties
    
    private var container: StateContainer<State> {
        isParentReferenceType ? referenceTypeContainer : valueTypeContainer
    }

    public var wrappedValue: State {
        get { container.state }
    }

    private let wrapper: Wrapper
    public var projectedValue: Wrapper {
        wrapper
    }
    
    // MARK: Intializers

    /// Instantiate with a custom `StateContainer` to allow the caller to directly interact with the `StateContainer`, if desired.
    ///
    /// - Parameter container: `StateContainer` where `State` matches the view state type.
    init(container: StateContainer<State>) {
        self.referenceTypeContainer = container
        self._valueTypeContainer = .init(wrappedValue: container)
        self.wrapper = .init(container: container)
    }
    
    private init(_state: State, render: ((AnyObject, State) -> ())?) {
        let container = StateContainer(state: _state)
        self.init(container: container)
        self.render = render
    }
    
    public init(wrappedValue: State) {
        self.init(_state: wrappedValue, render: nil)
    }
    
    /// UIKit only. Instantiates with a render function that is invoked when the State changes.
    ///
    /// Example:
    /// ```swift
    /// class MyViewController: UIViewController {
    ///     @ViewState var state: MyViewState
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
    /// - Parameters:
    ///   - wrappedValue: The view state to be wrapped.
    ///   - render: The function to call when the view state changes.
    public init<Parent: AnyObject>(
        wrappedValue: State,
        render: @escaping (Parent) -> () -> ()
    ) {
        let render: (Any, State) -> () = { parent, state in
            guard let parent = parent as? Parent else { return }
            render(parent)()
        }
        self.init(_state: wrappedValue, render: render)
    }

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
        storage storageKeyPath: KeyPath<ParentClass, ViewState<State>>
    ) -> State {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            guard let render = wrapper.render else {
                return wrapper.wrappedValue
            }
            wrapper
                .stateDidChangeSubscriber
                .subscribeOnce(to: wrapper.container.statePublisher) { [weak instance] newState in
                    guard let instance else { return }
                    render(instance, newState)
                }
            return wrapper.wrappedValue
        }
    }
}
