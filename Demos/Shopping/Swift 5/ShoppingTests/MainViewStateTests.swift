//
//  MainViewStateTests.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import Combine
import Testing
@testable import Shopping

struct MainViewStateTests {
    
    /// Tests the loading state progression of the `DependenciesLoaderModel`
    @Test("DependenciesLoaderModel loads dependencies", .timeLimit(.minutes(1)))
    func testLoad() async throws {
        let mockedDependenciesProvider = AsyncResource<MainView.Dependencies>({ return MockAppDependencies.noOp })
        let subject = DependenciesLoaderModel(appDependenciesProvider: mockedDependenciesProvider)
        
        var states: [MainViewState] = []
        let publisher = subject.loadDependencies()
        
        // Collect states from the publisher using prefix and async/await
        try await withTimeout(seconds: 5) {
            await withCheckedContinuation { continuation in
                var cancellable: AnyCancellable?
                cancellable = publisher
                    .prefix(2)
                    .collect()
                    .sink { _ in
                        continuation.resume()
                        cancellable?.cancel()
                    } receiveValue: { collectedStates in
                        states = collectedStates
                    }
            }
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
        
        for try await state in stream.prefix(1) {
            if case .loaded(let model) = state {
                stateReceived = true
                #expect(model.cardCount >= 0)
                break
            }
        }
        
        #expect(stateReceived, "Expected to receive at least one state from cart count stream")
    }

}

private extension MainViewStateTests {
    func withTimeout(seconds: Double, operation: @escaping () async throws -> Void) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw TimeoutError()
            }
            
            try await group.next()
            group.cancelAll()
        }
    }
    
    struct TimeoutError: Error {}
}
