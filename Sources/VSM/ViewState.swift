//
//  ViewState.swift
//  
//
//  Created by Albert Bori on 11/18/22.
//

import Combine
import SwiftUI

@available(iOS 14.0, *)
@propertyWrapper
public struct ViewState<State>: DynamicProperty {
    
    @StateObject var container: StateContainer<State>
    private var stateDidChangeSubscriber: AtomicStateChangeSubscriber<State> = .init()
    
    public var wrappedValue: State {
        get { container.state }
        @available(*, unavailable, message: "VSM does not support direct view state editing")
        nonmutating set { /* no-op */ }
    }
        
    public init(_ state: State) {
        _container = .init(state: state)
    }
    
    public init(_ container: StateContainer<State>) {
        _container = .init(wrappedValue: container)
    }
    
    var publisher: Published<State>.Publisher {
        container.$state
    }
    
    public var projectedValue: StateContainer<State> {
        container
    }
    
    /// Hooks into the property wrapper implicit behavior to automatically call the `render()` function on any class that declares a property with this property wrapper.
    ///
    /// For the behavior to take effect, the property's parent type must be a `class` that implements the ``ViewStateRendering`` and will usually be some sort of `UIView` or `UIViewController` subclass.
    /// This is helpful for implementing VSM with **UIKit** views and view controllers in that it handles the "auto-updating" behavior that comes implicitly with SwiftUI.
    public static subscript<ParentClass: AnyObject & ViewStateRendering>(
        _enclosingInstance instance: ParentClass,
        wrapped wrappedKeyPath: KeyPath<ParentClass, StateContainer<State>>,
        storage storageKeyPath: KeyPath<ParentClass, ViewState<State>>
    ) -> StateContainer<State> {
        get {
            let wrapper = instance[keyPath: storageKeyPath]
            wrapper
                .stateDidChangeSubscriber
                .subscribe(to: wrapper.container.statePublisher) { [weak instance] newState in
                    instance?.render()
                }
            return wrapper.container
        }
        @available(*, unavailable, message: "VSM does not support direct view state editing")
        set { /* no-op */ }
    }
}

private class AutoRenderSubscriptions {
    static var subscriptions: Set<AnyCancellable> = []
}

/// View state now gets all the convenience functions from StateContainer to save on extra typing (copy/pasted from ViewStateRendering)
@available(iOS 14.0, *)
extension ViewState {
    
    func observe(_ stateChangePublisher: AnyPublisher<State, Never>) {
        container.observe(stateChangePublisher)
    }

    func observe(_ awaitState: @escaping () async -> State) {
        container.observe(awaitState)
    }

    func observe(_ nextState: @autoclosure @escaping () -> State) {
        container.observe(nextState)
    }
    
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> State) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
    
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> State) -> Binding<Value> {
        container.bind(stateKeyPath, to: observedSetter)
    }
}

// MARK: Example

protocol OptionAViewStating {
    var isEnabled: Bool { get }
    func toggle(isEnabled: Bool) -> OptionAViewStating
}

struct OptionAViewState: OptionAViewStating, MutatingCopyable, Equatable {
    var isEnabled: Bool = false
    
    func toggle(isEnabled: Bool) -> OptionAViewStating {
        self.copy(mutating: { $0.isEnabled = isEnabled })
    }
}

/// Pros:
/// - ViewStateRendering protocol is no longer recommended (was never required, but is helpful)
/// - Simpler view definition (no thinking about property-wrapped state containers)
/// - Changes the paradigm from "a VSM View" to "a View that has an 'observed view state' "
/// Cons:
/// - Regularly using the `_` syntax is "smelly" (aside from having to use it in custom initializers, which is a burden everyone already deals with)
/// - More typing is required for convenience functions. old: `observe(...)` new: `_state.observe(...)`, old: `bind(...)` new: `_state.bind(...)`

@available(iOS 14.0, *)
struct OptionAView: View {
    
    @ViewState var state: OptionAViewStating
    
    var body: some View {
        Toggle("Test", isOn: $state.bind(\.isEnabled, to: OptionAViewStating.toggle))
        Button(state.isEnabled.description) {
            $state.observe(state.toggle(isEnabled: !state.isEnabled))
        }
        .onChange(of: state.isEnabled) { isEnabled in
            print(isEnabled)
        }
        .onReceive($state.statePublisher) { newState in
            print(newState)
        }
        //Can also access: _state.container
    }
}

@available(iOS 14.0, *)
struct OptionAParentView: View {
    var body: some View {
        VStack { }
        OptionAView(state: .init(OptionAViewState(isEnabled: true)))
    }
}
