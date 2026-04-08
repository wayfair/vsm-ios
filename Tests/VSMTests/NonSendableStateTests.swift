//
//  NonSendableStateTests.swift
//  VSMTests
//
//  Created by Bill Dunay on 10/9/25.
//

import Combine
import Foundation
import OSLog
import SwiftUI
import Testing

@testable import VSM

/// A state type that is intentionally NOT Sendable to verify that
/// `AsyncStateContainer` works correctly without `Sendable` constraints.
enum NonSendableState: Equatable {
    case idle
    case loading
    case loaded(NonSendableModel)

    final class NonSendableModel: Equatable {
        var value: Int
        init(value: Int) { self.value = value }
        static func == (lhs: NonSendableModel, rhs: NonSendableModel) -> Bool {
            lhs.value == rhs.value
        }
    }
}

@Suite("Non-Sendable State Tests")
struct NonSendableStateTests {

    /// Turns on `debugStateHistory` recording (`#if DEBUG` only) for tests that use `waitUntilRecordedStateChanges`.
    @MainActor
    private func makeContainer(initialState: NonSendableState = .idle) -> AsyncStateContainer<NonSendableState> {
        let container = AsyncStateContainer(state: initialState, logger: .disabled)
        container.turnOnRecordingStateHistory()
        return container
    }

    @Test("Observe synchronous non-Sendable state")
    @MainActor
    func observeSynchronousState() {
        let container = makeContainer()
        container.observe(.loading)
        #expect(container.state == .loading)
    }

    @Test("Observe synchronous non-Sendable state — value reuse after observe (same actor)")
    @MainActor
    func observeSynchronousStateValueReuse() {
        let container = makeContainer()
        let model = NonSendableState.NonSendableModel(value: 42)
        let state = NonSendableState.loaded(model)
        container.observe(state)
        // Same actor: sending is a no-op, value reuse is fine
        #expect(container.state == .loaded(.init(value: 42)))
        #expect(model.value == 42)
        model.value = 99
        #expect(model.value == 99)
    }

    // MARK: — sending enforcement proof

    // `observe(_ nextState: sending State)` declares that the value is
    // transferred to the container's @MainActor region.
    //
    // When caller and callee share the same actor (the common case),
    // `sending` is a no-op — the value stays in the same region and can
    // be reused freely. (See observeSynchronousStateValueReuse above.)
    //
    // To prove region tracking protects against cross-isolation reuse,
    // we create a value on @MainActor, connect it to the actor's region
    // via observe(), then try to capture it into a Task.detached. This
    // mirrors the pattern from the bug report (swiftlang/swift#86896).
    //
    // ⚠️ As of Swift 6.3 (Xcode 26), there is a known compiler gap
    // (https://github.com/swiftlang/swift/issues/86896) where the
    // region-based isolation checker does not diagnose non-Sendable values
    // captured from an actor-isolated region into a concurrent context.
    // The issue is confirmed, triaged by @hborla, and assigned to
    // @gottesmm (fix in progress as of Feb 2026 but not yet shipped).
    // Once fixed, uncommenting the test below should produce a compiler
    // error on `state.value = 99`.
    //
    // UNCOMMENT AFTER swiftlang/swift#86896 IS FIXED:
    //
    // @Test("Region tracking prevents cross-isolation reuse")
    // @MainActor
    // func regionTrackingPreventsReuseAcrossIsolation() {
    //     final class DirectState { var value = 0 }
    //     let container = AsyncStateContainer(state: DirectState(), logger: .disabled)
    //     let state = DirectState()
    //     container.observe(state)    // state is now in the @MainActor region
    //     Task.detached {
    //         state.value = 99        // ← should error: captured from @MainActor
    //     }
    // }

    @Test("Observe async closure with non-Sendable state")
    @MainActor
    func observeAsyncClosure() async throws {
        let container = makeContainer()

        @concurrent
        func loadState() async -> NonSendableState {
            .loaded(.init(value: 42))
        }
        container.observe(loadState)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 42)))
        #expect(history == [.loaded(.init(value: 42))])
    }

    @Test("Observe StateSequence with non-Sendable state")
    @MainActor
    func observeStateSequence() async throws {
        let container = makeContainer()

        let sequence: StateSequence<NonSendableState> = [
            { .loading },
            { .loaded(.init(value: 7)) }
        ]
        container.observe(sequence)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 7)))
        #expect(history == [.loading, .loaded(.init(value: 7))])
    }

    @Test("StateSequenceBuilder with non-Sendable state produced on background thread")
    @MainActor
    func observeStateSequenceBuilder() async throws {
        let container = makeContainer()

        @concurrent
        func loadOnBackground() async -> NonSendableState {
            .loaded(.init(value: 5))
        }

        @StateSequenceBuilder
        var sequence: StateSequence<NonSendableState> {
            NonSendableState.loading
            Next { await loadOnBackground() }
        }
        container.observe(sequence)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 5)))
        #expect(history == [.loading, .loaded(.init(value: 5))])
    }

    @Test("StateSequence with non-Sendable state model capturing self (real-world pattern)")
    @MainActor
    func observeStateSequenceWithSelfCapture() async throws {
        let container = makeContainer()

        // Simulates a real-world state model: a non-Sendable class whose methods
        // return StateSequence closures that capture `self`.
        final class LoadedModel {
            var fetchCount = 0

            @StateSequenceBuilder
            func reload() -> StateSequence<NonSendableState> {
                NonSendableState.loading
                Next { [self] in
                    self.fetchCount += 1
                    return await self.fetchData()
                }
            }

            @concurrent
            private func fetchData() async -> NonSendableState {
                .loaded(.init(value: 42))
            }
        }

        let model = LoadedModel()
        container.observe(model.reload())

        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 42)))
        #expect(model.fetchCount == 1)
        #expect(history == [.loading, .loaded(.init(value: 42))])
    }

    @Test("Observe AsyncStream with non-Sendable state (iOS 18+)")
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    @MainActor
    func observeAsyncStream() async throws {
        let container = makeContainer()

        let stream = AsyncStream<NonSendableState> { continuation in
            continuation.yield(.loading)
            continuation.yield(.loaded(.init(value: 3)))
            continuation.finish()
        }
        container.observe(stream)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 3)))
        #expect(history == [.loading, .loaded(.init(value: 3))])
    }

    @Test("Refresh (pull-to-refresh) with non-Sendable state produced on background thread")
    @MainActor
    func refreshState() async {
        let container = makeContainer()

        @concurrent
        func loadState() async -> NonSendableState {
            .loaded(.init(value: 88))
        }
        await container.refresh(state: loadState)

        #expect(container.state == .loaded(.init(value: 88)))
    }

    @Test("ViewState compiles with non-Sendable state")
    @MainActor
    func viewStateCompiles() {
        let viewState = ViewState(wrappedValue: AsyncStateContainer(state: NonSendableState.idle, logger: .disabled))
        #expect(viewState.wrappedValue.state == .idle)
    }

    // MARK: - bind (no Sendable required)

    @Test("bind works with non-Sendable state — no State: Sendable constraint needed")
    @MainActor
    func bindWithNonSendableState() {
        struct FormState: Equatable {
            final class Model: Equatable {
                var name: String
                init(name: String) { self.name = name }
                static func == (lhs: Model, rhs: Model) -> Bool { lhs.name == rhs.name }
            }
            var model: Model
        }

        let container = AsyncStateContainer(
            state: FormState(model: .init(name: "hello")),
            logger: .disabled
        )

        let binding: Binding<FormState.Model> = container.bind(\.model, to: { state, newModel in
            var copy = state
            copy.model = newModel
            return copy
        })

        #expect(binding.wrappedValue.name == "hello")

        binding.wrappedValue = FormState.Model(name: "world")
        #expect(container.state.model.name == "world")
    }

    // MARK: - observeLegacyUnsafe(_:firstState:) (no Sendable required)

    @Test("observeLegacyUnsafe(_:firstState:) applies firstState synchronously — no hop")
    @MainActor
    func observePublisherWithFirstState() async throws {
        let container = makeContainer()

        let publisher = Just(NonSendableState.loaded(.init(value: 99)))
            .delay(for: .milliseconds(10), scheduler: DispatchQueue.main)

        container.observeLegacyUnsafe(publisher, firstState: .loading)

        #expect(container.state == .loading)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 99)))
        #expect(history == [.loading, .loaded(.init(value: 99))])
    }

    @Test("observeLegacyAsyncUnsafe proves the hop — pure async publisher does NOT apply first state synchronously")
    @MainActor
    func proveTheHop() async throws {
        let container = makeContainer()

        let publisher = Just(NonSendableState.loading)
            .append(Just(.loaded(.init(value: 77))))

        Task { @MainActor in
            for await state in publisher.values {
                container.observe(state)
            }
        }

        #expect(container.state == .idle, "Pure async path should NOT apply state synchronously")

        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 77)))
        #expect(history == [.loading, .loaded(.init(value: 77))])
    }

    @Test("observeLegacyUnsafe(_:firstState:) vs observeLegacyAsyncUnsafe — firstState is immediate, hop is not")
    @MainActor
    func firstStateVsHop() async throws {
        let containerA = makeContainer()
        let subjectA = PassthroughSubject<NonSendableState, Never>()
        containerA.observeLegacyUnsafe(subjectA, firstState: .loading)
        let stateAfterFirstState = containerA.state

        let containerB = makeContainer()
        let publisher = Just(NonSendableState.loading)
        Task { @MainActor in
            for await state in publisher.values {
                containerB.observe(state)
            }
        }
        let stateAfterHop = containerB.state

        #expect(stateAfterFirstState == .loading, "firstState: applies synchronously")
        #expect(stateAfterHop == .idle, "Task-based path has a hop — state unchanged")

        let historyB = await containerB.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(containerB.state == .loading)
        #expect(historyB == [.loading])
    }

    // MARK: - observeLegacyAsyncUnsafe (hop, no Sendable)

    @Test("observeLegacyAsyncUnsafe delivers all emissions asynchronously")
    @MainActor
    func observeLegacyAsyncUnsafeDeliversAll() async throws {
        let container = makeContainer()
        let publisher = Just(NonSendableState.loading)
            .append(Just(NonSendableState.loaded(.init(value: 42))))
            .eraseToAnyPublisher()

        container.observeLegacyAsyncUnsafe(publisher)

        #expect(container.state == .idle)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 42)))
        #expect(history == [.loading, .loaded(.init(value: 42))])
    }

    @Test("observeLegacyAsyncUnsafe proves hop — first state not applied synchronously")
    @MainActor
    func observeLegacyAsyncUnsafeProvesHop() async throws {
        let container = makeContainer()
        let publisher = Just(NonSendableState.loading)

        container.observeLegacyAsyncUnsafe(publisher)

        #expect(container.state == .idle)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(container.state == .loading)
        #expect(history == [.loading])
    }

    @Test("observeLegacyAsyncUnsafe cancels on new observation")
    @MainActor
    func observeLegacyAsyncUnsafeCancelsOnNewObservation() async throws {
        let container = makeContainer()
        // Replays when the async iterator subscribes — avoids the PassthroughSubject timing gap.
        let subject = CurrentValueSubject<NonSendableState, Never>(.loading)

        container.observeLegacyAsyncUnsafe(subject.eraseToAnyPublisher())

        #expect(container.state == .idle)

        var history = await container.waitUntilRecordedStateChanges(atLeast: 1, timeout: .seconds(5))
        #expect(container.state == .loading)
        #expect(history == [.loading])

        container.observe(.idle)
        #expect(container.state == .idle)

        subject.send(.loaded(.init(value: 99)))
        history = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .milliseconds(200))
        #expect(history == [.loading, .idle])
        #expect(container.state == .idle)
    }

    // MARK: - observeLegacyUnsafe(_:firstState:) — multiple emissions

    @Test("observeLegacyUnsafe(_:firstState:) delivers multiple emissions after firstState")
    @MainActor
    func observeLegacyUnsafeFirstStateMultipleEmissions() async throws {
        let container = makeContainer()
        let publisher = Just(NonSendableState.loaded(.init(value: 1)))
            .append(Just(NonSendableState.loaded(.init(value: 2))))
            .eraseToAnyPublisher()

        container.observeLegacyUnsafe(publisher, firstState: .loading)
        #expect(container.state == .loading)

        let history = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 2)))
        #expect(history == [
            .loading,
            .loaded(.init(value: 1)),
            .loaded(.init(value: 2)),
        ])
    }

    @Test("observeLegacyUnsafe(_:firstState:) cancels on new observation")
    @MainActor
    func observeLegacyUnsafeFirstStateCancelsOnNewObservation() async throws {
        let container = makeContainer()
        let subject = PassthroughSubject<NonSendableState, Never>()

        container.observeLegacyUnsafe(subject, firstState: .loading)
        #expect(container.state == .loading)

        container.observe(.idle)
        #expect(container.state == .idle)

        subject.send(.loaded(.init(value: 99)))
        let history = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .milliseconds(200))
        #expect(history == [.loading, .idle])
        #expect(container.state == .idle)
    }

    // MARK: - observeLegacyBlockingUnsafe (blocking, no Sendable)

    @Test("observeLegacyBlockingUnsafe applies first synchronous emission immediately")
    @MainActor
    func observeLegacyBlockingUnsafeFirstEmission() async throws {
        let container = makeContainer()
        let subject = CurrentValueSubject<NonSendableState, Never>(.loading)

        container.observeLegacyBlockingUnsafe(subject.eraseToAnyPublisher())

        #expect(container.state == .loading)

        subject.send(.loaded(.init(value: 55)))
        let history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 55)))
        #expect(history == [.loading, .loaded(.init(value: 55))])
    }

    @Test("observeLegacyBlockingUnsafe delivers multiple emissions")
    @MainActor
    func observeLegacyBlockingUnsafeMultipleEmissions() async throws {
        let container = makeContainer()
        let subject = CurrentValueSubject<NonSendableState, Never>(.loading)

        container.observeLegacyBlockingUnsafe(subject.eraseToAnyPublisher())
        #expect(container.state == .loading)

        subject.send(.loaded(.init(value: 1)))
        var history = await container.waitUntilRecordedStateChanges(atLeast: 2, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 1)))
        #expect(history == [.loading, .loaded(.init(value: 1))])

        subject.send(.loaded(.init(value: 2)))
        history = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .seconds(5))
        #expect(container.state == .loaded(.init(value: 2)))
        #expect(history == [
            .loading,
            .loaded(.init(value: 1)),
            .loaded(.init(value: 2)),
        ])

        subject.send(completion: .finished)
    }

    @Test("observeLegacyBlockingUnsafe cancels on new observation")
    @MainActor
    func observeLegacyBlockingUnsafeCancelsOnNewObservation() async throws {
        let container = makeContainer()
        let subject = CurrentValueSubject<NonSendableState, Never>(.loading)

        container.observeLegacyBlockingUnsafe(subject.eraseToAnyPublisher())
        #expect(container.state == .loading)

        container.observe(.idle)
        #expect(container.state == .idle)

        subject.send(.loaded(.init(value: 99)))
        let history = await container.waitUntilRecordedStateChanges(atLeast: 3, timeout: .milliseconds(200))
        #expect(history == [.loading, .idle])
        #expect(container.state == .idle)
    }

}
