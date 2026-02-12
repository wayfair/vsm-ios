//
//  DebouncedChangeModifier.swift
//  VSM
//
//  Created by Bill Dunay on 2/12/26.
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
///
/// ## Implementation Details
///
/// This modifier uses AsyncStream with Swift Async Algorithms' `debounce` to implement the debouncing behavior:
///
/// 1. **Value Collection**: When the observed value changes, it's yielded to an AsyncStream via the continuation.
///    The stream uses `.bufferingNewest(1)` policy, which means only the latest value is kept if multiple values
///    are yielded before the debounce processes them.
///
/// 2. **Debouncing**: The stream is piped through `.debounce(for:)` which delays emission until the specified
///    duration has elapsed with no new values. This is more efficient than creating/cancelling Tasks manually.
///
/// 3. **Previous Value Tracking**: We maintain `previousValue` in @State to provide the "old value" to the action.
///    This is updated both when values are yielded (in onChange) and when they're processed (in the debounce loop).
///
/// 4. **Lifecycle Management**:
///    - `onAppear`: Creates the stream, starts the consumption task
///    - `onDisappear`: Finishes the stream and cancels the task to prevent leaks
///
/// ## Why AsyncStream + debounce?
///
/// We chose this approach over manual Task.sleep() because:
/// - Less boilerplate and state management
/// - Built-in debounce logic from Swift Async Algorithms is well-tested
/// - Cleaner separation: stream handles collection, debounce handles timing
/// - No need to manually track and cancel intermediate tasks
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
            .onChange(of: value, initial: false) { oldValue, newValue in
                continuation?.yield(newValue)
                previousValue = newValue
            }
    }
}

/// Debounced change modifier with manual cancellation via a Boolean binding.
///
/// ## Implementation Details
///
/// This extends the basic debounced modifier with the ability to cancel and reset the debounce operation
/// via a Boolean binding. When `cancelSignal` is set to `true`:
///
/// 1. The current consumption task is cancelled
/// 2. The old stream is finished (preventing memory leaks)
/// 3. A new stream and continuation are created
/// 4. A new consumption task is started
/// 5. The `cancelSignal` is reset to `false`
///
/// This is useful when you need to programmatically cancel pending operations, such as when clearing
/// a search field or navigating away from a screen.
///
/// ## Why recreate the stream?
///
/// We can't just cancel the task and restart it with the same stream because:
/// - The debounce operator maintains internal timing state
/// - We want a clean slate for the debounce timer
/// - Finishing and recreating ensures no stale values linger in the buffer
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
            .onChange(of: value, initial: false) { oldValue, newValue in
                continuation?.yield(newValue)
                previousValue = newValue
            }
            .onChange(of: cancelSignal, initial: false) { oldValue, newValue in
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
///
/// ## Implementation Details
///
/// This variant provides a stable cancel closure that can be stored and invoked at any time.
/// The key challenge here is providing a `@Sendable` closure that can safely access and mutate
/// @State properties across actor boundaries.
///
/// ### The Stable Cancel Closure Pattern
///
/// The cancel closure is created once in `onAppear` and stored in `@State`. This closure:
///
/// 1. Is marked `@Sendable` so it can be passed around safely in concurrent contexts
/// 2. Captures `self` to access the modifier's @State properties
/// 3. Wraps its work in `Task { @MainActor ... }` to ensure all state mutations happen on the main actor
/// 4. References `self.cancelClosure` when recreating the stream, ensuring the same stable closure
///    is passed to subsequent action invocations
///
/// ### Why a stable closure matters
///
/// Without storing the closure in @State and reusing it:
/// - Each invocation of the action would get a different cancel closure instance
/// - If the user stores the cancel closure, it might become stale after being called once
/// - The closure reference wouldn't be stable throughout the view's lifetime
///
/// With our approach:
/// - The same closure reference is used throughout the view's lifetime
/// - The closure always operates on the current task/continuation via `self`
/// - Users can safely store and invoke the closure at any point
///
/// ### Memory Management
///
/// The cancel closure captures `self`, but this is safe because:
/// - ViewModifiers are value types, so there's no reference cycle
/// - The closure is stored in @State which is owned by the view
/// - When the view disappears, all @State is cleaned up
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
                // Create stable cancel closure once
                let cancel: @Sendable () -> Void = { @Sendable in
                    Task { @MainActor [self] in
                        self.task?.cancel()
                        self.continuation?.finish()
                        
                        let (newStream, newCont) = AsyncStream<V>.makeStream(bufferingPolicy: .bufferingNewest(1))
                        self.continuation = newCont
                        
                        // Use the stored stable cancel closure
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
            .onChange(of: value, initial: false) { oldValue, newValue in
                continuation?.yield(newValue)
                previousValue = newValue
            }
    }
}
