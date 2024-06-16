//
//  StateObservingTests.swift
//  
//
//  Created by Albert Bori on 2/27/23.
//

import Combine
@testable import VSM
import XCTest

/// Tests the `StatContainer`'s implementation of `StateObserving` and acts as a base class for other `StateObserving` types to test their desired outcomes
class StateObservingTests: XCTestCase {
    var stateObservingSubject: (any StateObserving<MockState>)!
    var observedState: (() -> MockState)!
    var observedStatePublisher: AnyPublisher<MockState, Never>!
    
    private var subject: any StateObserving<MockState> { stateObservingSubject }
    private var state: MockState { observedState() }
    private var statePublisher: AnyPublisher<MockState, Never> { observedStatePublisher }
    
    override func setUp() {
        let stateContainer = StateContainer<MockState>(state: .foo)
        stateObservingSubject = stateContainer
        observedState = { stateContainer.state }
        observedStatePublisher = stateContainer.$state.eraseToAnyPublisher()
    }
    
    override func tearDown() {
        stateObservingSubject = nil
        observedState = nil
        observedStatePublisher = nil
    }
    
    func testDefaultState() {
        XCTAssertEqual(state, .foo)
        statePublisher
            .expect(.foo)
            .waitForExpectations(timeout: 5)
    }
    
    func testObserveStatePublisher_MainThread() {
        let publisher = CurrentValueSubject<MockState, Never>(.bar)
        subject.observe(publisher.eraseToAnyPublisher())
        XCTAssertEqual(state, .bar)
        publisher.send(.baz)
        XCTAssertEqual(state, .baz)
    }
    
    func testObserveStatePublisher_BackgroundThread() {
        let publisher = CurrentValueSubject<MockState, Never>(.bar)
        subject.observe(publisher.subscribe(on: DispatchQueue.global()).eraseToAnyPublisher())
        XCTAssertEqual(state, .foo)
        statePublisher
            .dropFirst()
            .expect({ _ in
                XCTAssert(Thread.isMainThread, "Observed published-state action should sink on main thread.")
            })
            .expect(.bar)
            .waitForExpectations(timeout: 5)
    }
    
    func testObserveStatePublisher_Debounced() {
        func thunk(state: MockState) {
            subject.observe(Just(state).eraseToAnyPublisher(), debounced: 0.0000001)
        }
        thunk(state: .bar)
        thunk(state: .baz)
        thunk(state: .grault)
        XCTAssertEqual(state, .foo)
        statePublisher
            .dropFirst()
            .expect(.grault)
            .waitForExpectations(timeout: 5)
        
    }
    
    func testObserveNextState() {
        subject.observe(.bar)
        XCTAssertEqual(state, .bar)
    }
    
    func testObserveNextState_Debounced() {
        func thunk(state: MockState) {
            subject.observe(state, debounced: 0.0000001)
        }
        thunk(state: .bar)
        thunk(state: .baz)
        thunk(state: .grault)
        XCTAssertEqual(state, .foo)
        statePublisher
            .dropFirst()
            .expect(.grault)
            .waitForExpectations(timeout: 5)
    }
    
    func testObserveAsyncNextState_Synchronous() {
        XCTExpectFailure("MainActor implicit main-thread optimization not yet supported")
        @MainActor
        func thunk() async -> MockState {
            .bar
        }
        subject.observeAsync(thunk)
        XCTAssertEqual(state, .bar)
    }
    
    func testObserveAsyncNextState_Asynchronous() {
        subject.observeAsync({ .bar })
        XCTAssertEqual(state, .foo)
        statePublisher
            .dropFirst()
            .expect(.bar)
            .waitForExpectations(timeout: 5)
    }
    
    func testObserveAsyncNextState_Debounced() {
        func thunk(state: MockState) {
            subject.observeAsync({ state }, debounced: 0.0000001)
        }
        thunk(state: .bar)
        thunk(state: .baz)
        thunk(state: .grault)
        XCTAssertEqual(state, .foo)
        statePublisher
            .dropFirst()
            .expect(.grault)
            .waitForExpectations(timeout: 5)
    }
    
    func testObserveAsyncStateSequence_Synchronous() {
        XCTExpectFailure("MainActor implicit main-thread optimization not yet supported")
        @MainActor
        func thunk() async -> StateSequence<MockState> {
            let bar: @MainActor () -> MockState = { .bar }
            let baz: @MainActor () -> MockState = { .baz }
            return StateSequence(bar, baz)
        }
        let test = statePublisher
            .collect(3)
            .expect([.foo, .bar, .baz])
        subject.observeAsync(thunk)
        XCTAssertEqual(state, .baz)
        test.waitForExpectations(timeout: 5)
    }
    
    func testObserveAsyncStateSequence_Asynchronous() {
        let test = statePublisher
            .collect(3)
            .expect([.foo, .bar, .baz])
        subject.observeAsync({ StateSequence<MockState>({ .bar }, { .baz }) })
        XCTAssertEqual(state, .foo)
        test.waitForExpectations(timeout: 5)
    }
    
    func testObserveAsyncStateSequence_Debounced() {
        func thunk(state: MockState) {
            subject.observeAsync({ StateSequence<MockState>({ state }) }, debounced: 0.0000001)
        }
        thunk(state: .bar)
        thunk(state: .baz)
        thunk(state: .grault)
        XCTAssertEqual(state, .foo)
        statePublisher
            .dropFirst()
            .expect(.grault)
            .waitForExpectations(timeout: 5)
    }
    
    func testObserveStateSequence() {
        let test = statePublisher
            .collect(3)
            .expect([.foo, .bar, .baz])
        subject.observe(StateSequence<MockState>({ .bar }, { .baz }))
        XCTAssertEqual(state, .foo)
        test.waitForExpectations(timeout: 5)
    }
    
    func testObserveStateSequence_Debounced() {
        func thunk(state: MockState) {
            subject.observe(StateSequence<MockState>({ state }), debounced: 0.0000001)
        }
        thunk(state: .bar)
        thunk(state: .baz)
        thunk(state: .grault)
        XCTAssertEqual(state, .foo)
        statePublisher
            .dropFirst()
            .expect(.grault)
            .waitForExpectations(timeout: 5)
    }
}
