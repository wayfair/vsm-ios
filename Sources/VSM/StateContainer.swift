import Combine
import Foundation

/// Wraps a state to be observed by a ViewStateRendering view or other interested observer.
/// Provides `observe` functions for forwarding new states to this container.
final public class StateContainer<State>: ObservableObject {
    
    @Published public private(set) var state: State
    private var cancellable: AnyCancellable?
    private var asyncTask: Task<Void, Error>?
    
    // Debounce Properties
    private var debounceSubscriptionQueue: DispatchQueue = DispatchQueue(label: #function, qos: .userInitiated)
    private var debounceCancellables: [AnyHashable: AnyCancellable] = [:]
    private var debouncePublisher: PassthroughSubject<DebounceableAction, Never> = .init()
    private var defaultDebounceId: UUID = .init() // Prevents accidental debounce collisions with custom identifiers
    
    public init(state: State) {
        self.state = state
        registerForDebugLogging()
    }
    
    /// Cancels any Combine `Subscriber`s that are being observed or Swift Concurrency `Task`s that are being run
    func cancelRunningObservations() {
        cancellable?.cancel()
        cancellable = nil
        asyncTask?.cancel()
        asyncTask = nil
    }
    
    deinit {
        cancelRunningObservations()
    }
}

// MARK: - Observe Function Overloads

public extension StateContainer {
    /// Observes the state publisher emitted as a result of invoking some action
    func observe(_ stateChangePublisher: AnyPublisher<State, Never>) {
        cancelRunningObservations()
        cancellable = stateChangePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newState in
                self?.state = newState
            }
    }
    
    /// Observes the state emitted as a result of invoking some asynchronous action
    func observe(_ awaitState: @escaping () async -> State) {
        cancelRunningObservations()
        // A weak-self declaration is required on the `Task` closure to break an unexpected strong self retention, despite not directly invoking self ¯\_(ツ)_/¯
        asyncTask = Task(priority: .userInitiated) { [weak self] in
            let newState = await awaitState()
            guard !Task.isCancelled else { return }
            // GCD is used here instead of `MainActor` to avoid back-ported Swift Concurrency crashes relating to `MainActor` usage
            // In a future iOS 15+ version, this class will be converted fully to the `MainActor` paradigm
            DispatchQueue.main.async { [weak self] in
                self?.state = newState
            }
        }
    }
    
    /// Observes the states emitted as a result of invoking some asynchronous action that returns an asynchronous sequence
    func observe<SomeAsyncSequence: AsyncSequence>(_ awaitStateSequence: @escaping () async -> SomeAsyncSequence) where SomeAsyncSequence.Element == State {
        cancelRunningObservations()
        // A weak-self declaration is required on the `Task` closure to break an unexpected strong self retention, despite not directly invoking self ¯\_(ツ)_/¯
        asyncTask = Task(priority: .userInitiated) { [weak self] in
            for try await newState in await awaitStateSequence() {
                guard !Task.isCancelled else { break }
                // GCD is used here instead of `MainActor` to avoid back-ported Swift Concurrency crashes relating to `MainActor` usage
                // In a future iOS 15+ version, this class will be converted fully to the `MainActor` paradigm
                DispatchQueue.main.async { [weak self] in
                    self?.state = newState
                }
            }
        }
    }
    
    /// Observes the state emitted as a result of invoking some synchronous action
    func observe(_ nextState: @autoclosure @escaping () -> State) {
        cancelRunningObservations()
        let newState = nextState()
        if Thread.isMainThread {
            state = newState
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.state = newState
            }
        }
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
            if debounceCancellables[action.identifier] == nil {
                debounceCancellables[action.identifier] = debouncePublisher
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
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangePublisherAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangePublisherAction: @escaping @autoclosure () -> AnyPublisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        let debounceGroupId = DebounceIdentifier(defaultId: defaultDebounceId, file: file, line: line)
        observe(stateChangePublisherAction(), debounced: dueTime, identifier: debounceGroupId)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` publisher emitted as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangePublisherAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangePublisherAction: @escaping @autoclosure () -> AnyPublisher<State, Never>,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        let debounceableAction = DebounceableAction(identifier: identifier, dueTime: dueTime) { [weak self] in
            self?.observe(stateChangePublisherAction().eraseToAnyPublisher())
        }
        debounce(action: debounceableAction)
    }
    
    /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangeAsyncAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangeAsyncAction: @escaping () async -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        let debounceGroupId = DebounceIdentifier(defaultId: defaultDebounceId, file: file, line: line)
        observe(stateChangeAsyncAction, debounced: dueTime, identifier: debounceGroupId)
    }
    
    /// Debounces the action calls by `dueTime`, then asynchronously observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangeAsyncAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangeAsyncAction: @escaping () async -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        let debounceableAction = DebounceableAction(identifier: identifier, dueTime: dueTime) { [weak self] in
            self?.observe({ await stateChangeAsyncAction() })
        }
        debounce(action: debounceableAction)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangeAsyncSequenceAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe<SomeAsyncSequence: AsyncSequence>(
        _ stateChangeAsyncSequenceAction: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) where SomeAsyncSequence.Element == State {
        let debounceGroupId = DebounceIdentifier(defaultId: defaultDebounceId, file: file, line: line)
        observe(stateChangeAsyncSequenceAction, debounced: dueTime, identifier: debounceGroupId)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the async sequence of `State`s returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangeAsyncSequenceAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe<SomeAsyncSequence: AsyncSequence>(
        _ stateChangeAsyncSequenceAction: @escaping () async -> SomeAsyncSequence,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) where SomeAsyncSequence.Element == State {
        let debounceableAction = DebounceableAction(identifier: identifier, dueTime: dueTime) { [weak self] in
            self?.observe({ await stateChangeAsyncSequenceAction() })
        }
        debounce(action: debounceableAction)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are automatically grouped by call location. Use `observe(_:debounced:identifier:)` if you need custom debounce grouping.
    /// - Parameters:
    ///   - stateChangeAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    func observe(
        _ stateChangeAction: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        file: String = #file,
        line: UInt = #line
    ) {
        let debounceGroupId = DebounceIdentifier(defaultId: defaultDebounceId, file: file, line: line)
        observe(stateChangeAction(), debounced: dueTime, identifier: debounceGroupId)
    }
    
    /// Debounces the action calls by `dueTime`, then observes the `State` returned as a result of invoking the action.
    /// Prevents actions from being excessively called when bound to noisy UI events.
    /// Action calls are grouped by the provided `identifier`.
    /// - Parameters:
    ///   - stateChangeAction: The action to be debounced before invoking
    ///   - dueTime: The amount of time required to pass before invoking the most recent action
    ///   - identifier: The identifier for grouping actions for debouncing
    func observe(
        _ stateChangeAction: @escaping @autoclosure () -> State,
        debounced dueTime: DispatchQueue.SchedulerTimeType.Stride,
        identifier: AnyHashable
    ) {
        let debounceableAction = DebounceableAction(identifier: identifier, dueTime: dueTime) { [weak self] in
            self?.observe(stateChangeAction())
        }
        debounce(action: debounceableAction)
    }
}

private struct DebounceIdentifier: Hashable {
    let defaultId: UUID
    let file: String
    let line: UInt
}
