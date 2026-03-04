//
//  Test.swift
//  AsyncVSMTests
//
//  Created by Bill Dunay on 10/9/25.
//

import Combine
import Foundation
import Observation
import OSLog
import Testing

@testable import VSM

@Suite
struct StateContainerTests {
    enum StateContainerTestError: Error {
        case missingStartState
    }

    /// Creates a fresh AsyncStateContainer for testing, avoiding @ViewState/@SwiftUI.State
    /// which requires a SwiftUI view graph to work correctly.
    @MainActor
    private func makeContainer(initialState: MockState = .initialize()) -> AsyncStateContainer<MockState> {
        AsyncStateContainer(state: initialState, logger: .disabled)
    }
    
    // MARK: - Single State Change Tests
    
    @Test("Single Synchronous State Change")
    @MainActor
    func singleSynchronousStateChange() async throws {
        let expectedResult: [MockState] = [
            .loaded(.init(count: 1)),
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 1, timeout: .seconds(1))
        
        container.observe(initStateModel.load())
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("Single Asynchronous State Change (Main Thread)")
    @MainActor
    func singleAsynchronousStateChange() async throws {
        let expectedResult: [MockState] = [
            .loaded(.init(count: 10)),
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 1, timeout: .seconds(1))
        
        container.observe { await initStateModel.loadAsync() }
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("Single Asynchronous State Change (Background Thread)")
    @MainActor
    func singleAsynchronousStateChangeOnBackgroundThread() async throws {
        let expectedResult: [MockState] = [
            .loaded(.init(count: 10)),
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 1, timeout: .seconds(1))
        
        container.observe { await initStateModel.loadAsyncOnBackgroundThread(count: 10) }
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    // MARK: - Multi-State Change Tests via StateSequence
    
    @Test("State Change via StateSequence expecting 2 states (Main Thread)")
    @MainActor
    func stateChangeViaStateSequence() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 2))
        ]
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 2, timeout: .seconds(1))
        
        container.observe(initStateModel.loadSequence())
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("State Change via StateSequence expecting 2 states (executes on Main Thread)")
    @MainActor
    func stateChangeViaStateSequenceOnAsyncMainThread() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 2))
        ]
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 2, timeout: .seconds(1))
        
        container.observe(initStateModel.loadSequenceAsync(onMainThread: true))
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("State Change via StateSequence expecting 2 states (executes on Background Thread)")
    @MainActor
    func stateChangeViaStateSequenceOnBackgroundThread() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 2))
        ]
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 2, timeout: .seconds(1))
        
        container.observe(initStateModel.loadSequenceAsync(onMainThread: false))
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    // MARK: - Multi-State Change Tests via AsyncStream
    
    @Test("State Change via AsyncStream expecting 3 states (Run on Main Thread)")
    @MainActor
    func stateChangeViaStateStream() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2))
        ]
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 3, timeout: .seconds(1))
        
        container.observe(initStateModel.loadStreamCurrentExecutionContext())
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("State Change via AsyncStream expecting 3 states (Run on Background Thread)")
    @MainActor
    func stateChangeViaStateStreamBackgroundThread() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2))
        ]
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 3, timeout: .seconds(1))
        
        container.observe(initStateModel.loadStreamBackgroundExecutionContext())
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("Await State change on Main Thread for PTR functionality")
    @MainActor
    func awaitingMainThreadStateChange() async throws {
        let expectedResult: MockState = .loaded(.init(count: 1))
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 1, timeout: .seconds(1))
        await container.refresh(state: { await initStateModel.loadAsyncOnCurrentExecutionContext(count: 1) })
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == [expectedResult])
    }
    
    @Test("Await State change on Background Thread for PTR functionality")
    @MainActor
    func awaitingBackgroundThreadStateChange() async throws {
        let expectedResult: MockState = .loaded(.init(count: 1))
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 1, timeout: .seconds(1))
        await container.refresh(state: { await initStateModel.loadAsyncOnBackgroundThread(count: 1) })
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == [expectedResult])
    }
    
    @Test("Observing State Publisher should result in state changes")
    @MainActor
    func testObservingStatePublisher() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 11))
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 2, timeout: .seconds(1))
        
        container.observe(initStateModel.loadFromPublisher())
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
        #expect(stateChanges.count == 2)
    }
    
    @Test("Observing State Publisher that works on a background thread should result in state changes")
    @MainActor
    func testObservingStatePublisherOnBackgroundThread() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 11))
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 2, timeout: .seconds(1))
        
        container.observe(initStateModel.loadFromPublisherBackgroundThread())
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }

    @Test("Observing Publisher applies synchronous first emission immediately")
    @MainActor
    func testObservingPublisherAppliesSynchronousFirstEmissionImmediately() async throws {
        let container = makeContainer()
        let subject = CurrentValueSubject<MockState, Never>(.loading)

        container.observe(subject.eraseToAnyPublisher())

        #expect(container.state == .loading)

        let stateChangsStream = container.stateChangeStream(last: 1, timeout: .seconds(1))
        subject.send(.loaded(.init(count: 42)))

        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }

        #expect(stateChanges == [.loaded(.init(count: 42))])
    }
    
    // MARK: Sanity Check Tests to ensure Mock types work as expected
    
    @Test("Sanity Check MockState sequence fires in the right order")
    @MainActor
    func testMockStateSequenceEmissions() async throws {
        let subject = MockState.InitializeStateModel()
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 2)),
        ]
        var stateChanges: [MockState] = []
        
        let stateSequence = subject.loadSequence()
        for try await newState in stateSequence {
            stateChanges.append(newState)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("Sanity Check MockState sequence fires all state when using first synchronous, then rest (Main Thread)")
    @MainActor
    func testMockStateSequenceEmissionsFirstSyncRestAsync() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 2)),
            .loaded(.init(count: 11))
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = container.stateChangeStream(last: 3, timeout: .seconds(1))
        
        container.observe(initStateModel.loadSynchronousFirstStateThenRest())
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("Sanity Check MockState stream fires in the right order (Main Thread)")
    @MainActor
    func testMockStateStreamEmissions() async throws {
        let subject = MockState.InitializeStateModel()
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2)),
        ]
        var stateChanges: [MockState] = []
        
        let stateStream = subject.loadStreamCurrentExecutionContext()
        for await newState in stateStream {
            stateChanges.append(newState)
        }
        
        #expect(stateChanges == expectedResult)
    }
    
    @Test("Sanity Check MockState stream fires in the right order (Background Thread")
    @MainActor
    func testMockStateStreamEmissionsOnBackgroundThread() async throws {
        let subject = MockState.InitializeStateModel()
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2)),
        ]
        var stateChanges: [MockState] = []
        
        let stateStream = subject.loadStreamCurrentExecutionContext()
        for await newState in stateStream {
            stateChanges.append(newState)
        }
        
        #expect(stateChanges == expectedResult)
    }
}

// MARK: Mock Types for Testing State transitions

enum MockState: Sendable, Equatable {
    case initialize(InitializeStateModel = .init())
    case loading
    case loaded(LoadedStateModel)
}

extension MockState {
    struct InitializeStateModel: Sendable, Equatable {
        func load() -> MockState {
            return .loaded(.init(count: 1))
        }
        
        func loadAsync() async -> MockState {
            return .loaded(.init(count: 10))
        }
        
        func loadSequence() -> StateSequence<MockState> {
            return .init(
                { .loading },
                { .loaded(.init(count: 2)) }
            )
        }
        
        func loadSynchronousFirstStateThenRest() -> StateSequence<MockState> {
            return .init(
                first: .loading,
                rest:
                    { .loaded(.init(count: 2)) },
                    { .loaded(.init(count: 11)) }
            )
        }
        
        func loadSequenceAsync(onMainThread: Bool) -> StateSequence<MockState> {
            return .init(
                { .loading },
                {
                    if onMainThread {
                        await loadAsyncOnCurrentExecutionContext(count: 2)
                    } else {
                        await loadAsyncOnBackgroundThread(count: 2)
                    }
                }
            )
        }
        
        func loadStreamCurrentExecutionContext() -> AsyncStream<MockState> {
            return AsyncStream<MockState> { continuation in
                Task {
                    continuation.yield(.loading)
                    
                    for count in 1 ... 2 {
                        continuation.yield(.loaded(.init(count: count)))
                    }
                    
                    continuation.finish()
                }
            }
        }
        
        func loadStreamBackgroundExecutionContext() -> AsyncStream<MockState> {
            return AsyncStream<MockState> { continuation in
                Task.detached {
                    continuation.yield(.loading)
                    
                    for count in 1 ... 2 {
                        continuation.yield(.loaded(.init(count: count)))
                    }
                    
                    continuation.finish()
                }
            }
        }
        
        func loadAsyncOnCurrentExecutionContext(count: Int) async -> MockState {
            return .loaded(.init(count: count))
        }
        
        @concurrent
        func loadAsyncOnBackgroundThread(count: Int) async -> MockState {
            return .loaded(.init(count: count))
        }
        
        func loadFromPublisher() -> AnyPublisher<MockState, Never> {
            return Publishers.Sequence(sequence: [.loading])
                .append(Just(.loaded(.init(count: 11))).delay(for: .milliseconds(100), scheduler: DispatchQueue.main))
                .subscribe(on: DispatchQueue.main)
                .eraseToAnyPublisher()
        }

        func loadFromPublisherBackgroundThread() -> AnyPublisher<MockState, Never> {
            return Publishers.Sequence(sequence: [.loading])
                .append(Just(.loaded(.init(count: 11))).delay(for: .milliseconds(100), scheduler: DispatchQueue.global()))
                .subscribe(on: DispatchQueue.global())
                .eraseToAnyPublisher()
        }
        
        // MARK: - Debounce Test Helpers
        
        /// Creates a StateSequence that emits states rapidly (for debounce testing)
        func loadRapidSequence() -> StateSequence<MockState> {
            return .init(
                { .loaded(.init(count: 1)) },
                { .loaded(.init(count: 2)) },
                { .loaded(.init(count: 3)) },
                { .loaded(.init(count: 4)) },
                { .loaded(.init(count: 5)) }
            )
        }
        
        /// Creates an AsyncStream that emits states rapidly (for debounce testing)
        func loadRapidStream() -> AsyncStream<MockState> {
            return AsyncStream<MockState> { continuation in
                Task {
                    // Emit states rapidly without delays
                    continuation.yield(.loaded(.init(count: 1)))
                    continuation.yield(.loaded(.init(count: 2)))
                    continuation.yield(.loaded(.init(count: 3)))
                    continuation.finish()
                }
            }
        }
        
        /// Creates a Publisher that emits states rapidly (for debounce testing)
        func loadRapidPublisher() -> AnyPublisher<MockState, Never> {
            return Publishers.Sequence(sequence: [
                .loaded(.init(count: 1)),
                .loaded(.init(count: 2)),
                .loaded(.init(count: 3))
            ])
            .eraseToAnyPublisher()
        }
        
        /// Creates a StateSequence that emits states with delays longer than debounce period
        func loadDelayedSequence() -> StateSequence<MockState> {
            return .init(
                { .loaded(.init(count: 1)) },
                {
                    // Add delay between emissions
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                    return .loaded(.init(count: 2))
                }
            )
        }
        
        /// Creates an AsyncStream that emits states with delays longer than debounce period
        func loadDelayedStream() -> AsyncStream<MockState> {
            return AsyncStream<MockState> { continuation in
                Task {
                    continuation.yield(.loaded(.init(count: 1)))
                    try? await Task.sleep(nanoseconds: 200_000_000) // 200ms delay
                    continuation.yield(.loaded(.init(count: 2)))
                    continuation.finish()
                }
            }
        }
    }
    
    struct LoadedStateModel: Sendable, Equatable {
        let count: Int
    }
}
