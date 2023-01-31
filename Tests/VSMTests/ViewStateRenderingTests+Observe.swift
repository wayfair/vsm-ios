//
//  ViewStateRenderingTests+Observe.swift
//  
//
//  Created by Albert Bori on 5/11/22.
//

import Combine
import SwiftUI
import XCTest
import VSM

/// Tests all forwarding Observe overloads on the `ViewStateRendering` protocol extension
class ViewStateRenderingTests_Observe: XCTestCase {
    var subject: AnyViewStateRendering<MockState>!

    override func setUpWithError() throws {
        subject = AnyViewStateRendering(container: .init(state: .bar))
    }

    override func tearDownWithError() throws {
        subject = nil
    }
    
    func testObserveSynchronous() throws {
        test(subject.container, expect: [.bar], when: { _ in subject.observe(.bar) })
    }
    
    func testObserveAsynchronous() throws {
        let asyncAction: () async -> MockState = {
            .bar
        }
        test(subject.container, expect: [.bar], when: { _ in subject.observeAsync({ await asyncAction() }) })
    }
    
    func testObserveAsynchronousSequence() throws {
        let asyncAction: () async -> StateSequence<MockState> = {
            .init({ .bar })
        }
        test(subject.container, expect: [.bar], when: { _ in subject.observeAsync({ await asyncAction() }) })
    }
    
    func testObservePublisher() throws {
        test(subject.container, expect: [.bar], when: { _ in subject.observe({ Just(.bar).eraseToAnyPublisher() }()) })
    }
}
