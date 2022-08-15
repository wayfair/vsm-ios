//
//  ViewStateRenderingTests+Bind.swift
//  
//
//  Created by Albert Bori on 5/11/22.
//

import Combine
import SwiftUI
import XCTest
import VSM

class ViewStateRenderingTests_Bind: XCTestCase {
    var subject: AnyViewStateRendering<MockBindableStateModel>!
    var cancellables: Set<AnyCancellable> = []

    override func setUpWithError() throws {
        subject = AnyViewStateRendering(container: .init(state: MockBindableStateModel(isEnabled: false)))
        
        let expectation = expectation(description: "Waiting for \(#function)")
        subject.container.$state
            .sink { state in
                if state.isEnabled {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
    }

    override func tearDownWithError() throws {
        subject = nil
        cancellables.forEach { $0.cancel() }
        cancellables = []
    }
    
    func testBindSynchronousClosure() throws {
        let binding = subject.bind(\.isEnabled, to: { state, newValue in state.toggleSync(newValue) })
        binding.wrappedValue = true
        waitForExpectations(timeout: 1)
    }
    
    func testBindSynchronousMethodSignature() throws {
        let binding = subject.bind(\.isEnabled, to: MockBindableStateModel.toggleSync)
        binding.wrappedValue = true
        waitForExpectations(timeout: 1)
    }
    
    func testBindAsynchronousClosure() throws {
        let binding = subject.bind(\.isEnabled, to: { state, newValue in await state.toggleAsync(newValue) })
        binding.wrappedValue = true
        waitForExpectations(timeout: 1)
    }
    
    func testBindAsynchronousMethodSignature() throws {
        let binding = subject.bind(\.isEnabled, to: MockBindableStateModel.toggleAsync)
        binding.wrappedValue = true
        waitForExpectations(timeout: 1)
    }
    
    func testBindPublisherClosure() throws {
        let binding = subject.bind(\.isEnabled, to: { state, newValue in state.togglePublisher(newValue) })
        binding.wrappedValue = true
        waitForExpectations(timeout: 1)
    }
    
    func testBindPublisherMethodSignature() throws {
        let binding = subject.bind(\.isEnabled, to: MockBindableStateModel.togglePublisher)
        binding.wrappedValue = true
        waitForExpectations(timeout: 1)
    }
}
