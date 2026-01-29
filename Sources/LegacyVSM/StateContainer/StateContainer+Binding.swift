//
//  StateContainer+Binding.swift
//  
//
//  Created by Albert Bori on 5/10/22.
//

#if canImport(SwiftUI)

import Combine
import SwiftUI

// MARK: - Synchronous Observed Binding Extensions

public extension StateContainer {
    
    // See StateBinding for details
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> State) -> Binding<Value> {
        return Binding<Value>(
            get: {
                return self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observe(observedSetter(self.state, newValue))
            })
    }
    
    // See StateBinding for details
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
    
    // See StateBinding for details
    func bindAsync<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) async -> State) -> Binding<Value> {
        return Binding<Value>(
            get: {
                return self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observeAsync({ await observedSetter(self.state, newValue) })
            })
    }
    
    // See StateBinding for details
    func bindAsync<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) async -> State) -> Binding<Value> {
        return Binding<Value>(
            get: {
                return self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observeAsync({ await observedSetter(self.state)(newValue) })
            })
    }
}

// MARK: - State-Publishing Observed Binding Extensions

public extension StateContainer {
    
    // See StateBinding for details
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> AnyPublisher<State, Never>) -> Binding<Value> {
        return Binding<Value>(
            get: {
                self.state[keyPath: stateKeyPath]
            },
            set: { newValue in
                self.observe(observedSetter(self.state, newValue))
            })
    }
    
    // See StateBinding for details
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
