//
//  ViewStateObservingTests.swift
//  
//
//  Created by Albert Bori on 2/28/23.
//

@testable import LegacyVSM
import XCTest
import SwiftUI

@available(iOS 14.0, *)
@available(tvOS 14.0, *)
final class ViewStateObservingTests: StateObservingTests {
    
    override func setUp() {
        let viewState = LegacyViewState(wrappedValue: MockState.foo)
        stateObservingSubject = viewState.projectedValue
        observedState = { viewState.wrappedValue }
        observedStatePublisher = viewState.projectedValue.didSetPublisher
    }

}
