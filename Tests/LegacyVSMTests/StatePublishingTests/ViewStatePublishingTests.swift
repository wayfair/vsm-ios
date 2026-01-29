//
//  ViewStatePublishingTests.swift
//  
//
//  Created by Albert Bori on 2/28/23.
//

@testable import VSM
import XCTest

@available(iOS 14.0, *)
@available(tvOS 14.0, *)
final class ViewStatePublishingTests: StatePublishingTests {
    
    override func setUp() {
        let viewState = ViewState(wrappedValue: MockState.foo)
        statePublishingSubject = viewState.projectedValue
        progressState = { viewState.projectedValue.observe(.bar) }
        observedState = { viewState.wrappedValue }
    }
    
}
