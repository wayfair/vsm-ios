//
//  AsyncStateContainer.swift
//  AsyncVSM
//
//  Created by Bill Dunay on 11/17/24.
//

import Foundation

@Observable
@MainActor
public final class AsyncStateContainer<State: Sendable> {
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
    func observe(_ nextState: State) {
        cancelRunningObservations()
        stateChanges = 0
        performStateChange(nextState)
    }
    
    func observeAsync(_ nextState: State) async {
        cancelRunningObservations()
        stateChanges = 0
        performStateChange(nextState)
    }
    
    func observe(_ nextState: @escaping () async -> State) {
        cancelRunningObservations()
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            
            let nextStateValue = await nextState()
            guard Task.isCancelled == false else { return }
            
            self.performStateChange(nextStateValue)
        }
    }
    
    func observe(_ nextState: @escaping () async throws -> State, onError: @escaping @Sendable (Error) -> State) {
        cancelRunningObservations()
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let nextStateValue = try await nextState()
                guard Task.isCancelled == false else {
                    return
                }
                
                self.performStateChange(nextStateValue)
            } catch {
                guard Task.isCancelled == false else { return }
                self.performStateChange(onError(error))
            }
        }
    }
    
    // MARK: - Failable Async Sequences
    
    func observe<SomeAsyncSequence: AsyncSequence>(initial: @autoclosure () throws -> State? = nil, sequence: SomeAsyncSequence, onError: (@Sendable (Error) -> State)? = nil) where SomeAsyncSequence.Element == State {
        cancelRunningObservations()
        stateChanges = 0
        
        if let initialState = try? initial() {
            performStateChange(initialState)
        }
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                for try await nextState in sequence {
                    guard Task.isCancelled == false else { break }
                    self.performStateChange(nextState)
                }
            } catch {
                guard Task.isCancelled == false else { return }
                guard let onError else {
                    preconditionFailure(error.localizedDescription)
                }
                
                self.performStateChange(onError(error))
            }
        }
    }
    
    func observe<SomeAsyncSequence: AsyncSequence>(initial: @escaping @Sendable () async throws -> State, sequence: SomeAsyncSequence, onError: (@Sendable (Error) -> State)? = nil) where SomeAsyncSequence.Element == State {
        cancelRunningObservations()
        stateChanges = 0
        
        stateTask = Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                guard Task.isCancelled == false else { return }
                self.performStateChange(try await initial())
                
                for try await nextState in sequence {
                    guard Task.isCancelled == false else { break }
                    self.performStateChange(nextState)
                }
            } catch {
                guard Task.isCancelled == false else { return }
                guard let onError else {
                    preconditionFailure(error.localizedDescription)
                }
                
                self.performStateChange(onError(error))
            }
        }
    }
    
    // MARK: - Non-Failable Async Sequences
    
    @available(iOS 18.0, macOS 11.0, tvOS 18.0, watchOS 11.0, *)
    func observe<SomeAsyncSequence: AsyncSequence>(initial: @autoclosure () -> State? = nil, sequence: SomeAsyncSequence) where SomeAsyncSequence.Element == State, SomeAsyncSequence.Failure == Never {
        cancelRunningObservations()
        stateChanges = 0
        
        if let initialState = initial() {
            performStateChange(initialState)
        }
        
        stateTask = Task { @MainActor [weak self] in
            for await nextState in sequence {
                guard let self, !Task.isCancelled else { break }
                
                self.performStateChange(nextState)
            }
        }
    }
    
    @available(iOS 18.0, macOS 11.0, tvOS 18.0, watchOS 11.0, *)
    func observe<SomeAsyncSequence: AsyncSequence>(initial: @escaping @Sendable () async -> State, sequence: SomeAsyncSequence) where SomeAsyncSequence.Element == State, SomeAsyncSequence.Failure == Never {
        cancelRunningObservations()
        stateChanges = 0
        
        stateTask = Task { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            self.performStateChange(await initial())
            
            for await nextState in sequence {
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
