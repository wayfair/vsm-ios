//
//  ProductsViewStateTests.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import Testing
@testable import Shopping

struct ProductsViewStateTests {
    
    /// Tests the successful load state progression for `ProductsLoaderModel`
    @Test("ProductsLoaderModel loads products successfully")
    func testLoadSuccess() async throws {
        let mockDependencies = MockAppDependencies(
            mockProductRepository: MockProductRepository(
                getGridProductsImpl: { return [] },
                getProductsDetailImpl: { _ in
                    struct MockNoProductError: Error { }
                    throw MockNoProductError()
                }
            ),
            mockCartRepository: MockCartRepository.noOp,
            mockFavoritesRepository: MockFavoritesRepository.noOp,
            mockUserDefaults: StubbedUserDefaults(),
            mockUIFrameworkProvider: MockUIFrameworkProvider.noOp,
            mockProfileRepository: MockProfileRepository.noOp
        )
        let subject = ProductsLoaderModel(dependencies: mockDependencies)
        
        var states: [ProductsViewState] = []
        var iterator = subject.loadProducts().makeAsyncIterator()
        
        // Collect exactly 2 states from the sequence
        while let state = await iterator.next(), states.count < 2 {
            states.append(state)
        }
        
        #expect(states.count == 2, "Expected 2 states but got \(states.count)")
        
        guard case .loading = states[safe: 0] else {
            Issue.record("Expected first state of .loading, but got: \(states)")
            return
        }
        
        guard case .loaded = states[safe: 1] else {
            Issue.record("Expected second state of .loaded, but got: \(states)")
            return
        }
    }
    
    /// Tests the failure load state and retry state progression for `ProductsLoaderModel`
    @Test("ProductsLoaderModel handles load failure and retry")
    func testLoadFailRetry() async throws {
        let mockDependencies = MockAppDependencies(
            mockProductRepository: MockProductRepository(
                getGridProductsImpl: { throw MockError() },
                getProductsDetailImpl: { _ in
                    struct MockNoProductError: Error { }
                    throw MockNoProductError()
                }
            ),
            mockCartRepository: MockCartRepository.noOp,
            mockFavoritesRepository: MockFavoritesRepository.noOp,
            mockUserDefaults: StubbedUserDefaults(),
            mockUIFrameworkProvider: MockUIFrameworkProvider.noOp,
            mockProfileRepository: MockProfileRepository.noOp
        )
        let subject = ProductsLoaderModel(dependencies: mockDependencies)
        
        var states: [ProductsViewState] = []
        var iterator = subject.loadProducts().makeAsyncIterator()
        
        // Collect exactly 2 states from the sequence
        while let state = await iterator.next(), states.count < 2 {
            states.append(state)
        }
        
        #expect(states.count == 2, "Expected 2 states but got \(states.count)")
        
        guard case .loading = states[safe: 0] else {
            Issue.record("Expected first state of .loading, but got: \(states)")
            return
        }
        
        guard case .error(let message, let retry) = states[safe: 1] else {
            Issue.record("Expected second state of .error, but got: \(states)")
            return
        }
        
        #expect(message == "\(MockError())", "Expected error message to match MockError")
        
        // Test retry - retry returns a single state directly, not a sequence
        let retryState = await retry()
        guard case .error(let retryMessage, _) = retryState else {
            Issue.record("Expected retry to return .error state, but got: \(retryState)")
            return
        }
        
        #expect(retryMessage == "\(MockError())", "Expected retry error message to match MockError")
    }
    
    /// Tests the navigation binding action for `ProductsLoadedModel`
    @Test("ProductsLoadedModel handles navigation to product detail")
    func testNavigation() throws {
        let subject = ProductsLoadedModel(products: [], productDetailId: nil)
        let output = subject.showProductDetail(id: 1)
        
        guard case .loaded(let loadedModel) = output else {
            Issue.record("Expected state of .loaded, but got: \(output)")
            return
        }
        
        #expect(loadedModel.productDetailId == 1, "Expected productDetailId to be 1")
    }
}

