//
//  ContainerLifetimeTests.swift
//  VSMTests
//
//  Verifies that releasing the last reference to an AsyncStateContainer cancels its in-flight
//  observation instead of letting the observing Task keep the container alive.
//

import Foundation
import os
import Testing

@testable import VSM

@Suite
struct ContainerLifetimeTests {
    enum LifetimeState: Sendable, Equatable {
        case idle
        case working
        case done
    }

    /// A thread-safe one-way flag that background work can set and the test can poll.
    final class Flag: Sendable {
        private let storage = OSAllocatedUnfairLock(initialState: false)
        var isSet: Bool { storage.withLock { $0 } }
        func set() { storage.withLock { $0 = true } }
    }

    /// Weak reference box so the test never holds a strong reference to the container.
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    final class WeakBox {
        weak var container: AsyncStateContainer<LifetimeState>?
    }

    /// Polls until `condition` is true or `timeout` elapses. Returns the final value of `condition`.
    @MainActor
    private func waitUntil(timeout: Duration = .seconds(2), _ condition: () -> Bool) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now + timeout
        while !condition() && clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test("Releasing the container cancels a suspended StateSequence step")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func releasingContainerCancelsSuspendedStateSequenceStep() async {
        let started = Flag()
        let cancellationObserved = Flag()
        let box = WeakBox()

        do {
            let container = AsyncStateContainer(state: LifetimeState.idle, logger: .disabled)
            box.container = container
            container.observe(StateSequence<LifetimeState>(
                { .working },
                {
                    started.set()
                    // Throws CancellationError as soon as the surrounding task is cancelled.
                    do { try await Task.sleep(for: .seconds(10)) } catch { cancellationObserved.set() }
                    return .done
                }
            ))
            #expect(await waitUntil { started.isSet }, "The Next step should have started")
        } // last strong reference released here

        #expect(box.container == nil, "Container should deallocate without waiting for the 10 second step")
        #expect(await waitUntil { cancellationObserved.isSet }, "Releasing the container should cancel the suspended step")
    }

    @Test("Releasing the container cancels an async closure observation")
    @available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, visionOS 2.0, macCatalyst 17.0, *)
    @MainActor
    func releasingContainerCancelsAsyncClosure() async {
        let started = Flag()
        let cancellationObserved = Flag()
        let box = WeakBox()

        do {
            let container = AsyncStateContainer(state: LifetimeState.idle, logger: .disabled)
            box.container = container
            container.observe {
                started.set()
                do { try await Task.sleep(for: .seconds(10)) } catch { cancellationObserved.set() }
                return LifetimeState.done
            }
            #expect(await waitUntil { started.isSet }, "The closure should have started")
        }

        #expect(box.container == nil, "Container should deallocate without waiting for the 10 second closure")
        #expect(await waitUntil { cancellationObserved.isSet }, "Releasing the container should cancel the closure")
    }

    @Test("Releasing the container terminates an AsyncStream that never finishes")
    @available(iOS 18.0, macOS 15.0, tvOS 18.0, watchOS 11.0, visionOS 2.0, macCatalyst 18.0, *)
    @MainActor
    func releasingContainerTerminatesInfiniteAsyncStream() async {
        let terminated = Flag()
        let box = WeakBox()

        do {
            let container = AsyncStateContainer(state: LifetimeState.idle, logger: .disabled)
            box.container = container
            let stream = AsyncStream<LifetimeState> { continuation in
                continuation.onTermination = { _ in terminated.set() }
                // Never yields and never finishes.
            }
            container.observe(stream)
            // Let the observing task start iterating.
            try? await Task.sleep(for: .milliseconds(50))
            #expect(!terminated.isSet)
        }

        #expect(await waitUntil { box.container == nil }, "Container observing an infinite stream should deallocate")
        #expect(await waitUntil { terminated.isSet }, "Stream's onTermination should fire once the container is released")
    }
}
