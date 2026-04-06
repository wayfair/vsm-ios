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

public extension AsyncStateContainer {
    
    // See StateBinding for details
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> State) -> Binding<Value> {
        _safeBindMainActor(stateKeyPath, to: observedSetter)
    }
    
    // See StateBinding for details
    func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> State) -> Binding<Value> {
        _safeBindMainActor(stateKeyPath, to: { state, value in observedSetter(state)(value) })
    }
}

// MARK: - Binding.safeInit: Apple's Binding.init without @preconcurrency
//
// Apple's Binding.init(get:set:) uses @preconcurrency, which suppresses Sendable
// diagnostics at the call site. This private factory has the same shape but WITHOUT
// @preconcurrency, so the compiler fully enforces @Sendable checks.
//
// If code compiles when calling safeInit, it means the closures are provably safe —
// not just "trusted" via @preconcurrency suppression.

private extension Binding {
    static func safeInit(
        get: @escaping @isolated(any) @Sendable () -> Value,
        set: @escaping @isolated(any) @Sendable (Value) -> Void
    ) -> Binding<Value> {
        Binding(get: get, set: set)
    }
}

// MARK: - Compiler-Proven Safe Binding (@MainActor)
//
// This extension proves our bind closures are safe by calling Binding.safeInit
// (no @preconcurrency) instead of Apple's Binding.init. Safety comes from
// @MainActor on the closures: captures (self, stateKeyPath) never cross isolation
// boundaries because the closure is guaranteed to execute on the same actor.
// The compiler uses region-based isolation (SE-0414) to verify this — no Sendable
// conformance is needed on captures that stay within their isolation region.
//
// The public `bind` methods above use Apple's @preconcurrency init — which is
// equivalent in practice. This private extension exists solely to document that
// we understand _why_ it is safe.

private extension AsyncStateContainer {
    func _safeBindMainActor<Value>(
        _ stateKeyPath: KeyPath<State, Value>,
        to observedSetter: @escaping (State, Value) -> State
    ) -> Binding<Value> {
        return .safeInit(
            get: { @MainActor in
                self.state[keyPath: stateKeyPath]
            },
            set: { @MainActor newValue in
                self.observe(observedSetter(self.state, newValue))
            })
    }
}
#endif
