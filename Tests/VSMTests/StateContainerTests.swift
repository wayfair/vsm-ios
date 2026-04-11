//
//  StateContainerTests.swift
//  VSMTests
//
//  Created by Bill Dunay on 10/9/25.
//

import Foundation
import Observation
import OSLog
import SwiftUI
import Testing

@testable import VSM

@Suite
struct StateContainerTests {
    enum StateContainerTestError: Error {
        case missingStartState
    }

    /// Creates a fresh AsyncStateContainer for testing, avoiding @ViewState/@SwiftUI.State
    /// which requires a SwiftUI view graph to work correctly.
    ///
    /// Turns on `debugStateHistory` recording (`#if DEBUG` only) so `waitUntilRecordedStateChanges` can observe transitions.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    private func makeContainer(initialState: MockState = .initialize()) -> AsyncStateContainer<MockState> {
        let container = AsyncStateContainer(state: initialState, logger: .disabled)
        container.turnOnRecordingStateHistory()
        return container
    }
    
    // MARK: - Single State Change Tests
    
    @Test("Single Synchronous State Change")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func singleSynchronousStateChange() async throws {
        let expectedResult: [MockState] = [
            .loaded(.init(count: 1)),
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe(initStateModel.load())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("Single Asynchronous State Change (Main Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func singleAsynchronousStateChange() async throws {
        let expectedResult: [MockState] = [
            .loaded(.init(count: 10)),
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe { await initStateModel.loadAsync() }

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("Single Asynchronous State Change (Background Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func singleAsynchronousStateChangeOnBackgroundThread() async throws {
        let expectedResult: [MockState] = [
            .loaded(.init(count: 10)),
        ]
        let container = makeContainer()
        
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe { await initStateModel.loadAsyncOnBackgroundThread(count: 10) }

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    // MARK: - Multi-State Change Tests via StateSequence
    
    @Test("State Change via StateSequence expecting 2 states (Main Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
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
        container.observe(initStateModel.loadSequence())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("State Change via StateSequence expecting 2 states (executes on Main Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
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
        container.observe(initStateModel.loadSequenceAsync(onMainThread: true))

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("State Change via StateSequence expecting 2 states (executes on Background Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
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
        container.observe(initStateModel.loadSequenceAsync(onMainThread: false))

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    // MARK: - Multi-State Change Tests via AsyncStream
    
    @Test("State Change via AsyncStream expecting 3 states (Run on Main Thread)")
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
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
        container.observe(initStateModel.loadStreamCurrentExecutionContext())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("State Change via AsyncStream expecting 3 states (Run on Background Thread)")
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
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
        container.observe(initStateModel.loadStreamBackgroundExecutionContext())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("Await State change on Main Thread for PTR functionality")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func awaitingMainThreadStateChange() async throws {
        let expectedResult: MockState = .loaded(.init(count: 1))
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        await container.refresh(state: { await initStateModel.loadAsyncOnCurrentExecutionContext(count: 1) })

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))

        #expect(stateChanges == [expectedResult])
    }
    
    @Test("Await State change on Background Thread for PTR functionality")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func awaitingBackgroundThreadStateChange() async throws {
        let expectedResult: MockState = .loaded(.init(count: 1))
        
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        await container.refresh(state: { await initStateModel.loadAsyncOnBackgroundThread(count: 1) })

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))

        #expect(stateChanges == [expectedResult])
    }
    
    // MARK: - Refresh Cancellation Tests
    //
    // The 500ms sleep inside `refresh` keeps the refresh task alive long enough to cancel mid-flight.
    // The `while` + `Task.yield()` loop waits until that body has started (no `Task.sleep` polling).

    @Test("refresh(state:) is cancelled when a new observe is called (container-initiated)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func refreshCancelledByNewObserve() async throws {
        let container = makeContainer()

        let refreshStarted = OSAllocatedUnfairLock(initialState: false)
        let refreshTask = Task { @MainActor in
            await container.refresh(state: {
                refreshStarted.withLock { $0 = true }
                try? await Task.sleep(for: .milliseconds(500))
                return .loaded(.init(count: 999))
            })
        }

        while !refreshStarted.withLock({ $0 }) {
            await Task.yield()
        }

        container.observe(.loading)
        #expect(container.state == .loading)

        await refreshTask.value

        #expect(container.state == .loading)
    }

    @Test("refresh(state:) is cancelled when caller's task is cancelled (withTaskCancellationHandler)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func refreshCancelledByCallerTask() async throws {
        let container = makeContainer()

        let refreshStarted = OSAllocatedUnfairLock(initialState: false)
        let callerTask = Task { @MainActor in
            await container.refresh(state: {
                refreshStarted.withLock { $0 = true }
                try? await Task.sleep(for: .milliseconds(500))
                return .loaded(.init(count: 888))
            })
        }

        while !refreshStarted.withLock({ $0 }) {
            await Task.yield()
        }

        callerTask.cancel()
        await callerTask.value

        #expect(container.state == .initialize(.init()))
    }


    // MARK: - StateSequence

    @Test("Synchronous states in StateSequenceBuilder are applied immediately before observe returns")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func synchronousStateAppliedImmediatelyBeforeObserveReturns() async throws {
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        // Call observe with a StateSequenceBuilder-based sequence that has a
        // synchronous first state (.loading) followed by an async state.
        container.observe(initStateModel.loadSequenceAsync(onMainThread: true))

        // The key assertion: immediately after observe() returns (no await),
        // the container's state must already be .loading because the
        // StateSequenceBuilder classified it as a synchronous action and
        // observe() applies synchronous actions inline on the current call stack.
        #expect(container.state == .loading)

        // Wait for the full sequence to complete and verify both states arrived.
        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(stateChanges == [.loading, .loaded(.init(count: 2))])
    }
    
    // MARK: - StateSequenceBuilder Ordering Tests
    
    @Test("StateSequenceBuilder: mixed sync and async states arrive in declared order (Main Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func stateSequenceBuilderMixedOrderingMainThread() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2)),
            .loaded(.init(count: 3)),
        ]
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe(initStateModel.loadMixedSyncAsyncSequence())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 4, timeout: .seconds(10))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("StateSequenceBuilder: mixed sync and async states arrive in declared order (Background Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func stateSequenceBuilderMixedOrderingBackgroundThread() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 10)),
            .loaded(.init(count: 20)),
            .loaded(.init(count: 30)),
            .loaded(.init(count: 40)),
        ]
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe(initStateModel.loadMixedSyncAsyncSequenceBackground())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 5, timeout: .seconds(10))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("StateSequenceBuilder: all synchronous states arrive in declared order")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func stateSequenceBuilderAllSyncOrdering() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2)),
            .loaded(.init(count: 3)),
        ]
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe(initStateModel.loadAllSyncSequence())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 4, timeout: .seconds(10))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("StateSequenceBuilder: all async states arrive in declared order")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func stateSequenceBuilderAllAsyncOrdering() async throws {
        let expectedResult: [MockState] = [
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2)),
            .loaded(.init(count: 3)),
        ]
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe(initStateModel.loadAllAsyncSequence())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(10))

        #expect(stateChanges == expectedResult)
    }
    
    // MARK: - Array Literal StateSequence Ordering Tests
    
    @Test("Array literal StateSequence: mixed sync and async closures arrive in declared order (Main Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func arrayLiteralSequenceMixedOrderingMainThread() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2)),
            .loaded(.init(count: 3)),
        ]
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe(initStateModel.loadArrayLiteralMixedSequence())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 4, timeout: .seconds(10))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("Array literal StateSequence: mixed sync and async closures arrive in declared order (Background Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func arrayLiteralSequenceMixedOrderingBackgroundThread() async throws {
        let expectedResult: [MockState] = [
            .loading,
            .loaded(.init(count: 10)),
            .loaded(.init(count: 20)),
            .loaded(.init(count: 30)),
            .loaded(.init(count: 40)),
        ]
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        container.observe(initStateModel.loadArrayLiteralMixedSequenceBackground())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 5, timeout: .seconds(10))

        #expect(stateChanges == expectedResult)
    }
    
    // MARK: - Sanity Check Tests to ensure Mock types work as expected
    
    @Test("Sanity Check MockState sequence fires in the right order")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
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
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
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
        container.observe(initStateModel.loadSynchronousFirstStateThenRest())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    @Test("Sanity Check MockState stream fires in the right order (Main Thread)")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
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
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
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

    // MARK: - Binding Tests

    @Test("bind with Sendable state")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func bindWithSendableState() {
        struct FormState: Sendable, Equatable {
            var name: String
        }

        let container = AsyncStateContainer(state: FormState(name: "hello"), logger: .disabled)

        let binding: Binding<String> = container.bind(\.name, to: { state, newName in
            var copy = state
            copy.name = newName
            return copy
        })

        #expect(binding.wrappedValue == "hello")

        binding.wrappedValue = "world"
        #expect(container.state.name == "world")
    }

    @Test("bind curried overload `(State) -> (Value) -> State` with Sendable state")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func bindCurriedOverloadWithSendableState() {
        struct FormState: Sendable, Equatable {
            var name: String
        }

        let container = AsyncStateContainer(state: FormState(name: "hello"), logger: .disabled)

        let binding: Binding<String> = container.bind(\.name, to: { state in { newName in
            var copy = state
            copy.name = newName
            return copy
        } })

        #expect(binding.wrappedValue == "hello")
        binding.wrappedValue = "curried"
        #expect(container.state.name == "curried")
    }

    @Test("observe uses @Sendable overload when closure is @Sendable and State is Sendable")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func observeSendableOverloadWhenApplicable() async throws {
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let closure: @Sendable () async -> MockState = { await initStateModel.loadAsync() }
        container.observe(closure)
        let changes = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(changes == [.loaded(.init(count: 10))])
    }

    @Test("refresh uses @Sendable overload when closure is @Sendable and State is Sendable")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func refreshSendableOverloadWhenApplicable() async throws {
        let container = makeContainer()
        guard case let .initialize(initStateModel) = container.state else {
            throw StateContainerTestError.missingStartState
        }
        let closure: @Sendable () async -> MockState = { await initStateModel.loadAsyncOnCurrentExecutionContext(count: 1) }
        await container.refresh(state: closure)
        let changes = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(changes == [.loaded(.init(count: 1))])
    }
}

// MARK: - Mock Types for Testing State transitions

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
            return [
                { .loading },
                { .loaded(.init(count: 2)) }
            ]
        }
        
        @StateSequenceBuilder
        func loadSynchronousFirstStateThenRest() -> StateSequence<MockState> {
            MockState.loading
            MockState.loaded(.init(count: 2))
            MockState.loaded(.init(count: 11))
        }
        
        @StateSequenceBuilder
        func loadSequenceAsync(onMainThread: Bool) -> StateSequence<MockState> {
            MockState.loading
            
            if onMainThread {
                Next { await loadAsyncOnCurrentExecutionContext(count: 2) }
            } else {
                Next { await loadAsyncOnBackgroundThread(count: 2) }
            }
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
        
        // MARK: - StateSequenceBuilder Ordering Test Helpers
        
        /// A StateSequenceBuilder sequence with 4 states: sync, sync, async (main), sync-after-async.
        /// Verifies that all states arrive in declared order even when mixing sync and async.
        @StateSequenceBuilder
        func loadMixedSyncAsyncSequence() -> StateSequence<MockState> {
            MockState.loading                                           // sync 1
            MockState.loaded(.init(count: 1))                          // sync 2
            Next { await self.loadAsyncOnCurrentExecutionContext(count: 2) }  // async 3
            MockState.loaded(.init(count: 3))                          // sync-after-async 4
        }
        
        /// A StateSequenceBuilder sequence with 5 states mixing sync and async (background thread).
        @StateSequenceBuilder
        func loadMixedSyncAsyncSequenceBackground() -> StateSequence<MockState> {
            MockState.loading                                                   // sync 1
            MockState.loaded(.init(count: 10))                                  // sync 2
            Next { await self.loadAsyncOnBackgroundThread(count: 20) }          // async (bg) 3
            MockState.loaded(.init(count: 30))                                  // sync-after-async 4
            Next { await self.loadAsyncOnBackgroundThread(count: 40) }          // async (bg) 5
        }
        
        /// A StateSequenceBuilder sequence where all states are synchronous (no async at all).
        @StateSequenceBuilder
        func loadAllSyncSequence() -> StateSequence<MockState> {
            MockState.loading
            MockState.loaded(.init(count: 1))
            MockState.loaded(.init(count: 2))
            MockState.loaded(.init(count: 3))
        }
        
        /// A StateSequenceBuilder sequence where all states are async.
        @StateSequenceBuilder
        func loadAllAsyncSequence() -> StateSequence<MockState> {
            Next { await self.loadAsyncOnCurrentExecutionContext(count: 1) }
            Next { await self.loadAsyncOnBackgroundThread(count: 2) }
            Next { await self.loadAsyncOnCurrentExecutionContext(count: 3) }
        }
        
        // MARK: - Array Literal StateSequence Ordering Test Helpers
        
        /// An array-literal StateSequence with 4 closures mixing sync and async returns.
        /// All closures are treated as async by the array literal initializer.
        func loadArrayLiteralMixedSequence() -> StateSequence<MockState> {
            return [
                { .loading },
                { await self.loadAsyncOnCurrentExecutionContext(count: 1) },
                { .loaded(.init(count: 2)) },
                { await self.loadAsyncOnBackgroundThread(count: 3) },
            ]
        }
        
        /// An array-literal StateSequence with 5 closures mixing sync and async (background).
        func loadArrayLiteralMixedSequenceBackground() -> StateSequence<MockState> {
            return [
                { .loading },
                { .loaded(.init(count: 10)) },
                { await self.loadAsyncOnBackgroundThread(count: 20) },
                { .loaded(.init(count: 30)) },
                { await self.loadAsyncOnBackgroundThread(count: 40) },
            ]
        }
    }
    
    struct LoadedStateModel: Sendable, Equatable {
        let count: Int
    }
}

