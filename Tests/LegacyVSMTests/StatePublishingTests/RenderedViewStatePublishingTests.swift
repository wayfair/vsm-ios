//
//  RenderedViewStatePublishingTests.swift
//  
//
//  Created by Albert Bori on 2/28/23.
//

@testable import VSM
import XCTest

@available(iOS 14.0, *)
final class RenderedViewStatePublishingTests: StatePublishingTests {
    
    override func setUp() {
        let renderedViewState = RenderedViewState(wrappedValue: MockState.foo, render: Self.render)
        statePublishingSubject = renderedViewState.projectedValue
        progressState = { renderedViewState.projectedValue.observe(.bar) }
        observedState = { renderedViewState.wrappedValue }
    }

    func render() {
        // no-op
    }
}
