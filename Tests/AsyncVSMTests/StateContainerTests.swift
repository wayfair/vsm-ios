//
//  Test.swift
//  AsyncVSMTests
//
//  Created by Bill Dunay on 10/9/25.
//

import Testing
import Observation

@testable import AsyncVSM

struct StateContainerTests {
    enum StateContainerTestError: Error {
        case missingStartState
    }
    
    // MARK: - Single State Change Tests
    
    @Test("Single Synchronous State Change")
    @MainActor
    func singleSynchronousStateChange() async throws {
        let expectedResult: [MockState] = [
            .loaded(.init(count: 1)),
        ]
        @ViewState var state: MockState = .initialize()
        
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 1)
        
        $state.observe(initStateModel.load())
        
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
        @ViewState var state: MockState = .initialize()
        
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 1)
        
        $state.observe { await initStateModel.loadAsync() }
        
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
        @ViewState var state: MockState = .initialize()
        
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 1)
        
        $state.observe { await initStateModel.loadAsyncOnBackgroundThread(count: 10) }
        
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
        
        @ViewState var state: MockState = .initialize()
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 2)
        
        $state.observe(sequence: initStateModel.loadSequence())
        
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
        
        @ViewState var state: MockState = .initialize()
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 2)
        
        $state.observe(sequence: initStateModel.loadSequenceAsync(onMainThread: true))
        
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
        
        @ViewState var state: MockState = .initialize()
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 2)
        
        $state.observe(sequence: initStateModel.loadSequenceAsync(onMainThread: false))
        
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
        
        @ViewState var state: MockState = .initialize()
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 3)
        
        $state.observe(sequence: initStateModel.loadStreamCurrentExecutionContext())
        
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
        
        @ViewState var state: MockState = .initialize()
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 3)
        
        $state.observe(sequence: initStateModel.loadStreamBackgroundExecutionContext())
        
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
        
        @ViewState var state: MockState = .initialize()
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 1)
        await $state.refresh(state: { await initStateModel.loadAsyncOnCurrentExecutionContext(count: 1) })
        
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
        
        @ViewState var state: MockState = .initialize()
        guard case let .initialize(initStateModel) = state else {
            throw StateContainerTestError.missingStartState
        }
        let stateChangsStream = $state.stateChangeStream(last: 1)
        await $state.refresh(state: { await initStateModel.loadAsyncOnBackgroundThread(count: 1) })
        
        var stateChanges: [MockState] = []
        for await stateChange in stateChangsStream {
            stateChanges.append(stateChange)
        }
        
        #expect(stateChanges == [expectedResult])
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
    }
    
    struct LoadedStateModel: Sendable, Equatable {
        let count: Int
    }
}
