//
//  StatePublishingTests.swift
//  
//
//  Created by Albert Bori on 2/28/23.
//

import Combine
@testable import VSM
import XCTest

/// Tests the `StatContainer`'s implementation of `StatePublishing` and acts as a base class for other `StatePublishing` types to test their desired outcomes
class StatePublishingTests: XCTestCase {
    var statePublishingSubject: (any StatePublishing<MockState>)!
    var progressState: (() -> Void)!
    var observedState: (() -> MockState)!
    
    private var subject: any StatePublishing<MockState> { statePublishingSubject }
    private var state: MockState { observedState() }
    
    override func setUp() {
        let stateContainer = StateContainer<MockState>(state: .foo)
        statePublishingSubject = stateContainer
        progressState = { stateContainer.observe(.bar) }
        observedState = { stateContainer.state }
    }
    
    override func tearDown() {
        statePublishingSubject = nil
        progressState = nil
        observedState = nil
    }
    
    @available(*, deprecated, message: "Will be removed in a future version")
    func testStatePublisher_SendOnDidSet() {
        let test = subject
            .publisher
            .dropFirst()
            .expect({ _ in XCTAssertEqual(self.state, .bar) })
            .expect(.bar)
        XCTAssertEqual(state, .foo)
        progressState()
        test.waitForExpectations(timeout: 5)
    }
    
    func testWillSetStatePublisher() {
        let test = subject
            .willSetPublisher
            .dropFirst()
            .expect({ _ in XCTAssertEqual(self.state, .foo) })
            .expect(.bar)
        XCTAssertEqual(state, .foo)
        progressState()
        test.waitForExpectations(timeout: 5)
        XCTAssertEqual(state, .bar)
    }
    
    func testDidSetStatePublisher() {
        let test = subject
            .didSetPublisher
            .dropFirst()
            .expect({ _ in XCTAssertEqual(self.state, .bar) })
            .expect(.bar)
        XCTAssertEqual(state, .foo)
        progressState()
        test.waitForExpectations(timeout: 5)
    }
}
