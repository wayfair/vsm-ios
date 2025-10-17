//
//  AsyncStateContainer.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

#if canImport(Observation)
import Foundation
import Observation

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
/// ## Error Handling
///
/// `AsyncStateContainer` follows a never-throwing design philosophy:
/// - Does not accept closures that produce state and also throw
/// - Does not accept `AsyncSequence` types that can error
/// - Only works with sequences whose `Failure` type is `Never`
/// - Supports non-throwing `AsyncStream<State>` and `StateSequence<State>`
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
///                         $state.observe(sequence: viewModel.load())
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
/// - Note: All state changes are automatically published to SwiftUI views through the `@Observable` macro.
@Observable
@MainActor
public final class AsyncStateContainer<State: Sendable> {
    /// The current state of the container.
    ///
    /// This property is observable and will trigger view updates when changed.
    /// All changes to this property are guaranteed to occur on the main thread.
    public private(set) var state: State
    
    @ObservationIgnored
    private var stateTask: Task<Void, Never>?
    
    @ObservationIgnored
    private var streamContinuation: AsyncStream<State>.Continuation?
    
    @ObservationIgnored
    private var numberOfWatchedStates: Int = 0
    
    @ObservationIgnored
    private var stateChanges: Int = 0
    
    init(state: State) {
        self.state = state
    }
    
    internal func stateChangeStream(last numberOfChanges: Int) -> AsyncStream<State> {
        numberOfWatchedStates = numberOfChanges
        let stateChangeStream = AsyncStream<State>.makeStream(of: State.self, bufferingPolicy: .bufferingNewest(numberOfChanges))
        
        streamContinuation = stateChangeStream.continuation
        return stateChangeStream.stream
    }
}

public extension AsyncStateContainer {
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
    ///                         $state.observe(sequence: viewModel.load())
    ///                     }
    ///             }
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///                 .toolbar {
    ///                     Button("Retry") {
    ///                         $state.observe(.loading)
    ///                     }
    ///                 }
    ///         case .error(let error):
    ///             ErrorView(error: error)
    ///         }
    ///     }
    /// }
    /// ```
    func observe(_ nextState: State) {
        cancelRunningObservations()
        stateChanges = 0
        performStateChange(nextState)
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
    /// - Parameter nextState: An async closure that produces the next state value.
    ///                        This closure must not throw errors.
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
    ///                         $state.observe(sequence: viewModel.load())
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
    /// - Note: The closure is captured with `@escaping` and executed within a `Task` on the main actor.
    func observe(_ nextState: @escaping () async -> State) {
        cancelRunningObservations()
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            let nextStateValue = await nextState()
            guard Task.isCancelled == false else { return }
            
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
    ///                        This closure must not throw errors.
    ///
    /// ## Pull-to-Refresh Support
    ///
    /// This method is specifically designed to enable pull-to-refresh (PTR) functionality in
    /// VSM-managed SwiftUI views. SwiftUI's `refreshable` view modifier requires an async
    /// closure that suspends until the refresh operation completes. By using `observe(waitingFor:)`,
    /// the refresh indicator will remain visible until the state has been updated.
    ///
    /// The `refreshable` modifier can be applied to scrollable views like `List` and `ScrollView`,
    /// providing users with a standard pull-to-refresh gesture to manually update content.
    ///
    /// ## Example
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
    func refresh(state nextState: @escaping () async -> State) async {
        cancelRunningObservations()
        let nextStateValue = await nextState()
        
        guard Task.isCancelled == false else { return }
        performStateChange(nextStateValue)
    }
    
    /// Observes and updates the state through a sequence of state values.
    ///
    /// This method consumes a ``StateSequence`` that produces multiple state values over time.
    /// Each state value is applied to the container as it becomes available from the sequence.
    /// The method returns immediately without waiting for the sequence to complete.
    ///
    /// State values are produced according to the sequence's timing, which can run on any thread,
    /// but all state changes are guaranteed to occur on the main thread. Any ongoing state
    /// observations are cancelled before starting the new observation.
    ///
    /// The observation continues until the sequence completes or the observation is cancelled.
    /// If cancelled, no further states from the sequence will be applied.
    ///
    /// - Parameter sequence: A ``StateSequence`` that produces a series of state values.
    ///                       This sequence is guaranteed to never throw errors.
    ///
    /// ## Example
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
    ///                         // viewModel.load() returns StateSequence that emits .loading, then .loaded
    ///                         $state.observe(sequence: viewModel.load())
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
    /// - Note: ``StateSequence`` is designed to never throw, ensuring reliable state transitions.
    func observe(sequence: StateSequence<State>) {
        cancelRunningObservations()
        stateChanges = 0
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await nextState in sequence {
                guard Task.isCancelled == false else { break }
                self.performStateChange(nextState)
            }
        }
    }
    
    /// Observes and updates the state from an `AsyncStream`.
    ///
    /// This method consumes an `AsyncStream` that emits state values over time. Each state value
    /// is applied to the container as it becomes available from the stream. The method returns
    /// immediately without waiting for the stream to complete.
    ///
    /// State values can be produced on any thread, but all state changes are guaranteed to occur
    /// on the main thread. Any ongoing state observations are cancelled before starting the new
    /// observation.
    ///
    /// The observation continues until the stream finishes or the observation is cancelled.
    /// If cancelled, no further states from the stream will be applied.
    ///
    /// - Parameter sequence: An `AsyncStream<State>` that emits state values. Since `AsyncStream`
    ///                       cannot throw errors by design, this ensures reliable state transitions.
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
    ///                         // This is just an example. Typically you would define a method on your view state model that returns an AsyncStream.
    ///                         let (stream, continuation) = AsyncStream<ExampleViewState>.makeStream()
    ///                         
    ///                         $state.observe(sequence: stream)
    ///                         
    ///                         // Emit states from elsewhere (e.g., background task)
    ///                         Task {
    ///                             let data = await fetchData()
    ///                             continuation.yield(.loaded(LoadedViewStateModel(data: data)))
    ///                             continuation.finish()
    ///                         }
    ///                     }
    ///             }
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///         case .error(let viewModel):
    ///             ErrorView(viewModel: viewModel)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: `AsyncStream` is non-throwing by design, making it ideal for state management.
    func observe(sequence: AsyncStream<State>) {
        cancelRunningObservations()
        stateChanges = 0
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await nextState in sequence {
                guard Task.isCancelled == false else { break }
                self.performStateChange(nextState)
            }
        }
    }
    
    /// Observes and updates the state from a generic `AsyncSequence` that never throws.
    ///
    /// This method consumes any `AsyncSequence` whose element type is `State` and failure type
    /// is `Never`. Each state value is applied to the container as it becomes available from
    /// the sequence. The method returns immediately without waiting for the sequence to complete.
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
    ///                         // This is just an example. Typically you would define a method on your view state model that returns an AsyncStream.
    ///                         let (stream, continuation) = AsyncStream<ExampleViewState>.makeStream()
    ///                         
    ///                         $state.observe(sequence: stream)
    ///                         
    ///                         // Emit states from elsewhere (e.g., background task)
    ///                         Task {
    ///                             let data = await fetchData()
    ///                             continuation.yield(.loaded(LoadedViewStateModel(data: data)))
    ///                             continuation.finish()
    ///                         }
    ///                     }
    ///             }
    ///         case .loaded(let model):
    ///             ContentView(model: model)
    ///         case .error(let viewModel):
    ///             ErrorView(viewModel: viewModel)
    ///         }
    ///     }
    /// }
    /// ```
    ///
    /// - Note: The `Never` failure type is enforced at compile time, ensuring type safety.
    ///         Any errors thrown despite this constraint will cause a precondition failure.
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, *)
    func observe<SomeAsyncSequence: AsyncSequence>(sequence: SomeAsyncSequence)
    where SomeAsyncSequence.Element == State, SomeAsyncSequence.Failure == Never {
        cancelRunningObservations()
        stateChanges = 0
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for await nextState in sequence {
                guard Task.isCancelled == false else { break }
                self.performStateChange(nextState)
            }
        }
    }
}

private extension AsyncStateContainer {
    /// Cancels any Swift Concurrency `Task`s that are being run
    private func cancelRunningObservations() {
        stateTask?.cancel()
        stateTask = nil
    }
    
    private func performStateChange(_ newState: State) {
        self.state = newState
        
        // This code tracks state changes for testing purposes only. It should only be invoked
        // if the user called the stateChangeStream function and that should be accessible via
        // unit tests.
        guard let streamContinuation else { return }
        streamContinuation.yield(newState)
        stateChanges += 1

        if numberOfWatchedStates == stateChanges {
            streamContinuation.finish()
            self.streamContinuation = nil
        }
    }
}

#endif
