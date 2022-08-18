//
//  StateContainer+Binding.swift
//  
//
//  Created by Albert Bori on 5/10/22.
//

#if canImport(SwiftUI) && canImport(Combine)

import Combine
import SwiftUI

// MARK: - Synchronous Observed Binding Extensions

public extension StateContainer {
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `State` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`State` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: Converts the new `Value` to a new `State`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> State) -> Binding<Value> {
        return Binding<Value>(
            get: {
                return self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observe(observedSetter(self.state, newValue))
            })
    }
    
    /// Creates a `Binding<Value>` for SwiftUI views by binding a `State`'s Value to an `Action`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `State` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    ///
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `State` using a `KeyPath` and a *method signature*.
    /// This function is best suited for a `State`s that is a `struct`.
    ///
    /// Example Usage
    /// ```swift
    /// TextField("Username", bind(\.username, to: ViewState.changeUsername))
    /// ```
    ///
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> State) -> Binding<Value> {
        return Binding<Value>(
            get: {
                return self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observe(observedSetter(self.state)(newValue))
            })
    }
}

// MARK: - Asynchronous Observed Binding Extensions

public extension StateContainer {
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `State` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`State` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: Converts the new `Value` to a new `State`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) async -> State) -> Binding<Value> {
        return Binding<Value>(
            get: {
                return self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observe({ await observedSetter(self.state, newValue) })
            })
    }
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `State` using a `KeyPath` and a *method signature*
    /// **Not intended for use when`State` is an enum.**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `State` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) async -> State) -> Binding<Value> {
        return Binding<Value>(
            get: {
                return self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observe({ await observedSetter(self.state)(newValue) })
            })
    }
}

// MARK: - State-Publishing Observed Binding Extensions

public extension StateContainer {
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `State` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`State` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: Converts the new `Value` to a new `State`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> AnyPublisher<State, Never>) -> Binding<Value> {
        return Binding<Value>(
            get: {
                self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observe(observedSetter(self.state, newValue))
            })
    }
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `State` using a `KeyPath` and a *method signature*
    /// **Not intended for use when`State` is an enum.**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `State` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> AnyPublisher<State, Never>) -> Binding<Value> {
        return Binding<Value>(
            get: {
                self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observe(observedSetter(self.state)(newValue))
            })
    }
}

#endif
