//
//  AsyncStateContainer.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

#if canImport(Observation)
import AsyncAlgorithms
@preconcurrency import Combine
import Foundation
import Observation
import os.signpost

/// A container that manages state changes on the main thread while allowing state production on any thread.
///
/// `AsyncStateContainer` provides thread-safe state management by guaranteeing that all state changes occur
/// on the main thread, while the code that produces the next state can run on any thread. This design leverages
/// Swift 6's built-in concurrency features including `Task`, `Task.detached`, `@concurrent`, and `@MainActor`.
///
/// ## Thread Safety
///
/// The container ensures thread safety through the following guarantees:
/// - State changes always occur on the `@MainActor` (main thread)
/// - State production closures can run on any thread, controlled by Swift's concurrency model
/// - Observation methods handle thread context automatically
///
/// ### Atomicity and Property Access
///
/// **All properties in this class are thread-safe and atomic** due to `@MainActor` isolation:
/// - The `@MainActor` attribute on the class ensures all property access (reads and writes) is serialized
/// - Swift's actor isolation guarantees that only one piece of code can access the instance at a time
/// - No additional synchronization primitives (locks, atomics, etc.) are needed
/// - This applies to both public (`state`) and private properties (`stateTask`, `streamContinuation`, etc.)
///
/// When modifying this class, maintainers should ensure all property access remains within `@MainActor`
/// context. Actor isolation automatically handles thread synchronization, preventing data races.
///
/// ## Error Handling
///
/// `AsyncStateContainer` follows a never-throwing design philosophy:
/// - Does not accept closures that produce state and also throw
/// - Does not accept `AsyncSequence` types that can error
/// - Only works with sequences whose `Failure` type is `Never`
/// - Supports non-throwing `AsyncStream<State>` and `StateSequence<State>`
///
/// ## State Models and Actions
///
/// In VSM, state models contain the actions available in a given state. For example, when your view
/// state is defined as an enum, each case can have an associated **state model**. This pattern provides
/// benefits such as:
/// - Each state has a well-defined, limited set of actions
/// - Actions are only available when they make sense for the current state
/// - The compiler enforces that you handle all states in your view
///
/// > Note: Enums are a common choice for view states, but not the only one. You can use structs or
/// > other data types depending on the shape of your feature. See <doc:StateDefinition> for examples
/// > of alternative view state shapes.
///
/// ### Defining State Models
///
/// Every state that can perform actions should have an associated state model type:
///
/// ```swift
/// enum ExampleViewState {
///     case initialized(InitializedModel)  // Has a load() action
///     case loading                         // No actions - just shows progress
///     case loaded(LoadedModel)             // Has refresh(), delete() actions
///     case loadedEmpty(LoadedEmptyModel)   // Has refresh() action
///     case error(ErrorModel)               // Has retry() action
/// }
/// ```
///
/// States like `.loading` that don't need actions don't require an associated model.
///
/// ### Adding New Actions
///
/// When you need to add a new action to a state:
/// 1. Add a method to the state's model that returns `State`, `StateSequence<State>`, or `AsyncStream<State>`
/// 2. If the state doesn't have an associated model yet, create one
/// 3. Never add actions directly in the view - always define them on state models
///
/// ### Sharing Actions Between States
///
/// When multiple states need the same action (e.g., both `loaded` and `loadedEmpty` need a `refresh` action),
/// use a protocol to share the implementation:
///
/// ```swift
/// protocol Refreshable {
///     var repository: ItemRepository { get }
/// }
///
/// extension Refreshable {
///     func refresh() -> StateSequence<ExampleViewState> {
///         StateSequence(
///             { .loading },
///             { await self.fetchItems() }
///         )
///     }
///     
///     @concurrent
///     private func fetchItems() async -> ExampleViewState {
///         do {
///             let items = try await repository.fetchItems()
///             if items.isEmpty {
///                 return .loadedEmpty(LoadedEmptyModel(repository: repository))
///             }
///             return .loaded(LoadedModel(items: items, repository: repository))
///         } catch {
///             return .error(ErrorModel(error: error, retry: { await self.fetchItems() }))
///         }
///     }
/// }
///
/// struct LoadedModel: Refreshable {
///     let items: [Item]
///     let repository: ItemRepository
/// }
///
/// struct LoadedEmptyModel: Refreshable {
///     let repository: ItemRepository
/// }
/// ```
///
/// This pattern ensures both states have access to the same `refresh()` action without code duplication,
/// while still maintaining separate model types that can have their own state-specific actions.
///
/// ## Usage
///
/// You interact with `AsyncStateContainer` through the `@ViewState` property wrapper in SwiftUI views:
///
/// ```swift
/// struct ExampleView: View {
///     @ViewState var state = ExampleViewState.initialized(InitializedViewStateModel())
///     
///     var body: some View {
///         switch state {
///         case .initialized(let viewModel):
///             HStack {
///                 Color.clear
///                     .onAppear {
///                         $state.observe(viewModel.load())
///                     }
///             }
///         case .loading:
///             ProgressView()
///         case .loaded(let model):
///             ContentView(model: model)
///         case .error(let error):
///             ErrorView(error: error)
///         }
///     }
/// }
/// ```
///
/// ## Debugging
///
/// `AsyncStateContainer` supports debug logging to help you trace state changes during development.
/// When enabled, state changes are logged to the Console using Apple's unified logging system (`os_log`)
/// at the `.debug` level.
///
/// Logging is disabled by default to avoid flooding the Console. You can enable it on a per-view basis
/// by setting `loggingEnabled: true` when initializing the `@ViewState` or `@RenderedViewState` property wrapper.
///
/// When logging is enabled, you'll see messages like:
/// - `"observe(State) called"` - when a synchronous state observation begins
/// - `"observe(StateSequence) called"` - when a sequence observation begins
/// - `"State changed to: <state>"` - when the state actually changes
/// - `"StateSequence completed after N state changes"` - when a sequence finishes
///
/// If your state type conforms to `CustomDebugStringConvertible`, the `debugDescription` will be used
/// in log output for more readable state representations.
///
/// - Note: All state changes are automatically published to SwiftUI views through the `@Observable` macro.
@Observable
@MainActor
public final class AsyncStateContainer<State: Sendable>: Sendable, StateObserving {
    /// The current state of the container.
    ///
    /// This property is observable and will trigger view updates when changed.
    /// All changes to this property are guaranteed to occur on the main thread.
    public private(set) var state: State
    
    // MARK: - Private Properties
    // All properties below are thread-safe and atomic due to @MainActor isolation.
    // No additional synchronization is needed - actor isolation handles all thread safety.
    
    @ObservationIgnored
    private var stateTask: Task<Void, Never>?

    @ObservationIgnored
    private var publisherCancellable: AnyCancellable?
    
    // MARK: - Debug-only Testing Infrastructure
    //
    // The following properties support `stateChangeStream(last:timeout:)`, an internal method
    // used exclusively by this package's own unit tests. They are excluded from non-DEBUG builds
    // to keep release binaries free of test-only code. `internal` access control prevents
    // external callers from reaching this API even in DEBUG builds.
    //
    // See the "Internal Testing Extension" section at the bottom of this file for usage details.
    #if DEBUG
    @ObservationIgnored
    private var streamContinuation: AsyncStream<State>.Continuation?
    
    @ObservationIgnored
    private var numberOfWatchedStates: Int = 0
    
    @ObservationIgnored
    private var stateChanges: Int = 0
    
    @ObservationIgnored
    private var streamTimeoutTask: Task<Void, Never>?
    #endif
    
    @ObservationIgnored
    private let logger: OSLog
    
    @ObservationIgnored
    private let signposter: OSSignposter
    
    @ObservationIgnored
    private let loggingEnabled: Bool
    
    init(state: State, logger: OSLog, loggingEnabled: Bool = false) {
        self.state = state
        self.logger = logger
        self.signposter = OSSignposter(logHandle: logger)
        self.loggingEnabled = loggingEnabled
    }
    
    deinit {
        stateTask?.cancel()
        publisherCancellable?.cancel()
        #if DEBUG
        // Clean up testing infrastructure. See the debug-only properties above for context.
        streamTimeoutTask?.cancel()
        streamContinuation?.finish()
        streamContinuation = nil
        #endif
    }
}

public extension AsyncStateContainer {

    // MARK: - Observe Single State Change Functions

    /// Immediately updates the container's state to the provided value.
    ///
    /// This method cancels any ongoing state observations and synchronously updates the state
    /// on the main thread. Use this method when you have a state value ready and want to
    /// update immediately without any asynchronous work.
    ///
    /// - Parameter nextState: The new state value to set.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct ExampleView: View {
    ///     @ViewState var state = ExampleViewState.initialized(.init())
    ///     
    ///     var body: some View {
    ///         switch state {
    ///         case .initialized(let viewModel):
    ///             HStack {
    ///                 Color.clear
    ///                     .onAppear {
    ///                         $state.observe(viewModel.load())
    ///                     }
    ///             }
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///                 .toolbar {
    ///                     Button("Retry") {
    ///                         $state.observe(viewModel.load())
    ///                     }
    ///                 }
    ///         case .error(let error):
    ///             ErrorView(error: error)
    ///         }
    ///     }
    /// }
    /// ```
    func observe(_ nextState: State) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(State) called")
        }
        
        cancelRunningObservations()
        stateChanges = 0
        
        let signpostId = signposter.makeSignpostID()
        let postName: StaticString = "State"
        let state = signposter.beginInterval(postName, id: signpostId)
        
        performStateChange(nextState)
        
        signposter.endInterval(postName, state)
    }
    
    /// Observes and updates the state using an asynchronous closure.
    ///
    /// This method executes the provided closure asynchronously to produce the next state.
    /// The closure can run on any thread based on Swift's concurrency model, but the resulting
    /// state change is guaranteed to occur on the main thread. The method returns immediately
    /// without waiting for the closure to complete.
    ///
    /// Any ongoing state observations are cancelled before starting the new observation.
    /// If the observation task is cancelled before completion, the state will not be updated.
    ///
    /// - Parameter nextStateClosure: An async closure that produces the next state value.
    ///                                This closure must not throw errors and must be `@Sendable`,
    ///                                meaning all captured values must be thread-safe.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct ExampleView: View {
    ///     @ViewState var state = ExampleViewState.initialized(.init())
    ///     
    ///     var body: some View {
    ///         switch state {
    ///         case .initialized(let viewModel):
    ///             HStack {
    ///                 Color.clear
    ///                     .onAppear {
    ///                         $state.observe(viewModel.load())
    ///                     }
    ///             }
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///         case .error(let viewModel):
    ///             ErrorView(viewModel: viewModel)
    ///                 .toolbar {
    ///                     Button("Retry") {
    ///                         $state.observe { await viewModel.retry() }
    ///                     }
    ///                 }
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: The closure is captured with `@escaping @Sendable` and executed within a `Task` on the main actor.
    ///         The `@Sendable` requirement ensures thread-safe capture of values that may be accessed
    ///         across different concurrency domains.
    func observe(_ nextStateClosure: @escaping @Sendable () async -> State) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(async closure) called")
        }
        
        cancelRunningObservations()
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            let signpostId = signposter.makeSignpostID()
            let postName: StaticString = "State"
            let state = signposter.beginInterval(postName, id: signpostId)
            defer { signposter.endInterval(postName, state) }
            
            let nextStateValue = await nextStateClosure()
            
            guard Task.isCancelled == false else {
                if self.loggingEnabled {
                    os_log(.debug, log: self.logger, "observe(async closure) cancelled before state change")
                }
                return
            }
            
            self.performStateChange(nextStateValue)
        }
    }
    
    /// Refreshes the state using an asynchronous closure, suspending until complete.
    ///
    /// This method executes the provided closure asynchronously to produce the next state,
    /// suspending the caller until the state has been produced and applied. Unlike ``observe(_:)-(State)``,
    /// this method waits for the state production to complete before returning.
    ///
    /// The closure can run on any thread based on Swift's concurrency model, but the resulting
    /// state change is guaranteed to occur on the main thread. Any ongoing state observations
    /// are cancelled before starting the new observation.
    ///
    /// If the observation task is cancelled before completion, the state will not be updated
    /// and the method will return early.
    ///
    /// - Parameter nextState: An async closure that produces the next state value.
    ///                        This closure must not throw errors and must be `@Sendable`,
    ///                        meaning all captured values must be thread-safe.
    ///
    /// ## Pull-to-Refresh Support
    ///
    /// This method is specifically designed to enable pull-to-refresh (PTR) functionality in
    /// VSM-managed SwiftUI views. SwiftUI's `refreshable` view modifier requires an async
    /// closure that suspends until the refresh operation completes. By using `refresh(state:)`,
    /// the refresh indicator will remain visible until the state has been updated.
    ///
    /// The `refreshable` modifier can be applied to scrollable views like `List` and `ScrollView`,
    /// providing users with a standard pull-to-refresh gesture to manually update content.
    ///
    /// ## Example
    ///
    /// First, define a state model that implements a `refresh()` action returning the next state:
    ///
    /// ```swift
    /// struct LoadedViewStateModel: Sendable {
    ///     let items: [Item]
    ///     private let repository: ItemRepository
    ///     
    ///     func refresh() async -> ExampleViewState {
    ///         do {
    ///             let freshItems = try await repository.fetchItems()
    ///             return .loaded(LoadedViewStateModel(items: freshItems, repository: repository))
    ///         } catch {
    ///             // Return the current state with items preserved, or handle error as appropriate
    ///             return .loaded(self)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// Then use the `refresh(state:)` method in your view's `refreshable` modifier:
    ///
    /// ```swift
    /// struct ExampleView: View {
    ///     @ViewState var state = ExampleViewState.loaded(LoadedViewStateModel())
    ///     
    ///     var body: some View {
    ///         switch state {
    ///         case .loaded(let model):
    ///             List(model.items) { item in
    ///                 ItemRow(item: item)
    ///             }
    ///             .refreshable {
    ///                 await $state.refresh(state: {
    ///                     await model.refresh()
    ///                 })
    ///             }
    ///         default:
    ///             ProgressView()
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// In this example, when the user pulls down on the list, the refresh indicator appears
    /// and remains visible until the state update completes. The `refresh(state:)` method
    /// ensures the refresh operation fully completes before the indicator is dismissed.
    ///
    /// - Note: Use this method when you need to ensure the state update completes before
    ///         proceeding with subsequent operations, particularly with SwiftUI's `refreshable` modifier.
    ///         The closure must be `@Sendable` to ensure thread-safe capture of values that may be
    ///         accessed across different concurrency domains.
    func refresh(state nextState: @escaping @Sendable () async -> State) async {
        if loggingEnabled {
            os_log(.debug, log: logger, "refresh(state:) called")
        }
        
        cancelRunningObservations()
        let signpostId = signposter.makeSignpostID()
        let postName: StaticString = "Refresh"
        let state = signposter.beginInterval(postName, id: signpostId)
        defer { signposter.endInterval(postName, state) }
        
        let nextStateValue = await nextState()
        guard Task.isCancelled == false else {
            if loggingEnabled {
                os_log(.debug, log: logger, "refresh(state:) cancelled before state change")
            }
            return
        }
        performStateChange(nextStateValue)
    }
    
    // MARK: - Observe Sequence of State Changes Functions

    /// Observes and updates the state through a ``StateSequence``.
    ///
    /// Each state value produced by the sequence is applied to the container as it becomes
    /// available. The method returns immediately without waiting for the sequence to complete,
    /// and any ongoing state observation is cancelled before the new one begins.
    ///
    /// ## First-state timing: synchronous vs. asynchronous
    ///
    /// The behavior of the first state change depends on how the ``StateSequence`` was created:
    ///
    /// - **`@StateSequenceBuilder` with a plain `State` value before `Next`** — The first
    ///   plain `State` value is applied *synchronously*, in the same run-loop iteration as the
    ///   call to this method, before a `Task` is created. Any subsequent states produced by
    ///   `Next { ... }` expressions (or plain values that appear *after* a `Next`) are applied
    ///   asynchronously inside a `Task`. This means only the leading plain-value states are
    ///   synchronous; once async work begins, the rest of the sequence is async. Use this form
    ///   when you need the first state (e.g. `.loading`) to appear on the very first frame
    ///   SwiftUI renders—especially for your view's initial `onAppear` observation.
    ///
    /// - **Array literal or variadic ``StateSequence/init(_:)``** — All closures are async,
    ///   including the first one. The first state change happens after a `Task` has been
    ///   scheduled, meaning SwiftUI may render one frame of the previous state before the
    ///   first closure executes. This is generally fine for user-initiated actions that occur
    ///   after the view is already visible, where a brief delay is imperceptible.
    ///
    /// ## Choosing the right creation style
    ///
    /// For your view's first observation—typically called from `onAppear`—prefer
    /// `@StateSequenceBuilder` to ensure the transition state appears immediately:
    ///
    /// ```swift
    /// // Recommended for onAppear: first state is applied synchronously
    /// @StateSequenceBuilder
    /// func load() -> StateSequence<ExampleViewState> {
    ///     ExampleViewState.loading
    ///     Next { await self.fetchItems() }
    /// }
    /// ```
    ///
    /// For user-initiated actions on an already-visible view, the all-async form is fine:
    ///
    /// ```swift
    /// // Fine for button taps or other user actions
    /// func refresh() -> StateSequence<ExampleViewState> {
    ///     [
    ///         { .loading },
    ///         { await self.fetchItems() }
    ///     ]
    /// }
    /// ```
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct InitializedViewStateModel: Sendable {
    ///     private let repository: ItemRepository
    ///
    ///     @StateSequenceBuilder
    ///     func load() -> StateSequence<ExampleViewState> {
    ///         ExampleViewState.loading
    ///         Next { await self.fetchItems() }
    ///     }
    ///
    ///     @concurrent
    ///     private func fetchItems() async -> ExampleViewState {
    ///         do {
    ///             let items = try await repository.fetchItems()
    ///             return .loaded(LoadedViewStateModel(items: items, repository: repository))
    ///         } catch {
    ///             return .error(ErrorViewStateModel(error: error, retry: { await self.fetchItems() }))
    ///         }
    ///     }
    /// }
    ///
    /// struct ExampleView: View {
    ///     @ViewState var state = ExampleViewState.initialized(InitializedViewStateModel())
    ///
    ///     var body: some View {
    ///         switch state {
    ///         case .initialized(let viewModel):
    ///             Color.clear
    ///                 .onAppear {
    ///                     $state.observe(viewModel.load())
    ///                 }
    ///         case .loading:
    ///             ProgressView()
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///         case .error(let model):
    ///             ErrorView(model: model)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Parameter stateSequence: A ``StateSequence`` that produces a series of state values.
    ///                            ``StateSequence`` is designed to never throw; errors from async
    ///                            work should be caught and converted into appropriate error states.
    func observe(_ stateSequence: StateSequence<State>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(StateSequence) called")
        }
        
        cancelRunningObservations()
        stateChanges = 0
        
        // Begin signpost interval before any state changes so it spans the full observation.
        let sequenceID = signposter.makeSignpostID()
        let postName: StaticString = "Sequence"
        let sequenceState = signposter.beginInterval(postName, id: sequenceID, "State Sequence")
        
        // Apply all synchronous state actions inline on the current call stack
        // so they are applied in the same run loop iteration as the call to observe().
        for syncAction in stateSequence.synchronousStateActions {
            let syncState = syncAction()
            performStateChange(syncState)
            let eventName: StaticString = "StateSequence Changed State"
            signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: syncState))")
        }
        
        // If there are no async closures, the sequence is complete.
        guard !stateSequence.states.isEmpty else {
            let syncCount = stateSequence.synchronousStateActions.count
            if loggingEnabled {
                os_log(.debug, log: logger, "StateSequence completed after %d state changes", syncCount)
            }
            let endEventName: StaticString = "State Sequence Ended"
            signposter.emitEvent(endEventName, id: sequenceID, "Ended after \(syncCount) iterations")
            signposter.endInterval(postName, sequenceState)
            return
        }
        
        stateTask = Task { @MainActor [weak self, signposter] in
            guard let self else {
                signposter.endInterval(postName, sequenceState)
                return
            }
            defer { signposter.endInterval(postName, sequenceState) }
            
            // Iterate only the async closures (all synchronous actions, if any,
            // were already applied inline above before this Task was created).
            var iterationCount = stateSequence.synchronousStateActions.count + 1
            var remainingIterator = stateSequence.states.makeIterator()
            
            while !Task.isCancelled {
                guard let nextClosure = remainingIterator.next() else {
                    // Sequence completed naturally
                    if self.loggingEnabled {
                        os_log(.debug, log: self.logger, "StateSequence completed after %d state changes", iterationCount - 1)
                    }
                    let eventName: StaticString = "State Sequence Ended"
                    signposter.emitEvent(eventName, id: sequenceID,
                                         "Ended after \(iterationCount - 1) iterations")
                    break
                }
                
                let nextState = await nextClosure()
                
                guard !Task.isCancelled else {
                    if self.loggingEnabled {
                        os_log(.debug, log: self.logger, "StateSequence cancelled during iteration %d", iterationCount)
                    }
                    let eventName: StaticString = "State Sequence Cancelled"
                    signposter.emitEvent(eventName, id: sequenceID,
                                         "Cancelled during iteration \(iterationCount)")
                    break
                }
                self.performStateChange(nextState)
                
                // Emit an event to mark the state change
                // Note: Avoid accessing self.state in the message to prevent observation side effects
                let eventName: StaticString = "StateSequence Changed State"
                signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: nextState))")
                iterationCount += 1
            }
        }
    }
    
    /// Observes and updates the state from an `AsyncStream`.
    ///
    /// Each state value emitted by the stream is applied to the container as it becomes available.
    /// The method returns immediately without waiting for the stream to complete, and any ongoing
    /// state observation is cancelled before the new one begins.
    ///
    /// State values can be produced on any thread, but all state changes are guaranteed to occur
    /// on the main thread.
    ///
    /// ## One-tick run loop delay
    ///
    /// Because `AsyncStream` is fully asynchronous, all state changes—including the first—occur
    /// after a `Task` has been scheduled. SwiftUI may render one frame of the previous state
    /// before the first value is consumed. For most user-initiated actions on an already-visible
    /// view this is imperceptible, but if you need the first state change to happen synchronously
    /// (e.g. on your view's initial `onAppear`), use `observe(_:)` with a ``StateSequence``
    /// built via ``StateSequenceBuilder`` instead.
    ///
    /// - Parameter stream: An `AsyncStream<State>` that emits state values. `AsyncStream` is
    ///                     non-throwing by design, ensuring reliable state transitions.
    ///
    /// ## Example
    ///
    /// Use `AsyncStream` when you need fine-grained control over when states are emitted,
    /// such as multi-step operations where intermediate states depend on async results:
    ///
    /// ```swift
    /// struct LoadedViewStateModel: Sendable {
    ///     let items: [Item]
    ///     private let repository: ItemRepository
    ///     
    ///     func checkout() -> AsyncStream<ExampleViewState> {
    ///         AsyncStream { continuation in
    ///             Task {
    ///                 continuation.yield(.checkingOut)
    ///                 await self.performCheckout(continuation)
    ///                 continuation.finish()
    ///             }
    ///         }
    ///     }
    ///     
    ///     @concurrent
    ///     private func performCheckout(_ continuation: AsyncStream<ExampleViewState>.Continuation) async {
    ///         do {
    ///             try await repository.checkout()
    ///             continuation.yield(.checkoutComplete)
    ///             
    ///             try? await Task.sleep(for: .seconds(2))
    ///             continuation.yield(.loaded(LoadedViewStateModel(items: [], repository: repository)))
    ///         } catch {
    ///             continuation.yield(.checkoutError(error: error, model: self))
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// Then observe the stream in your view:
    ///
    /// ```swift
    /// struct ExampleView: View {
    ///     @ViewState var state = ExampleViewState.loaded(LoadedViewStateModel())
    ///     
    ///     var body: some View {
    ///         switch state {
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///                 .toolbar {
    ///                     Button("Checkout") {
    ///                         $state.observe(model.checkout())
    ///                     }
    ///                 }
    ///         case .checkingOut:
    ///             ProgressView("Processing...")
    ///         case .checkoutComplete:
    ///             Text("Order complete!")
    ///         case .checkoutError(let error, let model):
    ///             ErrorView(error: error, retry: { $state.observe(model.checkout()) })
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: `AsyncStream` is non-throwing by design, making it ideal for state management.
    ///         Use `AsyncStream` when you need to yield multiple states at specific points
    ///         during an async operation, rather than just at the beginning and end.
    func observe(_ stream: AsyncStream<State>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(AsyncStream) called")
        }
        
        cancelRunningObservations()
        stateChanges = 0
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Track the entire sequence with one interval
            let sequenceID = signposter.makeSignpostID()
            let postName: StaticString = "Sequence"
            let sequenceState = signposter.beginInterval(postName, id: sequenceID, "AsyncStream Sequence")
            defer { signposter.endInterval(postName, sequenceState) }
            
            var iterator = stream.makeAsyncIterator()
            var iterationCount = 1
            
            while !Task.isCancelled {
                let nextState = await iterator.next()
                
                guard let state = nextState else {
                    // Sequence completed naturally
                    if self.loggingEnabled {
                        os_log(.debug, log: self.logger, "AsyncStream completed after %d state changes", iterationCount - 1)
                    }
                    let eventName: StaticString = "AsyncStream Sequence Ended"
                    signposter.emitEvent(eventName, id: sequenceID,
                                         "Ended after \(iterationCount - 1) iterations")
                    break
                }
                
                guard !Task.isCancelled else {
                    if self.loggingEnabled {
                        os_log(.debug, log: self.logger, "AsyncStream cancelled during iteration %d", iterationCount)
                    }
                    let eventName: StaticString = "AsyncStream Sequence Cancelled"
                    signposter.emitEvent(eventName, id: sequenceID,
                                         "Cancelled during iteration \(iterationCount)")
                    break
                }
                self.performStateChange(state)
                
                // Emit an event to mark the state change
                // Note: Avoid accessing self.state in the message to prevent observation side effects
                let eventName: StaticString = "AsyncStream Changed State"
                signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: state))")
                iterationCount += 1
            }
        }
    }
    
    /// Observes and updates the state from a generic `AsyncSequence` that never throws.
    ///
    /// This method accepts any `AsyncSequence` whose element type is `State` and failure type
    /// is `Never`. Each state value is applied to the container as it becomes available from
    /// the sequence. The method returns immediately without waiting for the sequence to complete,
    /// and any ongoing state observation is cancelled before the new one begins.
    ///
    /// State values can be produced on any thread, but all state changes are guaranteed to occur
    /// on the main thread. Any ongoing state observations are cancelled before starting the new
    /// observation.
    ///
    /// The observation continues until the sequence completes or the observation is cancelled.
    /// If cancelled, no further states from the sequence will be applied.
    ///
    /// - Parameter sequence: Any `AsyncSequence` that emits `State` values and has a `Failure`
    ///                       type of `Never`, ensuring it can never throw errors.
    ///
    /// ## Type Constraints
    ///
    /// - `SomeAsyncSequence.Element == State`: The sequence must emit state values
    /// - `SomeAsyncSequence.Failure == Never`: The sequence must be non-throwing
    ///
    /// ## One-tick run loop delay
    ///
    /// Because `AsyncSequence` is fully asynchronous, there is no way to determine whether the
    /// first element can be produced synchronously. All state changes—including the first—occur
    /// after a `Task` has been scheduled, so SwiftUI may render one frame of the previous state
    /// before the first value is consumed. For most user-initiated actions on an already-visible
    /// view this is imperceptible, but if you need the first state change to happen synchronously
    /// (e.g. on your view's initial `onAppear`), use `observe(_:)` with a ``StateSequence``
    /// built via ``StateSequenceBuilder`` instead.
    ///
    /// ## Example
    ///
    /// This method accepts any `AsyncSequence` with a `Failure` type of `Never`. The most common
    /// type that satisfies this constraint is `AsyncStream`. First, define a state model that
    /// implements an action returning an `AsyncStream`:
    ///
    /// ```swift
    /// struct LoadedViewStateModel: Sendable {
    ///     let items: [Item]
    ///     private let repository: ItemRepository
    ///     
    ///     func checkout() -> AsyncStream<ExampleViewState> {
    ///         AsyncStream { continuation in
    ///             Task {
    ///                 continuation.yield(.checkingOut)
    ///                 await self.performCheckout(continuation)
    ///                 continuation.finish()
    ///             }
    ///         }
    ///     }
    ///     
    ///     @concurrent
    ///     private func performCheckout(_ continuation: AsyncStream<ExampleViewState>.Continuation) async {
    ///         do {
    ///             try await repository.checkout()
    ///             continuation.yield(.checkoutComplete)
    ///             
    ///             try? await Task.sleep(for: .seconds(2))
    ///             continuation.yield(.loaded(LoadedViewStateModel(items: [], repository: repository)))
    ///         } catch {
    ///             continuation.yield(.checkoutError(error: error, model: self))
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// Then observe the stream in your view:
    ///
    /// ```swift
    /// struct ExampleView: View {
    ///     @ViewState var state = ExampleViewState.loaded(LoadedViewStateModel())
    ///     
    ///     var body: some View {
    ///         switch state {
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///                 .toolbar {
    ///                     Button("Checkout") {
    ///                         $state.observe(model.checkout())
    ///                     }
    ///                 }
    ///         case .checkingOut:
    ///             ProgressView("Processing...")
    ///         case .checkoutComplete:
    ///             Text("Order complete!")
    ///         case .checkoutError(let error, let model):
    ///             ErrorView(error: error, retry: { $state.observe(model.checkout()) })
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// 
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    func observe<SomeAsyncSequence>(_ sequence: SomeAsyncSequence)
    where SomeAsyncSequence: AsyncSequence,
          SomeAsyncSequence.Element == State,
          SomeAsyncSequence.Failure == Never {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(AsyncSequence) called")
        }
        
        cancelRunningObservations()
        stateChanges = 0
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            // Track the entire sequence with one interval
            let sequenceID = signposter.makeSignpostID()
            let postName: StaticString = "Sequence"
            let sequenceState = signposter.beginInterval(postName, id: sequenceID, "\(String(describing: sequence.self)) Sequence")
            defer { signposter.endInterval(postName, sequenceState) }
            
            var iterationCount = 1
            
            for await state in sequence {
                guard !Task.isCancelled else {
                    if self.loggingEnabled {
                        os_log(.debug, log: self.logger, "AsyncSequence cancelled during iteration %d", iterationCount)
                    }
                    let eventName: StaticString = "Some AsyncSequence Sequence Cancelled"
                    signposter.emitEvent(eventName, id: sequenceID,
                                         "Cancelled during iteration \(iterationCount)")
                    break
                }
                self.performStateChange(state)
                
                // Emit an event to mark the state change
                // Note: Avoid accessing self.state in the message to prevent observation side effects
                let eventName: StaticString = "Some AsyncSequence Changed State"
                signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: state))")
                iterationCount += 1
            }
            
            if !Task.isCancelled {
                // Sequence completed naturally
                if self.loggingEnabled {
                    os_log(.debug, log: self.logger, "AsyncSequence completed after %d state changes", iterationCount - 1)
                }
                let eventName: StaticString = "Some AsyncSequence Sequence Ended"
                signposter.emitEvent(eventName, id: sequenceID,
                                     "Ended after \(iterationCount - 1) iterations")
            }
        }
    }

    // MARK: - Observe Combine Publisher State Change Functions

    /// Observes and updates the state from a Combine `Publisher`.
    ///
    /// This method consumes a Combine `Publisher` that emits state values over time. Each state value
    /// is applied to the container as it becomes available from the publisher. The method returns
    /// immediately without waiting for the publisher to complete.
    ///
    /// State values can be produced on any thread, but all state changes are guaranteed to occur
    /// on the main thread. Any ongoing state observations are cancelled before starting the new
    /// observation.
    ///
    /// The observation continues until the publisher completes or the observation is cancelled.
    /// If cancelled, no further states from the publisher will be applied.
    ///
    /// ## Thread Safety
    ///
    /// Combine publishers are not `Sendable`, which creates potential thread-safety concerns. This
    /// method addresses this by:
    /// - Subscribing immediately with Combine `sink` to preserve publisher ordering semantics
    /// - Bridging emissions into an `AsyncStream` for structured-concurrency consumption
    /// - Performing all state changes on the main actor via `performStateChange`
    ///
    /// **Important**: If you're using a mutable publisher (e.g., `CurrentValueSubject`), ensure that
    /// all mutations happen on the main thread to maintain thread safety.
    ///
    /// - Parameter publisher: A Combine `Publisher` that emits `State` values and has a `Failure`
    ///                        type of `Never`, ensuring it can never throw errors.
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct ExampleView: View {
    ///     @ViewState var state = ExampleViewState.initialized(.init())
    ///     
    ///     var body: some View {
    ///         switch state {
    ///         case .initialized(let viewModel):
    ///             HStack {
    ///                 Color.clear
    ///                     .onAppear {
    ///                         // viewModel.loadPublisher() returns a Publisher<ExampleViewState, Never>
    ///                         $state.observe(viewModel.loadPublisher())
    ///                     }
    ///             }
    ///         case .loading:
    ///             ProgressView()
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///         case .error(let error):
    ///             ErrorView(error: error)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: This method exists for ease of migration from VSM to AsyncVSM and may be removed
    ///         in the future if Apple ever deprecates Combine in favor of Swift Concurrency.
    func observe(_ publisher: some Publisher<State, Never>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(Publisher) called")
        }

        cancelRunningObservations()
        stateChanges = 0

        // Backward-compatible Combine behavior:
        // if the publisher emits synchronously during subscription on the main thread,
        // apply the first state inline to avoid the extra run-loop turn.
        let stream = AsyncStream<State>.makeStream(of: State.self, bufferingPolicy: .unbounded)
        let firstEmissionBuffer = SynchronousFirstEmissionBuffer<State>()
        publisherCancellable = publisher.sink(
            receiveCompletion: firstEmissionBuffer.makeReceiveCompletion(continuation: stream.continuation),
            receiveValue: firstEmissionBuffer.makeReceiveValue(continuation: stream.continuation)
        )

        let sequenceID = signposter.makeSignpostID()
        let postName: StaticString = "Publisher"
        let sequenceState = signposter.beginInterval(postName, id: sequenceID, "Combine Publisher \(String(describing: publisher.self))")

        let synchronousFirst = firstEmissionBuffer.finishSubscribing()
        if let synchronousFirst {
            performStateChange(synchronousFirst)
            let eventName: StaticString = "Publisher emitted new State"
            signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: synchronousFirst))")
        }

        stateTask = Task { @MainActor [weak self, signposter] in
            guard let self else {
                signposter.endInterval(postName, sequenceState)
                return
            }
            defer {
                signposter.endInterval(postName, sequenceState)
                self.publisherCancellable = nil
            }

            var iterationCount = synchronousFirst == nil ? 1 : 2

            for await newState in stream.stream {
                guard !Task.isCancelled else {
                    if self.loggingEnabled {
                        os_log(.debug, log: self.logger, "Publisher cancelled during iteration %d", iterationCount)
                    }
                    let eventName: StaticString = "Publisher Cancelled"
                    signposter.emitEvent(eventName, id: sequenceID, "Cancelled during iteration \(iterationCount)")
                    break
                }

                self.performStateChange(newState)

                let eventName: StaticString = "Publisher emitted new State"
                signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: newState))")
                iterationCount += 1
            }

            if self.loggingEnabled {
                os_log(.debug, log: self.logger, "Publisher subscription finished after %d state changes", iterationCount - 1)
            }
        }
    }
}

private final class SynchronousFirstEmissionBuffer<State: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var isSubscribing = true
    private var firstEmission: State?

    func makeReceiveValue(continuation: AsyncStream<State>.Continuation) -> (State) -> Void {
        { [self] newState in
            receive(newState, continuation: continuation)
        }
    }

    func makeReceiveCompletion(continuation: AsyncStream<State>.Continuation) -> (Subscribers.Completion<Never>) -> Void {
        { _ in
            continuation.finish()
        }
    }

    private func receive(_ newState: State, continuation: AsyncStream<State>.Continuation) {
        lock.lock()
        defer { lock.unlock() }

        if isSubscribing && firstEmission == nil && Thread.isMainThread {
            firstEmission = newState
        } else {
            continuation.yield(newState)
        }
    }

    func finishSubscribing() -> State? {
        lock.lock()
        defer { lock.unlock() }

        isSubscribing = false
        let captured = firstEmission
        firstEmission = nil
        return captured
    }
}

private extension AsyncStateContainer {
    /// Cancels any Swift Concurrency `Task`s or Combine Subscriptions that are being run
    private func cancelRunningObservations() {
        stateTask?.cancel()
        stateTask = nil

        publisherCancellable?.cancel()
        publisherCancellable = nil
    }
    
    private func performStateChange(_ newState: State) {
        if loggingEnabled {
            os_log(.info, log: logger, "State changed to: %{public}@", String(describing: newState))
        }
        
        self.state = newState
        
        #if DEBUG
        // Forward the new state to any active test stream. No-ops when no test is observing.
        // See the debug-only properties and the "Internal Testing Extension" for context.
        guard let streamContinuation else { return }
        streamContinuation.yield(newState)
        stateChanges += 1

        if numberOfWatchedStates == stateChanges {
            streamContinuation.finish()
            self.streamContinuation = nil
        }
        #endif
    }
}

// MARK: - Internal Testing Extension
#if DEBUG
internal extension AsyncStateContainer {
    /// Creates an `AsyncStream` that collects a specified number of state changes for unit testing.
    ///
    /// - Warning: **This method is exclusively for VSM's internal unit tests.**
    ///
    /// This method is marked `internal` intentionally and should **only** be accessed by the unit tests
    /// within the VSM framework itself. It was created to enable testing of `AsyncStateContainer` to verify
    /// that state changes occur in the expected order.
    ///
    /// **This method is unsupported for any code outside of VSM's test suite.** Do not use this method
    /// in your own application code or tests. VSM does not guarantee the stability or continued availability
    /// of this API.
    ///
    /// - Parameters:
    ///   - numberOfChanges: The number of state changes to collect before the stream finishes.
    ///   - timeout: An optional timeout duration. If specified, the stream will automatically
    ///              finish after this duration elapses, even if the expected number of state
    ///              changes has not been reached. This prevents unit tests from hanging indefinitely.
    ///
    /// - Returns: An `AsyncStream<State>` that emits each state change as it occurs.
    ///
    /// ## Stream Lifecycle
    ///
    /// The returned stream will finish when **any** of the following conditions is met:
    /// - The specified number of state changes (`numberOfChanges`) has been observed
    /// - The optional `timeout` duration elapses
    /// - The `AsyncStateContainer` instance is deallocated from memory
    ///
    /// ## Single Stream Limitation
    ///
    /// **Only one `AsyncStream` can be active at a time.** If you call this method while a
    /// previous stream is still active, the previous stream will immediately finish and only
    /// the newly created stream will receive subsequent state changes. This prevents potential
    /// deadlocks where a caller might otherwise wait indefinitely on a stream that will never
    /// receive updates.
    ///
    /// - Important: Call this method **before** triggering the action that causes state changes
    ///   to ensure all transitions are captured.
    func stateChangeStream(last numberOfChanges: Int, timeout: Duration? = nil) -> AsyncStream<State> {
        // Cancel any existing timeout task
        streamTimeoutTask?.cancel()
        streamTimeoutTask = nil
        
        // Finish any existing stream to prevent deadlocks on previous callers
        streamContinuation?.finish()
        
        numberOfWatchedStates = numberOfChanges
        let stateChangeStream = AsyncStream<State>.makeStream(of: State.self, bufferingPolicy: .bufferingNewest(numberOfChanges))
        
        streamContinuation = stateChangeStream.continuation
        
        // Set up timeout if specified.
        // The Task.sleep(for:) suspends without holding the actor, allowing state changes
        // to proceed in parallel. When the sleep completes, cleanup runs on the main actor.
        if let timeout {
            streamTimeoutTask = Task { @MainActor [weak self] in
                try? await Task.sleep(for: timeout)
                guard !Task.isCancelled else { return }
                self?.streamContinuation?.finish()
                self?.streamContinuation = nil
                self?.streamTimeoutTask = nil
            }
        }
        
        return stateChangeStream.stream
    }
}
#endif

#endif
