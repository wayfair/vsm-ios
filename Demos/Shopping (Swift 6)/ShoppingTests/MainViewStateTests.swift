//
//  MainViewStateTests.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import Testing
@testable import Shopping

struct MainViewStateTests {
    
    /// Tests the loading state progression of the `DependenciesLoaderModel`
    @Test("DependenciesLoaderModel loads dependencies", .timeLimit(.minutes(1)))
    func testLoad() async throws {
        let mockedDependenciesProvider = MockDependenciesProvider(dependencies: MockAppDependencies.noOp())
        let subject = DependenciesLoaderModel(dependenciesProvider: mockedDependenciesProvider)
        
        var states: [MainViewState] = []
        let stateSequence = subject.loadDependencies()
        
        // Collect states from the StateSequence
        for try await state in stateSequence {
            states.append(state)
        }
        
        #expect(states.count == 2, "Expected 2 states but got \(states.count)")
        
        guard case .loading = states.first else {
            Issue.record("Expected first state of .loading, but got: \(states)")
            return
        }
        
        guard case .loaded = states.last else {
            Issue.record("Expected last state of .loaded, but got: \(states)")
            return
        }
    }

}
