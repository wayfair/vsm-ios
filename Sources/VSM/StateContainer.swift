import Combine
import Foundation

/// Assists views by managing the current view state.
/// Observes the output of actions called by the view.
final public class StateContainer<State>: ObservableObject, StateContaining {
    
    /// The current state, managed by this container.
    ///
    /// This value is always updated on the main thread.
    @Published public private(set) var state: State {
        didSet {
            stateDidChangeSubject.value = state
        }
    }
    
    /// Publishes the State on `didSet` (main thread). For a `willSet` publisher, use the `$state` projected value.
    public lazy var publisher: AnyPublisher<State, Never> = {
        stateDidChangeSubject.eraseToAnyPublisher()
    }()
    
    /// Used for debug logging. Inert in non-DEBUG schemas.
    lazy var debugLogger: StateContainerDebugLogger = StateContainerDebugLogger()
    
    private var stateSubscription: AnyCancellable?
    private var stateTask: Task<Void, Error>?
    private var stateDidChangeSubject: CurrentValueSubject<State, Never>
    
    // Debounce Properties
    private var debounceSubscriptionQueue: DispatchQueue = DispatchQueue(label: #function, qos: .userInitiated)
    private var debounceSubscriptions: [AnyHashable: AnyCancellable] = [:]
    private var debouncePublisher: PassthroughSubject<DebounceableAction, Never> = .init()
    private var defaultDebounceId: UUID = .init() // Prevents accidental debounce collisions with custom identifiers
    
    public init(state: State) {
        self.state = state
        self.stateDidChangeSubject = .init(state)
        registerForDebugLogging()
    }
    
    /// This function exists to ensure that state is set synchronously if on main, or asynchronously if not on main.
    /// This prevents accidental frame-draws early in the view lifecycle in both SwiftUI and UIKit.
    /// Detail: `.receive(on: DispatchQueue.main)` queues asynchronously, always causing a thread-hop even if the subscription and send were performed on the main thread. TBD whether a runtime optimized Tasks (MainActor) would have the same problem
    /// In a future iOS 15+ version, this class will be converted fully to the `MainActor` paradigm
    private func setStateOnMainThread(to newState: State) {
        if Thread.isMainThread {
            state = newState
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.state = newState
            }
        }
    }
    
    /// Cancels any Combine `Subscriber`s that are being observed or Swift Concurrency `Task`s that are being run
    func cancelRunningObservations() {
        stateSubscription?.cancel()
        stateSubscription = nil
        stateTask?.cancel()
        stateTask = nil
    }
    
    deinit {
        cancelRunningObservations()
    }
}

// MARK: - Observe Function Overloads

public extension StateContainer {
    /// Observes the state publisher emitted as a result of invoking some action
    func observe(_ statePublisher: AnyPublisher<State, Never>) {
        cancelRunningObservations()
        stateSubscription = statePublisher
            .sink { [weak self] newState in
                self?.setStateOnMainThread(to: newState)
            }
    }
    
    /// Observes the state emitted as a result of invoking some asynchronous action
    func observeAsync(_ nextState: @escaping () async -> State) {
        cancelRunningObservations()
        // A weak-self declaration is required on the `Task` closure to break an unexpected strong self retention, despite not directly invoking self ¯\_(ツ)_/¯
        stateTask = Task { [weak self] in
            let newState = await nextState()
            guard !Task.isCancelled else { return }
            // GCD is used here instead of `MainActor` to avoid back-ported Swift Concurrency crashes relating to `MainActor` usage
            // In a future iOS 15+ version, this class will be converted fully to the `MainActor` paradigm
            self?.setStateOnMainThread(to: newState)
        }
    }
    
    /// Observes the states emitted as a result of invoking some asynchronous action that returns an asynchronous sequence
    func observeAsync<SomeAsyncSequence: AsyncSequence>(_ stateSequence: @escaping () async -> SomeAsyncSequence) where SomeAsyncSequence.Element == State {
        cancelRunningObservations()
        // A weak-self declaration is required on the `Task` closure to break an unexpected strong self retention, despite not directly invoking self ¯\_(ツ)_/¯
        stateTask = Task { [weak self] in
            for try await newState in await stateSequence() {
                guard !Task.isCancelled else { break }
                // GCD is used here instead of `MainActor` to avoid back-ported Swift Concurrency crashes relating to `MainActor` usage
                // In a future iOS 15+ version, this class will be converted fully to the `MainActor` paradigm
                self?.setStateOnMainThread(to: newState)
            }
        }
    }
    
    /// Observes the state emitted as a result of invoking some synchronous action
    func observe(_ nextState: State) {
        cancelRunningObservations()
        setStateOnMainThread(to: nextState)
    }
}

// MARK: - Observe Debounce Function Overloads

public extension StateContainer {
    
    private struct DebounceableAction {
        var identifier: AnyHashable
        var dueTime: DispatchQueue.SchedulerTimeType.Stride
        var action: () -> Void
    }
    
    private func debounce(action: DebounceableAction) {
        debounceSubscriptionQueue.sync {
            if debounceSubscriptions[action.identifier] == nil {
                debounceSubscriptions[action.identifier] = debouncePublisher
                    .filter({ $0.identifier == action.identifier })
                    .debounce(for: action.dueTime, scheduler: DispatchQueue.main)
                    .sink {
                        $0.action()
                    }
            }
        }
        debouncePublisher.send(action)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - statePublisher: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ statePublisher: @escaping @autoclosure () -> AnyPublisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        let debounceableAction = DebounceableAction(identifier: identifier, dueTime: dueTime) { [weak self] in
            self?.observe(statePublisher().eraseToAnyPublisher())
        }
        debounce(action: debounceableAction)
    }
    
    /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observeAsync(
        _ nextState: @escaping () async -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        let debounceableAction = DebounceableAction(identifier: identifier, dueTime: dueTime) { [weak self] in
            self?.observeAsync({ await nextState() })
        }
        debounce(action: debounceableAction)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateSequence: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observeAsync<SomeAsyncSequence: AsyncSequence>(
        _ stateSequence: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) where SomeAsyncSequence.Element == State {
        let debounceableAction = DebounceableAction(identifier: identifier, dueTime: dueTime) { [weak self] in
            self?.observeAsync({ await stateSequence() })
        }
        debounce(action: debounceableAction)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - nextState: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ nextState: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        let debounceableAction = DebounceableAction(identifier: identifier, dueTime: dueTime) { [weak self] in
            self?.observe(nextState())
        }
        debounce(action: debounceableAction)
    }
}
