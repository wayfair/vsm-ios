//
//  AsyncStateContainer.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

#if canImport(Observation)
import Combine
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
public final class AsyncStateContainer<State> {
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
    
    // MARK: - DEBUG test recording (opt-in)
    //
    // In DEBUG builds only, the container can append each `performStateChange` to `debugStateHistory` after
    // `turnOnRecordingStateHistory()` is called. Recording stays off by default so debug apps do not retain
    // every transition unless tests (or diagnostics) explicitly opt in. Release builds omit this code.
    #if DEBUG
    @ObservationIgnored
    private var debugStateHistory: [State] = []
    private var isRecordingStateHistory: Bool = false
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
        // AnyCancellable auto-cancels on deallocation — no explicit cancel needed.
    }
}

// MARK: - Conditional Sendable Conformance

extension AsyncStateContainer: Sendable where State: Sendable {}

// MARK: - Core API (always available, no Sendable constraint)

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
    func observe(_ nextState: sending State) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(State) called")
        }
        
        cancelRunningObservations()
        
        let signpostId = signposter.makeSignpostID()
        let postName: StaticString = "State"
        let state = signposter.beginInterval(postName, id: signpostId)
        
        performStateChange(nextState)
        
        signposter.endInterval(postName, state)
    }
    
    // MARK: - Core Async Observe (private — sending)

    private func _observe(_ nextStateClosure: sending @escaping () async -> State) {
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
            
            guard !Task.isCancelled else {
                if self.loggingEnabled {
                    os_log(.debug, log: self.logger, "observe(async closure) cancelled before state change")
                }
                return
            }
            
            self.performStateChange(nextStateValue)
        }
    }

    // Note: _refresh wraps its work in a stored Task so that subsequent actions
    // (observe/refresh) can cancel an in-flight refresh via cancelRunningObservations().
    // Without this, _refresh runs on the caller's task which the container has no handle to cancel.
    // We considered using withUnsafeCurrentTask to capture the caller's task, but the docs explicitly
    // forbid storing the UnsafeCurrentTask reference outside its closure (undefined behavior).
    // withTaskCancellationHandler bridges cancellation from the caller's task to the stored task,
    // so cancellation works from both directions: container-initiated and caller-initiated.
    private func _refresh(state nextStateClosure: sending @escaping () async -> State) async {
        if loggingEnabled {
            os_log(.debug, log: logger, "refresh(state:) called")
        }
        
        cancelRunningObservations()
        
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            
            let signpostId = signposter.makeSignpostID()
            let postName: StaticString = "Refresh"
            let signpostState = signposter.beginInterval(postName, id: signpostId)
            defer { signposter.endInterval(postName, signpostState) }
            
            let nextStateValue = await nextStateClosure()
            guard !Task.isCancelled else {
                if self.loggingEnabled {
                    os_log(.debug, log: self.logger, "refresh(state:) cancelled before state change")
                }
                return
            }
            self.performStateChange(nextStateValue)
        }
        stateTask = task
        
        await withTaskCancellationHandler {
            await task.value
        } onCancel: { [loggingEnabled, logger] in
            if loggingEnabled {
                os_log(.debug, log: logger, "refresh(state:) caller task cancelled — forwarding cancellation to stored task")
            }
            task.cancel()
        }
    }

    // MARK: - Public Observe (sending — works for all State)

    /// Observes and updates the state using an async `sending` closure.
    ///
    /// This is the core async observation method. It works for **all** `State` types, including
    /// non-Sendable ones. The `sending` keyword uses region-based isolation (SE-0430) to prove
    /// exclusive ownership of the closure and its captures at compile time, rather than requiring
    /// `@Sendable` capture checking.
    ///
    /// The closure inherits the caller's actor isolation via `Task.init` (which takes
    /// `sending @escaping @isolated(any)`). When called from `@MainActor` context, the closure
    /// runs on the main actor unless individual methods within it opt into `@concurrent`.
    ///
    /// - Parameter nextStateClosure: An async closure that produces the next state value.
    ///                                Transferred via `sending` for region-based safety.
    func observe(_ nextStateClosure: sending @escaping () async -> State) {
        _observe(nextStateClosure)
    }

    /// Refreshes the state using an async `sending` closure, suspending until complete.
    ///
    /// Works for all `State` types. Designed for pull-to-refresh when using non-Sendable states
    /// (where the `.refreshable` modifier's `@Sendable` closure requirement cannot be met).
    /// Use a toolbar `Button` calling this method instead.
    ///
    /// - Parameter nextStateClosure: An async closure that produces the next state value.
    func refresh(state nextStateClosure: sending @escaping () async -> State) async {
        await _refresh(state: nextStateClosure)
    }

    /// Observes and updates the state through a ``StateSequence``.
    ///
    /// Each state value produced by the sequence is applied to the container as it becomes
    /// available. Synchronous state actions are applied inline on the current call stack;
    /// async actions run sequentially inside a `Task`.
    ///
    /// The `sending` parameter uses region-based isolation (SE-0430) to prove exclusive
    /// ownership of the sequence and all its captured values at compile time.
    ///
    /// - Parameter stateSequence: A ``StateSequence`` that produces a series of state values.
    func observe(_ stateSequence: sending StateSequence<State>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(StateSequence) called")
        }
        
        cancelRunningObservations()

        let sequenceID = signposter.makeSignpostID()
        let postName: StaticString = "Sequence"
        let sequenceState = signposter.beginInterval(postName, id: sequenceID, "State Sequence")

        for syncAction in stateSequence.synchronousStateActions {
            let syncState = syncAction()
            performStateChange(syncState)
            let eventName: StaticString = "StateSequence Changed State"
            signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: syncState))")
        }

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

        let asyncStates = stateSequence.states
        stateTask = Task { [weak self, signposter] in
            guard let self else {
                signposter.endInterval(postName, sequenceState)
                return
            }
            defer { signposter.endInterval(postName, sequenceState) }

            var iterationCount = stateSequence.synchronousStateActions.count + 1
            var remainingIterator = asyncStates.makeIterator()

            while !Task.isCancelled {
                guard let nextClosure = remainingIterator.next() else {
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
                let nextStateDescription = String(describing: nextState)
                self.performStateChange(nextState)

                let eventName: StaticString = "StateSequence Changed State"
                signposter.emitEvent(eventName, id: sequenceID, "State changed to \(nextStateDescription)")
                iterationCount += 1
            }
        }
    }

    /// Observes and updates the state from a generic `AsyncSequence` that never throws.
    ///
    /// This method uses `iterator.next(isolation: #isolation)` to keep the iterator in the
    /// caller's isolation domain, avoiding Sendable requirements on `State`.
    ///
    /// - Parameter sequence: Any `AsyncSequence` that emits `State` values with `Failure` of `Never`.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    func observe(_ sequence: some AsyncSequence<State, Never>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observe(AsyncSequence) called")
        }
        
        cancelRunningObservations()
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            let sequenceID = signposter.makeSignpostID()
            let postName: StaticString = "Sequence"
            let sequenceState = signposter.beginInterval(postName, id: sequenceID, "\(String(describing: sequence.self)) Sequence")
            defer { signposter.endInterval(postName, sequenceState) }
            
            var iterator = sequence.makeAsyncIterator()
            var iterationCount = 1
            
            while !Task.isCancelled {
                let nextState = await iterator.next(isolation: #isolation)
                
                guard let state = nextState else {
                    if self.loggingEnabled {
                        os_log(.debug, log: self.logger, "AsyncSequence completed after %d state changes", iterationCount - 1)
                    }
                    let eventName: StaticString = "Some AsyncSequence Sequence Ended"
                    signposter.emitEvent(eventName, id: sequenceID,
                                         "Ended after \(iterationCount - 1) iterations")
                    break
                }
                
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
                
                let eventName: StaticString = "Some AsyncSequence Changed State"
                signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: state))")
                iterationCount += 1
            }
        }
    }
    
    // MARK: - Core Legacy Publisher Observation (private — unsafe)

    /// Consumes a publisher by spawning a ``Task`` that runs `for await newState in publisher.values`.
    ///
    /// ## Subscription timing
    /// The `Publisher.values` bridge does not receive until that `Task` runs and the async iterator
    /// attaches to Combine. Emissions that occur **before** then are not replayed. In particular, a
    /// `PassthroughSubject` has **no buffer**: calling `send` on the very next line after
    /// ``observeLegacyAsync(_:)`` / ``observeLegacyAsyncUnsafe(_:)`` returns (same actor, no `await`
    /// in between) can **drop** the value with no error. The same gap applies to the **first**
    /// publisher-driven value after ``observeLegacy(_:firstState:)`` /
    /// ``observeLegacyUnsafe(_:firstState:)`` — `firstState` is applied synchronously, but the
    /// publisher subscription still starts inside the `Task`, so an immediate `send` can still be lost.
    ///
    /// **Mitigations:** give the subscription `Task` time to attach (e.g. `Task.yield()` or any `await`
    /// that runs after `observeLegacy…` returns), schedule sends on the next run loop, use **cold** finite
    /// chains (e.g. `Just(a).append(Just(b))`) so values are produced only after subscription, use a
    /// replaying publisher / `CurrentValueSubject`, or structure flows so the first emission is not
    /// required until after an `await`. Package tests favor cold chains, `CurrentValueSubject`, or
    /// `waitUntilRecordedStateChanges` over fixed `Task.sleep` where possible.
    ///
    /// **Not** used by ``observeLegacyBlocking(_:)`` or ``observeLegacyBlockingUnsafe(_:)`` — those install
    /// `sink` synchronously and forward through an `AsyncStream`, so Combine is subscribed before the call
    /// returns and values are not subject to the same `publisher.values` iterator delay.
    ///
    /// Reproducers live in package tests `StateContainerTests` (Sendable) and `NonSendableStateTests`;
    /// see `observeLegacyAsyncDropsPassthroughIfSendBeforeSubscription`,
    /// `observeLegacyFirstStateDropsPassthroughIfSendBeforeSubscription`, and
    /// `observeLegacyAsyncReceivesColdPublisherChain` (no timing gap with `Just.append`).
    private func _observeLegacyPublisherUnsafe(_ publisher: some Publisher<State, Never>, firstState: State?) {
        cancelRunningObservations()
        
        let sequenceID = signposter.makeSignpostID()
        let postName: StaticString = "Publisher"
        let sequenceState = signposter.beginInterval(postName, id: sequenceID, "Combine Publisher \(String(describing: publisher.self))")
        
        if let firstState {
            performStateChange(firstState)
            let eventName: StaticString = "Publisher emitted new State"
            signposter.emitEvent(eventName, id: sequenceID, "State changed to \(String(describing: firstState))")
        }
        
        stateTask = Task { @MainActor [weak self, signposter] in
            guard let self else {
                signposter.endInterval(postName, sequenceState)
                return
            }
            defer {
                signposter.endInterval(postName, sequenceState)
            }
            
            var iterationCount = firstState == nil ? 1 : 2
            
            // Note: publisher.values (AsyncPublisher) has NO Sendable constraint on Output.
            // For non-Sendable mutable reference types, the bridge passes the same reference
            // across threads without protection. See NonSendableStateTests for a proof-of-concept
            // demonstrating the data race. This is why the "unsafe" methods carry that label.
            for await newState in publisher.values {
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

    // MARK: - Legacy Combine Publisher Observation (unsafe — no Sendable requirement)

    /// **(Legacy / Combine migration — unsafe)** Observes a Combine `Publisher`, applying
    /// `firstState` synchronously and consuming subsequent emissions asynchronously via
    /// `publisher.values`.
    ///
    /// Works with **any** `State` type — including non-`Sendable`. The caller provides the
    /// first state explicitly, which is applied immediately (synchronously) before the `Task`
    /// begins consuming the publisher.
    ///
    /// **Warning:** This method uses Apple's `publisher.values` bridge internally, which does
    /// **not** require `Sendable`. For value types (structs) this is safe because values are
    /// copied. For non-`Sendable` mutable reference types (classes), the bridge only
    /// synchronizes the reference handoff — not the object's internal state. If the publisher
    /// emits a mutable class instance and both sides retain a reference, data races on the
    /// object's properties are possible. This is the same trade-off Apple makes in their
    /// `publisher.values` implementation.
    ///
    /// When `State: Sendable`, prefer ``observeLegacy(_:firstState:)`` which provides the same
    /// behavior with compile-time safety guarantees.
    ///
    /// ## When to use which legacy publisher API
    ///
    /// | Method | `Sendable`? | First state | Trade-off |
    /// |---|---|---|---|
    /// | ``observeLegacy(_:firstState:)`` | **Yes** | Explicit, sync | Safest — no lock, no hop |
    /// | ``observeLegacyAsync(_:)`` | **Yes** | Async (hops) | First frame may flicker |
    /// | ``observeLegacyBlocking(_:)`` | **Yes** | Auto-captured, sync | Briefly blocks thread |
    /// | ``observeLegacyUnsafe(_:firstState:)`` | No | Explicit, sync | `.values` bridge risk for non-Sendable classes |
    /// | ``observeLegacyAsyncUnsafe(_:)`` | No | Async (hops) | `.values` bridge risk for non-Sendable classes |
    /// | ``observeLegacyBlockingUnsafe(_:)`` | No | Auto-captured, sync | Blocks thread + `@unchecked Sendable` risk |
    ///
    /// - Note: Consumption runs in a `Task` via `publisher.values`, so a synchronous `PassthroughSubject.send`
    ///   immediately after this call (no `await` in between) can run before subscription exists and drop the value.
    ///
    /// - Parameters:
    ///   - publisher: A Combine `Publisher` that emits `State` values and never fails.
    ///   - firstState: The initial state to apply synchronously before consuming the publisher.
    func observeLegacyUnsafe(_ publisher: some Publisher<State, Never>, firstState: State) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observeLegacyUnsafe(_:firstState:) called")
        }
        _observeLegacyPublisherUnsafe(publisher, firstState: firstState)
    }

    /// **(Legacy / Combine migration — unsafe)** Observes a Combine `Publisher`, consuming all
    /// emissions asynchronously — including the first one.
    ///
    /// Works with **any** `State` type — including non-`Sendable`. The first emission is
    /// delivered asynchronously (one `Task` hop), so there may be a brief UI flicker if the
    /// publisher emits synchronously on subscription.
    ///
    /// **Warning:** Uses Apple's `publisher.values` bridge which does **not** protect
    /// non-`Sendable` mutable reference types from data races. See
    /// ``observeLegacyUnsafe(_:firstState:)`` for a full explanation.
    ///
    /// When `State: Sendable`, prefer ``observeLegacyAsync(_:)`` for compile-time safety.
    /// Prefer ``observeLegacyUnsafe(_:firstState:)`` when you know the first state upfront,
    /// as it avoids the hop entirely.
    ///
    /// - Note: Consumption runs in a `Task` via `publisher.values`, so a synchronous `PassthroughSubject.send`
    ///   immediately after this call (no `await` in between) can run before subscription exists and drop the value.
    ///
    /// - Parameter publisher: A Combine `Publisher` that emits `State` values and never fails.
    func observeLegacyAsyncUnsafe(_ publisher: some Publisher<State, Never>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observeLegacyAsyncUnsafe(_:) called")
        }
        _observeLegacyPublisherUnsafe(publisher, firstState: nil)
    }

    // MARK: - Legacy Combine Publisher (blocking, unsafe — no Sendable requirement)

    /// **(Legacy / Combine migration — unsafe, blocking)** Observes a Combine `Publisher`,
    /// using a lock to capture the first emission synchronously — avoiding a `Task` hop on the
    /// first frame. Works with **any** `State` type, including non-`Sendable`.
    ///
    /// **Warning:** Uses `@unchecked Sendable` internally to bypass the compiler's Sendable
    /// checks. For non-`Sendable` mutable reference types (classes), data races on the object's
    /// properties are possible if both the publisher and the consumer retain a reference.
    /// This is the same trade-off as calling `publisher.values` directly on a non-Sendable type.
    ///
    /// **Intended for deletion** once all callers have migrated to `Sendable` state types.
    /// When `State: Sendable`, prefer ``observeLegacyBlocking(_:)`` which provides the same
    /// behavior with compiler-proven safety.
    ///
    /// ## When to use which legacy publisher API
    ///
    /// | Method | `Sendable`? | First state | Trade-off |
    /// |---|---|---|---|
    /// | ``observeLegacy(_:firstState:)`` | **Yes** | Explicit, sync | Safest — no lock, no hop |
    /// | ``observeLegacyAsync(_:)`` | **Yes** | Async (hops) | First frame may flicker |
    /// | ``observeLegacyBlocking(_:)`` | **Yes** | Auto-captured, sync | Briefly blocks thread |
    /// | ``observeLegacyUnsafe(_:firstState:)`` | No | Explicit, sync | `.values` bridge risk |
    /// | ``observeLegacyAsyncUnsafe(_:)`` | No | Async (hops) | `.values` bridge risk |
    /// | ``observeLegacyBlockingUnsafe(_:)`` | No | Auto-captured, sync | Blocks thread + `@unchecked Sendable` risk |
    ///
    /// - Note: Unlike ``observeLegacyAsyncUnsafe(_:)``, this path subscribes with `sink` before returning,
    ///   then bridges later values through an `AsyncStream` (buffered). It does **not** use `publisher.values`,
    ///   so a `PassthroughSubject` does not have the same “send before subscription exists” gap as the async
    ///   legacy APIs.
    ///
    /// - Parameter publisher: A Combine `Publisher` that emits `State` values and never fails.
    func observeLegacyBlockingUnsafe(_ publisher: some Publisher<State, Never>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observeLegacyBlockingUnsafe(_:) called")
        }

        cancelRunningObservations()

        typealias Boxed = UnsafeSendableBox<State>
        let boxedStream = AsyncStream<Boxed>.makeStream(of: Boxed.self, bufferingPolicy: .unbounded)
        let firstEmissionBuffer = SynchronousFirstEmissionBuffer<Boxed>()
        let receiveValue = firstEmissionBuffer.makeReceiveValue(continuation: boxedStream.continuation)
        publisherCancellable = publisher.sink(
            receiveCompletion: firstEmissionBuffer.makeReceiveCompletion(continuation: boxedStream.continuation),
            receiveValue: { receiveValue(Boxed(value: $0)) }
        )

        let sequenceID = signposter.makeSignpostID()
        let postName: StaticString = "Publisher"
        let sequenceState = signposter.beginInterval(postName, id: sequenceID, "Combine Publisher \(String(describing: publisher.self))")

        let synchronousFirst = firstEmissionBuffer.finishSubscribing()?.value
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

            for await box in boxedStream.stream {
                let newState = box.value
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

// MARK: - Strict API (requires State: Sendable)

public extension AsyncStateContainer where State: Sendable {

    // MARK: - Observe Single State Change Functions (@Sendable)

    /// `@Sendable` overload — preferred by the compiler when `State: Sendable`.
    ///
    /// Forwards to the `sending`-based implementation. A `@Sendable` closure satisfies
    /// `sending` because `@Sendable` is strictly more constrained.
    func observe(_ nextStateClosure: @escaping @Sendable () async -> State) {
        _observe(nextStateClosure)
    }
    
    /// `@Sendable` overload of `refresh(state:)`.
    func refresh(state nextState: @escaping @Sendable () async -> State) async {
        await _refresh(state: nextState)
    }

    // MARK: - Legacy Combine Publisher (safe — Sendable only)

    /// **(Legacy / Combine migration — safe)** Observes a Combine `Publisher`, applying
    /// `firstState` synchronously and consuming subsequent emissions asynchronously via
    /// `publisher.values`.
    ///
    /// **Requires `State: Sendable`.** This guarantees no shared mutable state can cross
    /// isolation boundaries through the `publisher.values` bridge.
    ///
    /// The caller provides the first state explicitly, which is applied immediately
    /// (synchronously) before the `Task` begins consuming the publisher. No lock, no hop.
    ///
    /// For non-`Sendable` states, use ``observeLegacyUnsafe(_:firstState:)`` (same behavior,
    /// but without compile-time safety for reference types).
    ///
    /// - Note: Consumption runs in a `Task` via `publisher.values`, so a synchronous `PassthroughSubject.send`
    ///   immediately after this call (no `await` in between) can run before subscription exists and drop the value.
    ///
    /// - Parameters:
    ///   - publisher: A Combine `Publisher` that emits `State` values and never fails.
    ///   - firstState: The initial state to apply synchronously before consuming the publisher.
    func observeLegacy(_ publisher: some Publisher<State, Never>, firstState: State) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observeLegacy(_:firstState:) called")
        }
        _observeLegacyPublisherSafe(publisher, firstState: firstState)
    }

    /// **(Legacy / Combine migration — safe)** Observes a Combine `Publisher`, consuming all
    /// emissions asynchronously — including the first one.
    ///
    /// **Requires `State: Sendable`.** The first emission is delivered asynchronously (one
    /// `Task` hop), so there may be a brief UI flicker if the publisher emits synchronously
    /// on subscription.
    ///
    /// Prefer ``observeLegacy(_:firstState:)`` when you know the first state upfront, as it
    /// avoids the hop entirely. For auto-captured synchronous first emission,
    /// ``observeLegacyBlocking(_:)`` uses a lock instead.
    ///
    /// For non-`Sendable` states, use ``observeLegacyAsyncUnsafe(_:)``.
    ///
    /// - Note: Consumption runs in a `Task` via `publisher.values`, so a synchronous `PassthroughSubject.send`
    ///   immediately after this call (no `await` in between) can run before subscription exists and drop the value.
    ///
    /// - Parameter publisher: A Combine `Publisher` that emits `State` values and never fails.
    func observeLegacyAsync(_ publisher: some Publisher<State, Never>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observeLegacyAsync(_:) called")
        }
        _observeLegacyPublisherSafe(publisher, firstState: nil)
    }

    // MARK: - Legacy Combine Publisher (blocking — Sendable only)

    /// **(Legacy / Combine migration)** Observes a Combine `Publisher`, using a lock to capture the
    /// first emission synchronously — avoiding a `Task` hop on the first frame.
    ///
    /// **Requires `State: Sendable`.** This method subscribes via Combine's `sink` and uses a
    /// lock-based buffer (`SynchronousFirstEmissionBuffer`) to intercept the first synchronous
    /// emission. The lock briefly **blocks the calling thread** during subscription. Subsequent
    /// emissions are bridged into an `AsyncStream` for structured-concurrency consumption.
    ///
    /// ## When to use which legacy publisher API
    ///
    /// | Method | `Sendable`? | First state | Trade-off |
    /// |---|---|---|---|
    /// | ``observeLegacy(_:firstState:)`` | **Yes** | Explicit, sync | Safest — no lock, no hop |
    /// | ``observeLegacyAsync(_:)`` | **Yes** | Async (hops) | First frame may flicker |
    /// | ``observeLegacyBlocking(_:)`` | **Yes** | Auto-captured, sync | **Briefly blocks thread** |
    /// | ``observeLegacyUnsafe(_:firstState:)`` | No | Explicit, sync | `.values` bridge risk for non-Sendable classes |
    /// | ``observeLegacyAsyncUnsafe(_:)`` | No | Async (hops) | `.values` bridge risk for non-Sendable classes |
    /// | ``observeLegacyBlockingUnsafe(_:)`` | No | Auto-captured, sync | Blocks thread + `@unchecked Sendable` risk |
    ///
    /// For non-`Sendable` states, use ``observeLegacyUnsafe(_:firstState:)``, ``observeLegacyAsyncUnsafe(_:)``,
    /// or ``observeLegacyBlockingUnsafe(_:)``.
    ///
    /// ## Known Combine Limitations
    ///
    /// Combine has known race conditions with certain operator combinations — notably
    /// `.append` + `.delay` + `.subscribe(on:)` — where the publisher may fire its completion
    /// before appended publishers emit their values. This is a Combine framework issue, not a
    /// VSM issue, and will affect any `sink` subscriber in the same way. See
    /// `CombinePublisherRaceConditionTests` for an isolated reproduction.
    ///
    /// - Note: Unlike ``observeLegacyAsync(_:)``, this path subscribes with `sink` before returning, then
    ///   bridges later values through an `AsyncStream` (buffered). It does **not** use `publisher.values`, so
    ///   a `PassthroughSubject` does not have the same “send before subscription exists” gap as
    ///   ``observeLegacy(_:firstState:)`` / ``observeLegacyAsync(_:)``.
    ///
    /// - Parameter publisher: A Combine `Publisher` that emits `State` values and never fails.
    func observeLegacyBlocking(_ publisher: some Publisher<State, Never>) {
        if loggingEnabled {
            os_log(.debug, log: logger, "observeLegacyBlocking(_:) called")
        }

        cancelRunningObservations()

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

// MARK: - Safe Legacy Publisher Forwarding (State: Sendable)

private extension AsyncStateContainer where State: Sendable {
    func _observeLegacyPublisherSafe(_ publisher: some Publisher<State, Never>, firstState: State?) {
        _observeLegacyPublisherUnsafe(publisher, firstState: firstState)
    }
}

// MARK: - SynchronousFirstEmissionBuffer (iOS 16+, State: Sendable)

/// Buffers the first synchronous emission from a Combine publisher during subscription,
/// allowing it to be applied inline before any `await` suspension point.
///
/// Uses `OSAllocatedUnfairLock` for compiler-verified exclusive access to the protected state.
/// Available on iOS 16+ (unlike `Mutex` which requires iOS 18+).
private final class SynchronousFirstEmissionBuffer<State: Sendable>: Sendable {
    private struct BufferState: Sendable {
        var isSubscribing = true
        var firstEmission: State?
    }

    private let lock = OSAllocatedUnfairLock(initialState: BufferState())

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
        lock.withLock { state in
            if state.isSubscribing && state.firstEmission == nil && Thread.isMainThread {
                state.firstEmission = newState
            } else {
                continuation.yield(newState)
            }
        }
    }

    func finishSubscribing() -> State? {
        lock.withLock { state in
            state.isSubscribing = false
            let captured = state.firstEmission
            state.firstEmission = nil
            return captured
        }
    }
}

// MARK: - UnsafeSendableBox (deletable — used only by observeLegacyBlockingUnsafe)

/// Wraps a non-`Sendable` value so it satisfies `Sendable` constraints, allowing it to be
/// stored in `SynchronousFirstEmissionBuffer` and yielded through `AsyncStream`.
///
/// **Intended for deletion** alongside `observeLegacyBlockingUnsafe` once all callers
/// adopt `Sendable` state types.
private struct UnsafeSendableBox<T>: @unchecked Sendable {
    let value: T
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
        if isRecordingStateHistory {
            debugStateHistory.append(newState)
        }
        #endif
    }
}

// MARK: - Internal Testing Extension
#if DEBUG
internal extension AsyncStateContainer {
    /// Waits until `debugStateHistory.count >= requiredCount` or `timeout` elapses, then returns a **copy**
    /// of the full debug log (whatever was recorded, even if the count threshold was not met).
    ///
    /// `timeout` is required so every test chooses an explicit wait bound (e.g. `.seconds(5)`).
    ///
    /// Implementation is a simple yield loop (not event-driven); that is intentional—low complexity for
    /// tests that finish in milliseconds, not a performance target.
    ///
    /// - Warning: **For VSM's internal unit tests only.** Requires a **DEBUG** build of **VSM** and a prior
    ///   call to `turnOnRecordingStateHistory()` on this container; otherwise the wait returns an empty log.
    func waitUntilRecordedStateChanges(
        atLeast requiredCount: Int,
        timeout: Duration
    ) async -> [State] {
        guard isRecordingStateHistory else { return [] }
        
        let deadline = ContinuousClock.now + timeout
        while debugStateHistory.count < requiredCount {
            if ContinuousClock.now >= deadline { break }
            await Task.yield()
        }
        return debugStateHistory
    }
    
    /// Enables appending to `debugStateHistory` on each state change. Call from tests before driving the container.
    func turnOnRecordingStateHistory() {
        isRecordingStateHistory = true
    }
}
#endif

#endif
