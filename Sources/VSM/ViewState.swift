//
//  ViewState.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//
#if canImport(SwiftUI)
import Foundation
import OSLog
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
@MainActor
@propertyWrapper
public struct ViewState<State>: DynamicProperty where State: Sendable {
    // @State gives us "init once" semantics: SwiftUI stores the container in its
    // view graph on first appearance and restores it on every subsequent re-render
    // of the same view identity, regardless of how many times the parent rebuilds
    // the struct. AsyncStateContainer conforms to Sendable via @MainActor isolation.
    @SwiftUI.State private var _container: AsyncStateContainer<State>

    public var container: AsyncStateContainer<State> { _container }
    
    public var wrappedValue: State {
        get { container.state }
    }
    
    public var projectedValue: AsyncStateContainer<State> { container }
    
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
    public init(wrappedValue initialState: State, subsystem: String = "com.wayfair.vsm", observedViewType: Any.Type? = nil) {
        var category = "VSM View"
        if let observedViewType {
            category = String(describing: observedViewType)
        }
        
        self.__container = SwiftUI.State(wrappedValue: AsyncStateContainer(state: initialState, logger: OSLog(subsystem: subsystem, category: category)))
    }
}
#endif
