//
//  RenderedViewStateTests.swift
//  
//
//  Created by Albert Bori on 2/28/23.
//

@testable import VSM
import XCTest

@available(iOS 14.0, *)
final class RenderedViewStateTests: XCTestCase {
    
    func testWillSetRender() {
        struct StatePair: Equatable {
            let current: MockState
            let future: MockState
        }
        let expectedPairs: [StatePair] = [
            .init(current: .foo, future: .foo),
            .init(current: .foo, future: .bar),
            .init(current: .bar, future: .baz)
        ]
        var actualPairs: [StatePair] = []
        let subject = MockWillSetRenderer(initialState: MockState.foo) { currentState, futureState in
            actualPairs.append(.init(current: currentState, future: futureState))
        }
        subject.$state.observe(.bar)
        subject.$state.observe(.baz)
        XCTAssertEqual(expectedPairs, actualPairs)
    }

    func testDidSetRender() {
        let expectedValues: [MockState] = [ .foo, .bar, .baz ]
        var actualValues: [MockState] = []
        let subject = MockDidSetRenderer(initialState: MockState.foo) { newState in
            actualValues.append(newState)
        }
        subject.$state.observe(.bar)
        subject.$state.observe(.baz)
        XCTAssertEqual(expectedValues, actualValues)
    }

}

@available(iOS 14.0, *)
private class MockWillSetRenderer<State> {
    @RenderedViewState var state: State
    var renderImpl: ((State, State) -> Void)?

    init(initialState: State, renderImpl: ((State, State) -> Void)? = nil) {
        _state = .init(wrappedValue: initialState, render: Self.renderOnWillSet)
        self.renderImpl = renderImpl
        $state.startRendering(on: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func renderOnWillSet(newState: State) {
        renderImpl?(state, newState)
    }
}

@available(iOS 14.0, *)
private class MockDidSetRenderer<State> {
    @RenderedViewState var state: State
    var renderImpl: ((State) -> Void)?

    init(initialState: State, renderImpl: ((State) -> Void)? = nil) {
        _state = .init(wrappedValue: initialState, render: Self.renderOnDidSet)
        self.renderImpl = renderImpl
        $state.startRendering(on: self)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func renderOnDidSet() {
        renderImpl?(state)
    }
}
