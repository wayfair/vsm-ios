import Combine
import TestableCombinePublishers
import XCTest
import VSM

class StateContainerTests: XCTestCase {
    
    // MARK: - Publisher Actions
    
    /// Asserts that observing state-emitting publisher actions will progress the state appropriately
    func testStatePublisherAction_MultipleStates_Immediate() throws {
        let mockAction: () -> AnyPublisher<MockState, Never> = {
            Deferred {
                [MockState.bar, MockState.baz].publisher
            }
            .eraseToAnyPublisher()
        }
        let subject = StateContainer<MockState>(state: .foo)
        test(subject, expect: [.foo, .bar, .baz], when: { $0.observe(mockAction()) })
    }

    /// Asserts that observing state-emitting publisher actions will progress the state appropriately
    func testStatePublisherAction_MultipleStates_Background() throws {
        let mockAction: () -> AnyPublisher<MockState, Never> = {
            Deferred {
                [MockState.bar, MockState.baz].publisher
                    .subscribe(on: DispatchQueue.global(qos: .background))
            }
            .eraseToAnyPublisher()
        }
        let subject = StateContainer<MockState>(state: .foo)
        test(subject, expect: [.foo, .bar, .baz], when: { $0.observe(mockAction()) })
    }
    
    /// Asserts that observing state-emitting publisher actions will progress the state appropriately
    func testStatePublisherAction_MultipleStates_Main() throws {
        let mockAction: () -> AnyPublisher<MockState, Never> = {
            Deferred {
                [MockState.bar, MockState.baz].publisher
                    .subscribe(on: DispatchQueue.main)
            }
            .eraseToAnyPublisher()
        }
        let subject = StateContainer<MockState>(state: .foo)
        test(subject, expect: [.foo, .bar, .baz], when: { $0.observe(mockAction()) })
    }
    
    /// Asserts that synchronous actions update the state on the same (main) thread. Prevents "extra-frame render" view initialization bugs.
    func testStatePublisherAction_MainThreadConsistency() throws {
        let mockAction: () -> AnyPublisher<MockState, Never> = {
            Just(MockState.bar).eraseToAnyPublisher()
        }
        XCTAssertTrue(Thread.isMainThread, "Unit test did not run on the main thread.")
        let subject = StateContainer<MockState>(state: .foo)
        subject.observe(mockAction())
        XCTAssertEqual(subject.state, .bar, "State was not updated synchronously by the synchronous action")
    }
    
    // MARK: - Async Actions
    
    /// Tests that observing state-emitting async actions will progress the state appropriately
    func testAsyncStateAction_Immediate() throws {
        let mockAction: () async -> MockState = {
            .bar
        }
        let subject = StateContainer<MockState>(state: .foo)
        test(subject, expect: [.foo, .bar], when: { $0.observeAsync({ await mockAction() }) })
    }
    
    /// Tests that observing state-emitting async actions will progress the state appropriately
    func testAsyncStateAction_Delayed() throws {
        let mockAction: () async -> MockState = {
            do {
                try await Task.sleep(seconds: 0.1)
            } catch {
                XCTFail("Task sleep error: \(error)")
            }
            return .bar
        }
        let subject = StateContainer<MockState>(state: .foo)
        test(subject, expect: [.foo, .bar], when: { $0.observeAsync({ await mockAction() }) })
    }
    
    /// Tests that observing long-running, state-emitting async actions will cancel when the subject is deallocated
    func testAsyncStateAction_Cancellation() throws {
        weak var weakSubject: StateContainer<MockState>?
        let cancellationExpectation = expectation(description: "Task is cancelled")
        func performActionOnMemoryScopedStateContainer() {
            let mockAction: () async -> MockState = {
                do {
                    for _ in 1...100 {
                        try await Task.sleep(seconds: 0.1)
                    }
                } catch {
                    XCTAssertTrue(error is CancellationError, "Unexpected error type!")
                    cancellationExpectation.fulfill()
                }
                return .foo
            }
            let subject = StateContainer<MockState>(state: .foo)
            weakSubject = subject
            subject.observeAsync({ await mockAction() })
        }
        performActionOnMemoryScopedStateContainer()
        XCTAssertNil(weakSubject, "\(type(of: weakSubject)) leaked!")
        waitForExpectations(timeout: 1)
    }
    
    // MARK: - Asynchronous Sequence Actions
    
    /// Tests that observing state-emitting async actions will progress the state appropriately
    func testAsyncStateSequenceAction_Awaitable_Immediate() throws {
        let mockAction: () async -> StateSequence<MockState> = {
            .init({ .bar }, { .baz })
        }
        let subject = StateContainer<MockState>(state: .foo)
        test(subject, expect: [.foo, .bar, .baz], when: { $0.observeAsync({ await mockAction() }) })
    }
    
    /// Tests that observing state-emitting async actions will progress the state appropriately
    func testAsyncStateSequenceAction_Awaitable_Delayed() throws {
        let mockAction: () async -> StateSequence<MockState> = {
            .init(
                { .bar },
                {
                    do {
                        try await Task.sleep(seconds: 0.1)
                    } catch {
                        XCTFail("Task sleep error: \(error)")
                    }
                    return .baz
                }
            )
        }
        let subject = StateContainer<MockState>(state: .foo)
        test(subject, expect: [.foo, .bar, .baz], when: { $0.observeAsync({ await mockAction() }) })
    }
    
    /// Tests that observing long-running, state-emitting async actions will cancel when the subject is deallocated
    func testAsyncStateSequenceAction_Cancellation() throws {
        weak var weakSubject: StateContainer<MockState>?
        let cancellationExpectation = expectation(description: "Task is cancelled")
        func performActionOnMemoryScopedStateContainer() {
            let mockAction: () -> StateSequence<MockState> = {
                .init(
                    { .bar },
                    {
                        do {
                            for _ in 1...100 {
                                try await Task.sleep(seconds: 0.1)
                            }
                        } catch {
                            XCTAssertTrue(error is CancellationError, "Unexpected error type!")
                            cancellationExpectation.fulfill()
                        }
                        return .baz
                    }
                )
            }
            let subject = StateContainer<MockState>(state: .foo)
            weakSubject = subject
            let negativeTest = subject.$state.collect(3).expectNoValue()
            test(subject, expect: [.foo, .bar], when: { $0.observeAsync(mockAction) })
            negativeTest.waitForExpectations(timeout: 1)
            
        }
        performActionOnMemoryScopedStateContainer()
        XCTAssertNil(weakSubject, "\(type(of: weakSubject)) leaked!")
        wait(for: [cancellationExpectation], timeout: 1)
    }
    
    /// Tests that observing long-running, state-emitting async actions will cancel when the subject is deallocated
    func testAsyncStateSequenceAction_Awaitable_Cancellation() throws {
        weak var weakSubject: StateContainer<MockState>?
        let cancellationExpectation = expectation(description: "Task is cancelled")
        func performActionOnMemoryScopedStateContainer() {
            let mockAction: () async -> StateSequence<MockState> = {
                .init(
                    { .bar },
                    {
                        do {
                            for _ in 1...100 {
                                try await Task.sleep(seconds: 0.1)
                            }
                        } catch {
                            XCTAssertTrue(error is CancellationError, "Unexpected error type!")
                            cancellationExpectation.fulfill()
                        }
                        return .baz
                    }
                )
            }
            let subject = StateContainer<MockState>(state: .foo)
            weakSubject = subject
            let negativeTest = subject.$state.collect(3).expectNoValue() // Should not emit .baz
            test(subject, expect: [.foo, .bar], when: { $0.observeAsync({ await mockAction() }) })
            negativeTest.waitForExpectations(timeout: 1)
            
        }
        performActionOnMemoryScopedStateContainer()
        XCTAssertNil(weakSubject, "\(type(of: weakSubject)) leaked!")
        wait(for: [cancellationExpectation], timeout: 1)
    }
    
    // MARK: - Synchronous Actions
    
    /// Tests that observing state-emitting synchronous actions will progress the state appropriately
    func testSyncStateAction() throws {
        let mockAction: () -> MockState = {
            .bar
        }
        let subject = StateContainer<MockState>(state: .foo)
        test(subject, expect: [.foo, .bar], when: { $0.observe(mockAction()) })
    }
    
    /// Tests that observing state-emitting synchronous actions will progress the state appropriately, even if fired from a background thread
    func testSyncStateAction_BackgroundObservation() throws {
        let mockAction: () -> MockState = {
            .bar
        }
        let subject = StateContainer<MockState>(state: .foo)
        let test = subject.$state
            .collect(2)
            .expect({ _ in XCTAssert(Thread.isMainThread, "Observed published-state action should sink on main thread.") })
            .expect([.foo, .bar])
        
        DispatchQueue.global().async {
            subject.observe(mockAction())
        }
        test.waitForExpectations(timeout: 1)
    }
    
    // MARK: - Action Interop
    
    /// Asserts that different state observation types will progress one to another in this order: Publisher -> Async -> Sync -> Async -> Publisher.
    func testAllActionTypesProgression() throws {
        let mockPublishedAction: () -> AnyPublisher<MockState, Never> = {
            return Deferred {
                Just(MockState.bar)
                    .subscribe(on: DispatchQueue.global(qos: .background))
            }
            .eraseToAnyPublisher()
        }
        let mockAsyncAction: () async -> MockState = {
            do {
                try await Task.sleep(seconds: 0.1)
            } catch {
                XCTFail("Task sleep error: \(error)")
            }
            return .baz
        }
        let mockSyncAction: () -> MockState = {
            .qux
        }
        let subject = StateContainer<MockState>(state: .foo)
        
        test(subject, expect: [.foo, .bar], when: { $0.observe(mockPublishedAction()) })
        test(subject, expect: [.bar, .baz], when: { $0.observeAsync({ await mockAsyncAction() }) })
        test(subject, expect: [.baz, .qux], when: { $0.observe(mockSyncAction()) })
        test(subject, expect: [.qux, .baz], when: { $0.observeAsync({ await mockAsyncAction() }) })
        test(subject, expect: [.baz, .bar], when: { $0.observe(mockPublishedAction()) })
    }
    
    /// Validates that a publisher's delayed output will not change the state if another action has been (or is being) observed
    func testAccidentalPublisherStateOverride() {
        let mockPublishedAction: () -> AnyPublisher<MockState, Never> = {
            let publisher = CurrentValueSubject<MockState, Never>(.bar)
            DispatchQueue.global().async {
                for newState in [MockState.corge, MockState.grault] {
                    Thread.sleep(forTimeInterval: 0.2)
                    publisher.value = newState
                }
            }
            return publisher.eraseToAnyPublisher()
        }
        let mockAsyncAction: () async -> MockState = {
            do {
                try await Task.sleep(seconds: 0.5)
            } catch {
                XCTFail("Task sleep error: \(error)")
            }
            return .baz
        }
        let mockSyncAction: () -> MockState = {
            .qux
        }
        let mockSyncAction2: () -> MockState = {
            .quux
        }
        let subject = StateContainer<MockState>(state: .foo)
        let negativeTest = subject.$state
            .expectNot(.corge)
            .expectNot(.grault)
        
        test(subject, expect: [.foo, .bar], when: { $0.observe(mockPublishedAction()) })
        test(subject, expect: [.bar, .baz], when: { $0.observeAsync({ await mockAsyncAction() }) })
        test(subject, expect: [.baz, .qux], when: { $0.observe(mockSyncAction()) })
        test(subject, expect: [.qux, .quux], when: { $0.observe(mockSyncAction2()) })
        
        negativeTest.waitForExpectations(timeout: 1)
    }
    
    /// Validates that a async action's delayed output will not change the state if another action has been (or is being) observed
    func testAccidentalAsyncStateOverride() {
        let cancellationExpectation = expectation(description: "Task is cancelled")
        let mockAsyncAction: () async -> MockState = {
            do {
                try await Task.sleep(seconds: 0.5)
            } catch {
                XCTAssertTrue(error is CancellationError, "Unexpected error type!")
                cancellationExpectation.fulfill()
            }
            return .bar
        }
        let mockSyncAction: () -> MockState = {
            .baz
        }
        let subject = StateContainer<MockState>(state: .foo)
        let negativeTest = subject.$state.collect(3).expectNoValue()
        
        subject.observeAsync({ await mockAsyncAction() })
        test(subject, expect: [.foo, .baz], when: { $0.observe(mockSyncAction()) })
        
        negativeTest.waitForExpectations(timeout: 1)
        wait(for: [cancellationExpectation], timeout: 1)
    }

    /// Validates that an asynchronous sequence's delayed output will not change the state if another action has been (or is being) observed
    func testAccidentalStateSequenceStateOverride() {
        let mockSequenceAction: () -> StateSequence<MockState> = {
            .init(
                { .bar },
                {
                    try? await Task.sleep(seconds: 0.2)
                    return .corge
                },
                {
                    try? await Task.sleep(seconds: 0.2)
                    return .grault
                }
            )
        }
        let mockAsyncAction: () async -> MockState = {
            do {
                try await Task.sleep(seconds: 0.5)
            } catch {
                XCTFail("Task sleep error: \(error)")
            }
            return .baz
        }
        let mockSyncAction: () -> MockState = {
            .qux
        }
        let mockSyncAction2: () -> MockState = {
            .quux
        }
        let subject = StateContainer<MockState>(state: .foo)
        let negativeTest = subject.$state
            .expectNot(.corge)
            .expectNot(.grault)

        test(subject, expect: [.foo, .bar], when: { $0.observeAsync(mockSequenceAction) })
        test(subject, expect: [.bar, .baz], when: { $0.observeAsync({ await mockAsyncAction() }) })
        test(subject, expect: [.baz, .qux], when: { $0.observe(mockSyncAction()) })
        test(subject, expect: [.qux, .quux], when: { $0.observe(mockSyncAction2()) })

        negativeTest.waitForExpectations(timeout: 1)
    }
}
