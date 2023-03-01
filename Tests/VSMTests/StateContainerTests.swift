import Combine
import TestableCombinePublishers
import XCTest
import VSM

class StateContainerTests: XCTestCase {
        
    // MARK: Task Cancellation Tests
    
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
    
    @available(*, deprecated, message: "This test will be removed when the publisher property is removed from the framework")
    func testStatePublisherTiming() {
        let subject = StateContainer<MockState>(state: .foo)
        let test = subject.publisher
            .dropFirst()
            .expect { state in
                XCTAssertEqual(state, .bar)
                XCTAssertEqual(subject.state, .bar)
            }
        subject.observe(.bar)
        test.waitForExpectations(timeout: 1)
    }
    
    func testEventStatePublisherTiming() {
        // Assures that the willSet and didSet publishers emit values at the appropriate times
        let subject = StateContainer<MockState>(state: .foo)
        let willSetTest = subject.willSetPublisher
            .dropFirst()
            .expect { state in
                XCTAssertEqual(state, .bar)
                XCTAssertEqual(subject.state, .foo)
            }
        let didSetTest = subject.didSetPublisher
            .dropFirst()
            .expect { state in
                XCTAssertEqual(state, .bar)
                XCTAssertEqual(subject.state, .bar)
            }
        subject.observe(.bar)
        willSetTest.waitForExpectations(timeout: 1)
        didSetTest.waitForExpectations(timeout: 1)
    }
}
