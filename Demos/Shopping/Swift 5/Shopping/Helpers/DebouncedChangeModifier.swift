//
//  DebouncedChangeModifier.swift
//  Shopping
//
//  Demonstrates debouncing SwiftUI input using Async Algorithms' `debounce` on an `AsyncStream`.
//  Copied from the VSM package for the demo app; the VSM library does not ship this modifier.
//

import AsyncAlgorithms
import SwiftUI

extension View {
    // MARK: - Basic version (old and new values)

    /// Adds a modifier for this view that fires an action when a specific value changes, debouncing the changes.
    ///
    /// This debounced version of `onChange` delays the execution of the action until a specified duration has passed
    /// without the value changing. This is particularly useful for scenarios like search-as-you-type where you want
    /// to avoid triggering expensive operations (like network requests) on every keystroke.
    ///
    /// Unlike the standard `onChange` modifier, this version waits for a "quiet period" before firing. If the value
    /// changes multiple times in rapid succession, only the final value (after the quiet period) triggers the action.
    ///
    /// - Parameters:
    ///   - value: The value to check against when determining whether to run the closure.
    ///   - duration: The debounce duration. The action will only fire after this much time has elapsed with no changes to the value.
    ///   - initial: Whether the action should be run when the view initially appears. Defaults to `false`.
    ///   - action: A closure to run when the value changes after the debounce period. The closure receives both the old and new values.
    ///
    /// - Returns: A view that fires an action when the specified value changes, debounced by the given duration.
    ///
    /// ## Example
    /// ```swift
    /// @State private var searchQuery = ""
    ///
    /// TextField("Search", text: $searchQuery)
    ///     .onChange(of: searchQuery, debounce: .milliseconds(300)) { oldValue, newValue in
    ///         await viewState.observe(viewState.current.search(query: newValue))
    ///     }
    /// ```
    ///
    /// In this example, if the user types "hello" quickly, the search will only trigger once after they stop typing
    /// for 300 milliseconds, rather than triggering 5 times (once for each letter).
    public func onChange<V: Equatable & Sendable>(
        of value: V,
        debounce duration: Duration,
        initial: Bool = false,
        _ action: @escaping @MainActor @Sendable (V, V) -> Void
    ) -> some View {
        self.modifier(DebouncedChangeModifier(
            value: value,
            duration: duration,
            initial: initial,
            action: action
        ))
    }

    // MARK: - With cancel signal

    /// Adds a modifier for this view that fires an action when a specific value changes, debouncing the changes,
    /// with the ability to manually cancel pending debounced actions via a binding.
    ///
    /// This variant provides a `cancelSignal` binding that allows you to programmatically cancel any pending
    /// debounced action and reset the debounce timer. When the binding is set to `true`, the current debounce
    /// operation is cancelled, the stream is reset, and the binding is automatically set back to `false`.
    ///
    /// - Parameters:
    ///   - value: The value to check against when determining whether to run the closure.
    ///   - duration: The debounce duration. The action will only fire after this much time has elapsed with no changes to the value.
    ///   - initial: Whether the action should be run when the view initially appears. Defaults to `false`.
    ///   - cancelSignal: A binding to a Boolean value that cancels the pending debounced action when set to `true`.
    ///   - action: A closure to run when the value changes after the debounce period. The closure receives both the old and new values.
    ///
    /// - Returns: A view that fires an action when the specified value changes, debounced by the given duration.
    ///
    /// ## Example
    /// ```swift
    /// @State private var searchQuery = ""
    /// @State private var cancelSearch = false
    ///
    /// VStack {
    ///     TextField("Search", text: $searchQuery)
    ///         .onChange(of: searchQuery, debounce: .milliseconds(300), cancelSignal: $cancelSearch) { oldValue, newValue in
    ///             await viewState.observe(viewState.current.search(query: newValue))
    ///         }
    ///
    ///     Button("Clear") {
    ///         searchQuery = ""
    ///         cancelSearch = true  // Cancels any pending search
    ///     }
    /// }
    /// ```
    public func onChange<V: Equatable & Sendable>(
        of value: V,
        debounce duration: Duration,
        initial: Bool = false,
        cancelSignal: Binding<Bool>,
        _ action: @escaping @MainActor @Sendable (V, V) -> Void
    ) -> some View {
        self.modifier(DebouncedChangeModifierWithSignal(
            value: value,
            duration: duration,
            initial: initial,
            cancelSignal: cancelSignal,
            action: action
        ))
    }

    // MARK: - With cancel callback

    /// Adds a modifier for this view that fires an action when a specific value changes, debouncing the changes,
    /// with the ability to manually cancel pending debounced actions via a callback.
    ///
    /// This variant provides a cancel callback as a third parameter to the action closure. This callback can be
    /// invoked at any time to cancel the current debounce operation and reset the stream. The cancel callback
    /// is stable throughout the view's lifetime and can be safely stored and called later.
    ///
    /// - Parameters:
    ///   - value: The value to check against when determining whether to run the closure.
    ///   - duration: The debounce duration. The action will only fire after this much time has elapsed with no changes to the value.
    ///   - initial: Whether the action should be run when the view initially appears. Defaults to `false`.
    ///   - action: A closure to run when the value changes after the debounce period. The closure receives the old value, new value, and a cancel callback.
    ///
    /// - Returns: A view that fires an action when the specified value changes, debounced by the given duration.
    ///
    /// ## Example
    /// ```swift
    /// @State private var searchQuery = ""
    ///
    /// TextField("Search", text: $searchQuery)
    ///     .onChange(of: searchQuery, debounce: .milliseconds(300)) { oldValue, newValue, cancel in
    ///         if newValue.isEmpty {
    ///             cancel()  // Don't search for empty strings
    ///             return
    ///         }
    ///         await viewState.observe(viewState.current.search(query: newValue))
    ///     }
    /// ```
    public func onChange<V: Equatable & Sendable>(
        of value: V,
        debounce duration: Duration,
        initial: Bool = false,
        _ action: @escaping @MainActor @Sendable (V, V, @escaping @Sendable () -> Void) -> Void
    ) -> some View {
        self.modifier(DebouncedChangeModifierWithCallback(
            value: value,
            duration: duration,
            initial: initial,
            action: action
        ))
    }
}

// MARK: - View Modifiers

/// Basic debounced change modifier that provides old and new values to the action closure.
private struct DebouncedChangeModifier<V: Equatable & Sendable>: ViewModifier {
    let value: V
    let duration: Duration
    let initial: Bool
    let action: @MainActor @Sendable (V, V) -> Void

    @State private var continuation: AsyncStream<V>.Continuation?
    @State private var task: Task<Void, Never>?
    @State private var hasAppeared = false
    @State private var previousValue: V?

    func body(content: Content) -> some View {
        content
            .onAppear {
                let (stream, cont) = AsyncStream<V>.makeStream(bufferingPolicy: .bufferingNewest(1))
                continuation = cont

                if initial && !hasAppeared {
                    action(value, value)
                    hasAppeared = true
                }
                previousValue = value

                task = Task { @MainActor in
                    for await debouncedValue in stream.debounce(for: duration) {
                        let oldValue = previousValue ?? debouncedValue
                        action(oldValue, debouncedValue)
                        previousValue = debouncedValue
                    }
                }
            }
            .onDisappear {
                continuation?.finish()
                task?.cancel()
            }
            .onChange(of: value, initial: false) { _, newValue in
                continuation?.yield(newValue)
                previousValue = newValue
            }
    }
}

/// Debounced change modifier with manual cancellation via a Boolean binding.
private struct DebouncedChangeModifierWithSignal<V: Equatable & Sendable>: ViewModifier {
    let value: V
    let duration: Duration
    let initial: Bool
    @Binding var cancelSignal: Bool
    let action: @MainActor @Sendable (V, V) -> Void

    @State private var continuation: AsyncStream<V>.Continuation?
    @State private var task: Task<Void, Never>?
    @State private var hasAppeared = false
    @State private var previousValue: V?

    func body(content: Content) -> some View {
        content
            .onAppear {
                let (stream, cont) = AsyncStream<V>.makeStream(bufferingPolicy: .bufferingNewest(1))
                continuation = cont

                if initial && !hasAppeared {
                    action(value, value)
                    hasAppeared = true
                }
                previousValue = value

                task = Task { @MainActor in
                    for await debouncedValue in stream.debounce(for: duration) {
                        let oldValue = previousValue ?? debouncedValue
                        action(oldValue, debouncedValue)
                        previousValue = debouncedValue
                    }
                }
            }
            .onDisappear {
                continuation?.finish()
                task?.cancel()
            }
            .onChange(of: value, initial: false) { _, newValue in
                continuation?.yield(newValue)
                previousValue = newValue
            }
            .onChange(of: cancelSignal, initial: false) { _, newValue in
                if newValue {
                    task?.cancel()
                    continuation?.finish()

                    let (stream, cont) = AsyncStream<V>.makeStream(bufferingPolicy: .bufferingNewest(1))
                    continuation = cont

                    task = Task { @MainActor in
                        for await debouncedValue in stream.debounce(for: duration) {
                            let oldVal = previousValue ?? debouncedValue
                            action(oldVal, debouncedValue)
                            previousValue = debouncedValue
                        }
                    }

                    cancelSignal = false
                }
            }
    }
}

/// Debounced change modifier with manual cancellation via a stable callback closure.
private struct DebouncedChangeModifierWithCallback<V: Equatable & Sendable>: ViewModifier {
    let value: V
    let duration: Duration
    let initial: Bool
    let action: @MainActor @Sendable (V, V, @escaping @Sendable () -> Void) -> Void

    @State private var continuation: AsyncStream<V>.Continuation?
    @State private var task: Task<Void, Never>?
    @State private var hasAppeared = false
    @State private var previousValue: V?
    @State private var cancelClosure: (@Sendable () -> Void)?

    func body(content: Content) -> some View {
        content
            .onAppear {
                let cancel: @Sendable () -> Void = { @Sendable in
                    Task { @MainActor [self] in
                        self.task?.cancel()
                        self.continuation?.finish()

                        let (newStream, newCont) = AsyncStream<V>.makeStream(bufferingPolicy: .bufferingNewest(1))
                        self.continuation = newCont

                        if let stableCancel = self.cancelClosure {
                            self.task = Task { @MainActor in
                                for await debouncedValue in newStream.debounce(for: self.duration) {
                                    let oldValue = self.previousValue ?? debouncedValue
                                    self.action(oldValue, debouncedValue, stableCancel)
                                    self.previousValue = debouncedValue
                                }
                            }
                        }
                    }
                }
                cancelClosure = cancel

                let (stream, cont) = AsyncStream<V>.makeStream(bufferingPolicy: .bufferingNewest(1))
                continuation = cont

                if initial && !hasAppeared {
                    action(value, value, cancel)
                    hasAppeared = true
                }
                previousValue = value

                task = Task { @MainActor in
                    for await debouncedValue in stream.debounce(for: duration) {
                        let oldValue = previousValue ?? debouncedValue
                        action(oldValue, debouncedValue, cancel)
                        previousValue = debouncedValue
                    }
                }
            }
            .onDisappear {
                continuation?.finish()
                task?.cancel()
            }
            .onChange(of: value, initial: false) { _, newValue in
                continuation?.yield(newValue)
                previousValue = newValue
            }
    }
}
