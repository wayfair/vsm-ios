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
    @MainActor
    func testLoad() async throws {
        let mockedDependenciesProvider = MockDependenciesProvider(dependencies: MockAppDependencies.noOp)
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
    
    /// Tests the cart count observation stream of the `MainViewLoadedModel`
    @Test("MainViewLoadedModel observes cart count changes")
    func testObserveCardCount() async throws {
        let mockDependencies = MockAppDependencies.noOp
        let subject = MainViewLoadedModel(dependencies: mockDependencies, cardCount: 0)
        
        // Observe cart count stream with a timeout
        let stream = subject.observeCardCount()
        var stateReceived = false
        
        // Use a task with timeout to avoid hanging indefinitely
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                for await state in stream.prefix(1) {
                    if case .loaded(let model) = state {
                        stateReceived = true
                        #expect(model.cardCount >= 0)
                        break
                    }
                }
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(5))
                throw TimeoutError()
            }
            
            try await group.next()
            group.cancelAll()
        }
        
        #expect(stateReceived, "Expected to receive at least one state from cart count stream")
    }

}

private extension MainViewStateTests {
    struct TimeoutError: Error {}
}
