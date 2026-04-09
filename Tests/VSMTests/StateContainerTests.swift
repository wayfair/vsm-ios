//
//  StateContainerTests.swift
//  VSMTests
//
//  Created by Bill Dunay on 10/9/25.
//

import Combine
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
    @MainActor
    private func makeContainer(initialState: MockState = .initialize()) -> AsyncStateContainer<MockState> {
        let container = AsyncStateContainer(state: initialState, logger: .disabled)
        container.turnOnRecordingStateHistory()
        return container
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
        container.observe(initStateModel.load())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))

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
        container.observe { await initStateModel.loadAsync() }

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))

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
        container.observe { await initStateModel.loadAsyncOnBackgroundThread(count: 10) }

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))

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
        container.observe(initStateModel.loadSequence())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

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
        container.observe(initStateModel.loadSequenceAsync(onMainThread: true))

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

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
        container.observeLegacyBlocking(initStateModel.loadFromPublisher())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }
    
    /// - Note: This test may fail intermittently due to a known Combine race condition
    ///   with `.append` + `.delay` + `.subscribe(on:)`. See `CombinePublisherRaceConditionTests`
    ///   for an isolated reproduction that proves the issue is in Combine, not in VSM.
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
        container.observeLegacyBlocking(initStateModel.loadFromPublisherBackgroundThread())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(stateChanges == expectedResult)
    }

    @Test("Observing Publisher applies synchronous first emission immediately")
    @MainActor
    func testObservingPublisherAppliesSynchronousFirstEmissionImmediately() async throws {
        let container = makeContainer()
        let subject = CurrentValueSubject<MockState, Never>(.loading)

        container.observeLegacyBlocking(subject.eraseToAnyPublisher())

        #expect(container.state == .loading)

        subject.send(.loaded(.init(count: 42)))

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(stateChanges == [.loading, .loaded(.init(count: 42))])
    }

    @Test("observeLegacyBlocking cancels previous publisher on new observation")
    @MainActor
    func testObserveLegacyBlockingCancelsOnNewObservation() async throws {
        let container = makeContainer()
        let subject = CurrentValueSubject<MockState, Never>(.loading)

        container.observeLegacyBlocking(subject.eraseToAnyPublisher())
        #expect(container.state == .loading)

        // New observation replaces the publisher
        container.observe(.initialize(.init()))
        #expect(container.state == .initialize(.init()))

        // Emissions from the old publisher should be ignored
        subject.send(.loaded(.init(count: 99)))
        let history = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .milliseconds(150))
        #expect(history == [.loading, .initialize(.init())])
        #expect(container.state == .initialize(.init()))
    }

    @Test("observeLegacyBlocking delivers multiple emissions")
    @MainActor
    func testObserveLegacyBlockingMultipleEmissions() async throws {
        let container = makeContainer()
        let subject = CurrentValueSubject<MockState, Never>(.loading)

        container.observeLegacyBlocking(subject.eraseToAnyPublisher())
        #expect(container.state == .loading)

        subject.send(.loaded(.init(count: 1)))
        subject.send(.loaded(.init(count: 2)))

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(5))

        #expect(stateChanges == [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2)),
        ])
    }

    // MARK: - observeLegacy (safe — Sendable)

    @Test("observeLegacy(_:firstState:) applies firstState synchronously with Sendable state")
    @MainActor
    func testObserveLegacySafeFirstState() async throws {
        let container = makeContainer()
        let publisher = Just(MockState.loaded(.init(count: 42))).eraseToAnyPublisher()

        container.observeLegacy(publisher, firstState: .loading)
        #expect(container.state == .loading)

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(stateChanges == [.loading, .loaded(.init(count: 42))])
    }

    @Test("observeLegacy(_:firstState:) delivers multiple emissions after firstState")
    @MainActor
    func testObserveLegacySafeFirstStateMultipleEmissions() async throws {
        let container = makeContainer()
        let publisher = Just(MockState.loaded(.init(count: 1)))
            .append(Just(MockState.loaded(.init(count: 2))))
            .eraseToAnyPublisher()

        container.observeLegacy(publisher, firstState: .loading)
        #expect(container.state == .loading)

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(5))

        #expect(container.state == .loaded(.init(count: 2)))
        #expect(stateChanges == [
            .loading,
            .loaded(.init(count: 1)),
            .loaded(.init(count: 2)),
        ])
    }

    @Test("observeLegacy(_:firstState:) cancels on new observation")
    @MainActor
    func testObserveLegacySafeFirstStateCancels() async throws {
        let container = makeContainer()
        let subject = PassthroughSubject<MockState, Never>()

        container.observeLegacy(subject, firstState: .loading)
        #expect(container.state == .loading)

        container.observe(.initialize(.init()))
        #expect(container.state == .initialize(.init()))

        subject.send(.loaded(.init(count: 99)))
        let history = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .milliseconds(150))
        #expect(history == [.loading, .initialize(.init())])
        #expect(container.state == .initialize(.init()))
    }

    // MARK: - observeLegacyAsync (safe — Sendable)

    @Test("observeLegacyAsync delivers emissions asynchronously with Sendable state")
    @MainActor
    func testObserveLegacySafeAsync() async throws {
        let container = makeContainer()
        let subject = CurrentValueSubject<MockState, Never>(.loading)

        container.observeLegacyAsync(subject.eraseToAnyPublisher())

        #expect(container.state == .initialize(.init()))

        _ = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(container.state == .loading)
    }

    @Test("observeLegacyAsync proves hop — first state not applied synchronously")
    @MainActor
    func testObserveLegacySafeAsyncProvesHop() async throws {
        let container = makeContainer()
        let publisher = Just(MockState.loading)

        container.observeLegacyAsync(publisher)

        #expect(container.state == .initialize(.init()))

        _ = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(container.state == .loading)
    }

    @Test("observeLegacyAsync delivers multiple emissions")
    @MainActor
    func testObserveLegacySafeAsyncMultipleEmissions() async throws {
        let container = makeContainer()
        let publisher = Just(MockState.loading)
            .append(Just(MockState.loaded(.init(count: 42))))
            .eraseToAnyPublisher()

        container.observeLegacyAsync(publisher)

        #expect(container.state == .initialize(.init()))

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))

        #expect(container.state == .loaded(.init(count: 42)))
        #expect(stateChanges == [.loading, .loaded(.init(count: 42))])
    }

    @Test("observeLegacyAsync cancels on new observation")
    @MainActor
    func testObserveLegacySafeAsyncCancels() async throws {
        let container = makeContainer()
        // Replays after `publisher.values` attaches — no yield loop needed (unlike PassthroughSubject).
        let subject = CurrentValueSubject<MockState, Never>(.loading)

        container.observeLegacyAsync(subject.eraseToAnyPublisher())

        #expect(container.state == .initialize(.init()))

        _ = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(container.state == .loading)

        container.observe(.initialize(.init()))
        #expect(container.state == .initialize(.init()))

        subject.send(.loaded(.init(count: 99)))
        let history = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .milliseconds(150))
        #expect(history == [.loading, .initialize(.init())])
        #expect(container.state == .initialize(.init()))
    }

    // MARK: - publisher.values subscription gap (PassthroughSubject)

    @Test("observeLegacyAsync drops PassthroughSubject if send runs before publisher.values subscription")
    @MainActor
    func observeLegacyAsyncDropsPassthroughIfSendBeforeSubscription() async throws {
        let container = makeContainer()
        let subject = PassthroughSubject<MockState, Never>()

        container.observeLegacyAsync(subject)
        #expect(container.state == .initialize(.init()))

        subject.send(.loading)
        let history = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .milliseconds(150))
        #expect(history.isEmpty)
        #expect(container.state == .initialize(.init()))
    }

    @Test("observeLegacy(firstState:) drops PassthroughSubject if send runs before publisher.values subscription")
    @MainActor
    func observeLegacyFirstStateDropsPassthroughIfSendBeforeSubscription() async throws {
        let container = makeContainer()
        let subject = PassthroughSubject<MockState, Never>()

        container.observeLegacy(subject, firstState: .loading)
        #expect(container.state == .loading)

        subject.send(.loaded(.init(count: 1)))
        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .milliseconds(150))
        #expect(history == [.loading])
        #expect(container.state == .loading)
    }

    @Test("observeLegacyAsync receives cold Just.append chain without Passthrough timing gap")
    @MainActor
    func observeLegacyAsyncReceivesColdPublisherChain() async throws {
        let container = makeContainer()
        let publisher = Just(MockState.loading)
            .append(Just(MockState.loaded(.init(count: 42))))
            .eraseToAnyPublisher()

        container.observeLegacyAsync(publisher)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(count: 42)))
        #expect(history == [.loading, .loaded(.init(count: 42))])
    }

    // MARK: - StateSequence

    @Test("Synchronous states in StateSequenceBuilder are applied immediately before observe returns")
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
        container.observe(initStateModel.loadSynchronousFirstStateThenRest())

        let stateChanges = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(5))

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

    // MARK: - Binding Tests

    @Test("bind with Sendable state")
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

