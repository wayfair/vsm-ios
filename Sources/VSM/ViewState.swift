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

/// Property wrapper you apply to the `state` property on a VSM view: a SwiftUI `View`, or a UIKit
/// `UIView` / `UIViewController` when you adopt UIKit’s observation tracking (iOS 18 and later; see
/// <doc:ViewDefinition-UIKit>).
///
/// In VSM, *state* is the value that describes what your feature is doing right now—which screen or phase
/// you are in (loading, success, error, and so on)—and, when you use enums with associated models, which
/// actions are available. That `state` value is the **single source of truth** for what the UI should
/// represent. SwiftUI reads it from `body`; in UIKit you align subviews and controls from
/// `updateProperties()` (or equivalent) when observation notifies you that `state` changed.
///
/// ### SwiftUI
///
/// `@ViewState` is a `DynamicProperty` that wraps an ``AsyncStateContainer`` stored in the SwiftUI view graph
/// (via SwiftUI’s `@State` so the container’s identity survives parent rebuilds). The container is
/// `@Observable`, so when its ``AsyncStateContainer/state`` changes, SwiftUI is notified and the view
/// refreshes—without you manually publishing or forwarding updates. See also <doc:ViewDefinition-SwiftUI>.
///
/// ### UIKit (iOS 18+)
///
/// The same property wrapper works on `UIView` and `UIViewController`. UIKit’s property observation tracks
/// `@ViewState` and calls `updateProperties()` when ``AsyncStateContainer/state`` changes. Setup,
/// `updateProperties()` patterns, and related details are covered in <doc:ViewDefinition-UIKit> (*Building the
/// View in VSM - UIKit*). On iOS 17, use ``RenderedViewState`` instead; it is deprecated on newer OS
/// versions in favor of `@ViewState`—see ``RenderedViewState`` for migration from `render()` to
/// `updateProperties()`.
///
/// > Important: On **iOS 18**, you must add the Boolean key `UIObservationTrackingEnabled` to your app’s
/// **Info.plist** (value `YES`) so UIKit automatically calls `updateProperties()` when `@ViewState` changes.
/// See **Enabling Observation Tracking on iOS 18** in <doc:ViewDefinition-UIKit> for the full plist entry and
/// behavior by OS version. On **iOS 26** and later, observation tracking is enabled by default and this key
/// is not required.
///
/// > Warning: **UIKit on iOS 17:** You cannot use `@ViewState` on `UIView` or `UIViewController` when your
/// UIKit integration depends on **iOS 17**. That OS does not provide the property-observation path that
/// triggers `updateProperties()` when an `@Observable` container (the backing ``AsyncStateContainer``) changes,
/// so the view would not refresh when state updates. Use ``RenderedViewState`` with an explicit `render()`
/// callback for UIKit on iOS 17 instead; see the **Legacy Approach (iOS 17)** section in
/// <doc:ViewDefinition-UIKit>. This does **not** apply to SwiftUI — `@ViewState` remains the right choice
/// for SwiftUI views on iOS 17 and later.
///
/// The wrapped value is only the current `State`. In both SwiftUI and UIKit, use the **projected value**
/// (`$state`) to reach the container’s APIs that drive transitions, such as `observe(_:)`
/// and the `bind` methods that produce SwiftUI `Binding` values tied to state.
///
/// The `State` type does not need to conform to `Sendable`; see ``AsyncStateContainer`` and
/// <doc:DataDefinition> for concurrency and optional `Sendable`.
///
/// ## Usage (SwiftUI)
///
/// Decorate your view state property with this property wrapper.
///
/// Example:
///
/// ```swift
/// struct MyView: View {
///     @ViewState var state: MyViewState = .initialized(.init())
///
///     var body: some View {
///         Button(state.someValue) {
///             $state.observe(state.someAction())
///         }
///     }
/// }
/// ```
///
/// ## Usage (UIKit)
///
/// On `UIView` or `UIViewController`, decorate your `state` property with `@ViewState`, assign it in an
/// initializer with `_state = .init(wrappedValue:)`, override `updateProperties()` to align subviews with
/// `state`, and call `$state.observe(_:)` when handling actions. See <doc:ViewDefinition-UIKit> for full
/// patterns (iOS version requirements and **Info.plist** are summarized in the callouts above).
///
/// Example:
///
/// ```swift
/// import UIKit
///
/// final class MyViewController: UIViewController {
///     @ViewState var state: MyViewState = .initialized(.init())
///
///     override func updateProperties() {
///         super.updateProperties()
///         // Map `state` onto your subviews
///     }
///
///     func handleTap() {
///         $state.observe(state.someAction())
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
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
public struct ViewState<State>: DynamicProperty {
    // @State gives us "init once" semantics: SwiftUI stores the container in its
    // view graph on first appearance and restores it on every subsequent re-render
    // of the same view identity, regardless of how many times the parent rebuilds
    // the struct. The container is `@MainActor`-isolated for SwiftUI; `AsyncStateContainer`
    // conforms to `Sendable` only when `State: Sendable`.
    @SwiftUI.State private var _container: AsyncStateContainer<State>

    public var container: AsyncStateContainer<State> { _container }
    
    public var wrappedValue: State {
        get { container.state }
    }
    
    public var projectedValue: AsyncStateContainer<State> { container }
    
    /// Instantiates the view state with an initial value for SwiftUI views or UIKit views and view
    /// controllers (see <doc:ViewDefinition-UIKit> for UIKit initialization on iOS 18+).
    ///
    /// Example:
    ///
    /// ```swift
    /// struct MyView: View {
    ///     @ViewState var state: MyViewState = .initialized(.init())
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
