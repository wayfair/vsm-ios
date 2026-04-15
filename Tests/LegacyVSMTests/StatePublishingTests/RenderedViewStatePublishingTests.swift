//
//  RenderedViewStatePublishingTests.swift
//  
//
//  Created by Albert Bori on 2/28/23.
//

@testable import LegacyVSM
import XCTest

@available(iOS 14.0, *)
final class RenderedViewStatePublishingTests: StatePublishingTests {
    
    override func setUp() {
        let renderedViewState = LegacyRenderedViewState(wrappedValue: MockState.foo, render: Self.render)
        statePublishingSubject = renderedViewState.projectedValue
        progressState = { renderedViewState.projectedValue.observe(.bar) }
        observedState = { renderedViewState.wrappedValue }
    }

    func render() {
        // no-op
    }
}
