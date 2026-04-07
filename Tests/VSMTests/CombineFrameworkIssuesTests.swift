//
//  CombineFrameworkIssuesTests.swift
//  VSMTests
//
//  Documents known Combine framework issues that affect VSM's legacy bridge code.
//  These tests are pure Combine — no AsyncStateContainer logic is involved.
//

import Combine
import Foundation
import Testing

@testable import VSM

// MARK: - publisher.values does NOT enforce Sendable

/// Proves that Apple's `AsyncPublisher` (`.values`) has no `Sendable` constraint on `Output`.
/// This is why VSM's "unsafe" legacy methods carry that label — they use `.values` internally
/// and inherit this risk for non-Sendable mutable reference types.
@Suite("Combine: publisher.values Sendable Gap")
struct PublisherValuesSendableGapTests {

    @Test("Apple's publisher.values compiles with non-Sendable types — no compiler protection")
    @MainActor
    func publisherValuesAcceptsNonSendable() async throws {
        // Proof that Apple's AsyncPublisher (.values) has NO Sendable constraint on Output.
        //
        // The bridge passes the same mutable reference across threads without any
        // compiler check. Both sides (publisher + consumer) can mutate the object
        // concurrently, causing torn reads/writes and lost increments.
        //
        // This is why our "unsafe" legacy methods carry that label — they use .values
        // internally and inherit this risk for non-Sendable mutable reference types.
        // The "safe" variants require State: Sendable to eliminate this class of bug.
        //
        // With TSan enabled, this test will flag the race condition.

        final class MutableModel {
            var counter = 0
        }

        // nonisolated(unsafe) opts out of Sendable checks — needed to capture
        // model in the DispatchQueue closure below. Ironically, Apple's .values
        // bridge does the equivalent silently without requiring this annotation.
        nonisolated(unsafe) let model = MutableModel()
        let subject = PassthroughSubject<MutableModel, Never>()

        // Force delivery on a background queue
        let backgroundPublisher = subject
            .subscribe(on: DispatchQueue.global(qos: .userInitiated))
            .receive(on: DispatchQueue.global(qos: .background))

        // Consumer iterates .values on background — mutates counter in a tight loop
        Task { @MainActor in
            for await value in backgroundPublisher.values {
                for _ in 0..<10_000 {
                    value.counter += 1
                }
            }
        }

        // Wait for subscription to be established on the background queue
        try await Task.sleep(for: .milliseconds(100))

        // Send the same mutable reference
        subject.send(model)

        // Simultaneously mutate from a background thread — real data race
        DispatchQueue.global(qos: .userInitiated).async {
            for _ in 0..<10_000 {
                model.counter += 1
            }
        }

        // Wait for both sides to finish
        try await Task.sleep(for: .milliseconds(500))

        // Without a race, counter would be exactly 20_000.
        // With a race, increments get lost due to torn reads/writes.
        // The compiler allowed all of this — no Sendable check anywhere.
        let finalCount = model.counter
        withKnownIssue("Apple's .values bridge allows data races on non-Sendable types", isIntermittent: true) {
            #expect(finalCount == 20_000, "Data race — got \(finalCount) instead of 20,000")
        }

        subject.send(completion: .finished)
    }
}

// MARK: - Combine append + delay + subscribe(on:) Race Condition

/// Isolated reproduction of a known Combine framework race condition.
///
/// Combine's `.append` + `.delay` + `.subscribe(on:)` operator combination can cause
/// the publisher's completion to fire before the appended publisher emits its value.
/// This is a pure Combine issue — no `AsyncStateContainer` or bridge code is involved.
///
/// This test exists to document the bug and explain intermittent failures in
/// `testObservingStatePublisherOnBackgroundThread`, which uses the same publisher pipeline.
@Suite("Combine: append + delay + subscribe(on:) Race")
struct CombinePublisherRaceConditionTests {

    @Test("Pure Combine: append + delay + subscribe(on:) delivers all values before completion")
    func appendDelaySubscribeOnRace() async throws {
        let expectedValues: [MockState] = [.loading, .loaded(.init(count: 11))]

        let publisher = MockState.InitializeStateModel().loadFromPublisherBackgroundThread()

        let values = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[MockState], Error>) in
            var received: [MockState] = []
            var cancellable: AnyCancellable?
            cancellable = publisher.sink(
                receiveCompletion: { _ in
                    continuation.resume(returning: received)
                    _ = cancellable // prevent premature dealloc
                },
                receiveValue: { value in
                    received.append(value)
                }
            )
        }

        withKnownIssue("Combine race: completion can fire before appended publisher emits", isIntermittent: true) {
            #expect(values == expectedValues)
        }
    }
}
