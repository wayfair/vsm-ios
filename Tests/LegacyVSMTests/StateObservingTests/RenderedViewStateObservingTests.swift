//
//  RenderedViewStateObservingTests.swift
//  
//
//  Created by Albert Bori on 2/28/23.
//

@testable import VSM
import XCTest

@available(iOS 14.0, *)
final class RenderedViewStateObservingTests: StateObservingTests {
    
    override func setUp() {
        let renderedViewState = RenderedViewState(wrappedValue: MockState.foo, render: Self.render)
        stateObservingSubject = renderedViewState.projectedValue
        observedState = { renderedViewState.wrappedValue }
        observedStatePublisher = renderedViewState.projectedValue.didSetPublisher
    }
        
    func render() {
        //no-op
    }
}
