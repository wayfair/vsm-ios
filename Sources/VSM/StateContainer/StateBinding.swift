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

/// Provides functions for converting a view state into a SwiftUI two-way `Binding<T>`
public protocol StateBinding<State> {
    associatedtype State
    
    /// Creates a two-way SwiftUI binding using a `KeyPath` and a _closure_ for simple (non-enum) view states.
    ///
    /// Example Usage
    /// ```swift
    /// TextField("Username", text: $state.bind(\.username, to: { $0.update(username: $1) }))
    /// ```
    ///
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: Converts the new `Value` to a new `State`, which is automatically rendered by the view
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> AnyPublisher<State, Never>) -> Binding<Value>
    
    /// Creates a two-way SwiftUI binding using a `KeyPath` and a _function type_ for simple (non-enum) view states.
    ///
    /// Example Usage
    /// ```swift
    /// TextField("Username", text: $state.bind((\.username), to: ProfileState.update))
    /// ```
    ///
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: A _function type_ which converts the new `Value` to a new `State` and is automatically rendered by the view
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> AnyPublisher<State, Never>) -> Binding<Value>
    
    /// Creates a two-way SwiftUI binding using a `KeyPath` and a _closure_ for simple (non-enum) view states.
    ///
    /// Example Usage
    /// ```swift
    /// TextField("Username", text: $state.bind(\.username, to: { $0.update(username: $1) }))
    /// ```
    ///
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: Converts the new `Value` to a new `State`, which is automatically rendered by the view
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> State) -> Binding<Value>
        
    /// Creates a two-way SwiftUI binding using a `KeyPath` and a _function type_ for simple (non-enum) view states.
    ///
    /// Example Usage
    /// ```swift
    /// TextField("Username", text: $state.bind((\.username), to: ProfileState.update))
    /// ```
    ///
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: A _function type_ which converts the new `Value` to a new `State` and is automatically rendered by the view
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> State) -> Binding<Value>
    
    /// Creates an asynchronous two-way SwiftUI binding using a `KeyPath` and a _closure_ for simple (non-enum) view states.
    ///
    /// Example Usage
    /// ```swift
    /// TextField("Username", text: $state.bind(\.username, to: { $0.update(username: $1) }))
    /// ```
    ///
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: Converts the new `Value` to a new `State`, which is automatically rendered by the view
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bindAsync<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) async -> State) -> Binding<Value>
        
    /// Creates an asynchronous two-way SwiftUI binding using a `KeyPath` and a _function type_ for simple (non-enum) view states.
    ///
    /// Example Usage
    /// ```swift
    /// TextField("Username", text: $state.bind((\.username), to: ProfileState.update))
    /// ```
    ///
    /// - Parameters:
    ///   - stateKeyPath: `KeyPath` for a `Value` of the `State`
    ///   - observedSetter: A _function type_ which converts the new `Value` to a new `State` and is automatically rendered by the view
    /// - Returns: A `Binding<Value>` for use in SwiftUI controls
    func bindAsync<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) async -> State) -> Binding<Value>
}
#endif
