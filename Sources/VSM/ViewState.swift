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
/// This property wrapper encapsulates a view's state property with an underlying `StateContainer` to provide the current view state.
/// A subset of `StateContainer` members are available through the `$` prefix, such as `observe(...)` and `bind(...)`.
///
/// ## Usage
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
///
/// ## Debugging
///
/// You can enable debug logging to trace state changes in the Console. This is useful during development
/// to understand when and how your view's state is changing. Logging is disabled by default.
///
/// To enable logging, set `loggingEnabled` to `true`:
///
/// ```swift
/// struct MyView: View {
///     @ViewState(loggingEnabled: true)
///     var state: MyViewState = .initialized(.init())
///
///     var body: some View {
///         // ...
///     }
/// }
/// ```
///
/// When enabled, you'll see debug messages in the Console showing state transitions, which can help
/// diagnose unexpected behavior or verify that actions are triggering the correct state changes.
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
    /// - Parameters:
    ///   - initialState: The view state to be managed by the state container.
    ///   - subsystem: The subsystem identifier for logging (defaults to "com.wayfair.vsm").
    ///   - observedViewType: The type of the view being observed, used for logging categorization.
    ///   - loggingEnabled: When `true`, enables debug logging of state changes to the Console. Defaults to `false`.
    public init(wrappedValue initialState: State, subsystem: String = "com.wayfair.vsm", observedViewType: Any.Type? = nil, loggingEnabled: Bool = false) {
        var category = "VSM View"
        if let observedViewType {
            category = String(describing: observedViewType)
        }
        
        self.__container = SwiftUI.State(wrappedValue: AsyncStateContainer(state: initialState, logger: OSLog(subsystem: subsystem, category: category), loggingEnabled: loggingEnabled))
    }
}
#endif
