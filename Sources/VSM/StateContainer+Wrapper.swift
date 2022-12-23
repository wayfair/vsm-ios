//
//  ViewState+Wrapper.swift
//  
//
//  Created by Albert Bori on 12/20/22.
//

import Combine
import Foundation
import SwiftUI

@available(iOS 14.0, *)
public extension StateContainer {
    /// Used by view state property wrappers as a projected value.
    struct Wrapper {
        public var container: StateContainer<State>
        
        // MARK: Publisher
        
        public var publisher: AnyPublisher<State, Never> {
            container.statePublisher
        }
        
        // MARK: - Observe
        
        /// Convenience accessor for the `StateContainer`'s `observe` function.
        /// Observes the state publisher emitted as a result of invoking some action
        public func observe(_ stateChangePublisher: AnyPublisher<State, Never>) {
            container.observe(stateChangePublisher)
        }

        /// Convenience accessor for the `StateContainer`'s `observe` function.
        /// Observes the state emitted as a result of invoking some asynchronous action
        public func observe(_ awaitState: @escaping () async -> State) {
            container.observe(awaitState)
        }
        
        /// Convenience accessor for the `StateContainer`'s `observe` function.
        /// Observes the states emitted as a result of invoking some asynchronous action that returns an asynchronous sequence
        public func observe<StateSequence: AsyncSequence>(_ awaitStateSequence: @escaping () async -> StateSequence) where StateSequence.Element == State {
            container.observe(awaitStateSequence)
        }

        /// Convenience accessor for the `StateContainer`'s `observe` function.
        /// Observes the state emitted as a result of invoking some synchronous action
        public func observe(_ nextState: @autoclosure @escaping () -> State) {
            container.observe(nextState)
        }
        
        // MARK: - Observe Debounce
        
        /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
        /// Prevents actions from being excessively called when bound to noisy UI events.
        /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
        /// - Parameters:
        ///   - stateChangePublisherAction: The action to be debounced before invoking
        ///   - dueTime: The amount of time required to pass before invoking the most recent action
        public func observe(
            _ stateChangePublisherAction: @escaping @autoclosure () -> AnyPublisher<State, Never>,
            debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
            file: String = #file,
            line: UInt = #line
        ) {
            container.observe(stateChangePublisherAction(), debounced: dueTime, file: file, line: line)
        }
        
        /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
        /// Prevents actions from being excessively called when bound to noisy UI events.
        /// Action calls are grouped by the provided `identifier`.
        /// - Parameters:
        ///   - stateChangePublisherAction: The action to be debounced before invoking
        ///   - dueTime: The amount of time required to pass before invoking the most recent action
        ///   - identifier: The identifier for grouping actions for debouncing
        public func observe(
            _ stateChangePublisherAction: @escaping @autoclosure () ->  AnyPublisher<State, Never>,
            debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
            identifier: AnyHashable
        ) {
            container.observe(stateChangePublisherAction(), debounced: dueTime, identifier: identifier)
        }
        
        /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
        /// Prevents actions from being excessively called when bound to noisy UI events.
        /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
        /// - Parameters:
        ///   - stateChangeAsyncAction: The action to be debounced before invoking
        ///   - dueTime: The amount of time required to pass before invoking the most recent action
        public func observe(
            _ stateChangeAsyncAction: @escaping () async -> State,
            debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
            file: String = #file,
            line: UInt = #line
        ) {
            container.observe(stateChangeAsyncAction, debounced: dueTime, file: file, line: line)
        }
        
        /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
        /// Prevents actions from being excessively called when bound to noisy UI events.
        /// Action calls are grouped by the provided `identifier`.
        /// - Parameters:
        ///   - stateChangeAsyncAction: The action to be debounced before invoking
        ///   - dueTime: The amount of time required to pass before invoking the most recent action
        ///   - identifier: The identifier for grouping actions for debouncing
        public func observe(
            _ stateChangeAsyncAction: @escaping () async -> State,
            debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
            identifier: AnyHashable
        ) {
            container.observe(stateChangeAsyncAction, debounced: dueTime, identifier: identifier)
        }
        
        /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
        /// Prevents actions from being excessively called when bound to noisy UI events.
        /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
        /// - Parameters:
        ///   - stateChangeAsyncSequenceAction: The action to be debounced before invoking
        ///   - dueTime: The amount of time required to pass before invoking the most recent action
        public func observe<SomeAsyncSequence: AsyncSequence>(
            _ stateChangeAsyncSequenceAction: @escaping () async -> SomeAsyncSequence,
            debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
            file: String = #file,
            line: UInt = #line
        ) where SomeAsyncSequence.Element == State {
            container.observe(stateChangeAsyncSequenceAction, debounced: dueTime, file: file, line: line)
        }
        
        /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
        /// Prevents actions from being excessively called when bound to noisy UI events.
        /// Action calls are grouped by the provided `identifier`.
        /// - Parameters:
        ///   - stateChangeAsyncSequenceAction: The action to be debounced before invoking
        ///   - dueTime: The amount of time required to pass before invoking the most recent action
        ///   - identifier: The identifier for grouping actions for debouncing
        public func observe<SomeAsyncSequence: AsyncSequence>(
            _ stateChangeAsyncSequenceAction: @escaping () async -> SomeAsyncSequence,
            debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
            identifier: AnyHashable
        ) where SomeAsyncSequence.Element == State {
            container.observe(stateChangeAsyncSequenceAction, debounced: dueTime, identifier: identifier)
        }
        
        /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
        /// Prevents actions from being excessively called when bound to noisy UI events.
        /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
        /// - Parameters:
        ///   - stateChangeAction: The action to be debounced before invoking
        ///   - dueTime: The amount of time required to pass before invoking the most recent action
        public func observe(
            _ stateChangeAction: @escaping @autoclosure () -> State,
            debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
            file: String = #file,
            line: UInt = #line
        ) {
            container.observe(stateChangeAction(), debounced: dueTime, file: file, line: line)
        }
        
        /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
        /// Prevents actions from being excessively called when bound to noisy UI events.
        /// Action calls are grouped by the provided `identifier`.
        /// - Parameters:
        ///   - stateChangeAction: The action to be debounced before invoking
        ///   - dueTime: The amount of time required to pass before invoking the most recent action
        ///   - identifier: The identifier for grouping actions for debouncing
        public func observe(
            _ stateChangeAction: @escaping @autoclosure () -> State,
            debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
            identifier: AnyHashable
        ) {
            container.observe(stateChangeAction(), debounced: dueTime, identifier: identifier)
        }
        
        // MARK: - Bind
        
        /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
        /// **Not intended for use when`ViewState` is an enum.**
        /// - Parameters:
        ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
        ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
        /// - Returns: A `Binding<Value>` for use in SwiftUI controls
        public func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> State) -> Binding<Value> {
            container.bind(stateKeyPath, to: observedSetter)
        }
        
        /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
        /// **This doesn't work when`ViewState` is an enum**
        /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
        /// - Parameters:
        ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
        ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
        /// - Returns: A `Binding<Value>` for use in SwiftUI controls
        public func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> State) -> Binding<Value> {
            container.bind(stateKeyPath, to: observedSetter)
        }
        
        /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a basic closure.
        /// **Not intended for use when`ViewState` is an enum.**
        /// - Parameters:
        ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
        ///   - observedSetter: Converts the new `Value` to a new `ViewState`, which is automatically observed
        /// - Returns: A `Binding<Value>` for use in SwiftUI controls
        public func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State, Value) -> AnyPublisher<State, Never>) -> Binding<Value> {
            container.bind(stateKeyPath, to: observedSetter)
        }
        
        /// Creates a unidirectional, auto-observing `Binding<Value>` for the `ViewState` using a `KeyPath` and a *method signature*
        /// **Not intended for use when`ViewState` is an enum.**
        /// Example usage: `bind(\.someModelProperty, to: ViewState.someModelMethod)`
        /// - Parameters:
        ///   - stateKeyPath: `KeyPath` for a `Value` of the `ViewState`
        ///   - observedSetter: A **method signature** which converts the new `Value` to a new `ViewState` and is automatically observed
        /// - Returns: A `Binding<Value>` for use in SwiftUI controls
        public func bind<Value>(_ stateKeyPath: KeyPath<State, Value>, to observedSetter: @escaping (State) -> (Value) -> AnyPublisher<State, Never>) -> Binding<Value> {
            container.bind(stateKeyPath, to: observedSetter)
        }
    }
}
