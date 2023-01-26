//
//  ViewState.swift
//  
//
//  Created by Albert Bori on 11/18/22.
//

#if canImport(SwiftUI)
import Combine
import SwiftUI

/// **(SwiftUI Only)** Manages the view state for a SwiftUI View in VSM. Automatically updates the view when the state changes.
///
/// This property wrapper encapsulates a view's state property with an underlying `StateContainer` to provide the current view state .
/// A subset of `StateContainer` members are available through the `$` prefix, such as `observe(...)` and `bind(...)`.
///
/// **Usage*
///
/// Decorate your view state property with this property wrapper.
///
/// Example:
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
@available(iOS 14.0, *)
@propertyWrapper
public struct ViewState<State>: DynamicProperty {
    
    @StateObject var container: StateContainer<State>
    
    // MARK: - Encapsulating Properties

    public var wrappedValue: State {
        get { container.state }
    }

    public var projectedValue: some StateContaining<State> {
        container
    }
    
    // MARK: - Initializers
    
    /// **(SwiftUI Only)** Instantiates the rendered view state with a custom state container.
    /// - Parameter container: The state container that manages the view state.
    public init(container: StateContainer<State>) {
        self._container = .init(wrappedValue: container)
    }
    
    /// **(SwiftUI only)** Instantiates the view state with an initial value.
    ///
    /// Example:
    ///
    /// ```swift
    /// struct MyView: View {
    ///     @ViewState var state: MyViewState
    ///
    ///     init() {
    ///         let myViewState = MyViewState()
    ///         _state = .init(wrappedValue: myViewState)
    ///     }
    ///
    ///     var body: some View {
    ///         Button(state.someValue) {
    ///             $state.observe(state.someAction())
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter wrappedValue: The view state to be managed by the state container.
    public init(wrappedValue: State) {
        self.init(container: StateContainer(state: wrappedValue))
    }
}
#endif
