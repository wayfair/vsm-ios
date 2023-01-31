//
//  StateBinding.swift
//
//
//  Created by Albert Bori on 1/26/23.
//

#if canImport(SwiftUI)
import Combine
import Foundation
import SwiftUI

public protocol StateBinding<State> {
    associatedtype State
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`ViewState` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> State) -> Binding<Value>
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **This doesn't work when`ViewState` is an enum**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> State) -> Binding<Value>
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
    /// **Not intended for use when`ViewState` is an enum.**
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> AnyPublisher<State, Never>) -> Binding<Value>
    
    /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
    /// **Not intended for use when`ViewState` is an enum.**
    /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
    ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> AnyPublisher<State, Never>) -> Binding<Value>
}

struct HashedIdentifier: Hashable {
    let uniqueValues: [AnyHashable]
    
    /// Prevents accidental key collisions between auto-generated identifiers and manually generated identifiers
    private static var uniqueKey: AnyHashable = UUID()
    
    init(_ values: AnyHashable ...) {
        uniqueValues = [Self.uniqueKey] + values
    }
}
#endif
