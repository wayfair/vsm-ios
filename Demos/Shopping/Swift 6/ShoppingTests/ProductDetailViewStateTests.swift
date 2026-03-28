//
//  ProductDetailViewStateTests.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import Foundation
import Testing
@testable import Shopping

struct ProductDetailViewStateTests {

    /// Tests the state progression of the add-to-cart behavior of `AddToCartModel`
    @Test("AddToCartModel progresses through states correctly")
    func testAddToCart() async throws {
        let mockCartRepository = MockCartRepository(
            getCartProductsImpl: { Cart(products: []) },
            addProductToCartImpl: { _ in
                try await Task.sleep(for: .milliseconds(10))
            },
            removeProductFromCartImpl: { _ in Cart(products: [])},
            checkoutImpl: { },
            cartCountStreamImpl: {
                let streamUUID = UUID()
                let stream = AsyncStream<Int> { continuation in
                    continuation.yield(0)
                    continuation.finish()
                }
                return (streamUUID, stream)
            },
            removeContinuationImpl: { _ in }
        )
        
        var mockDependencies = MockAppDependencies.noOp
        mockDependencies.mockCartRepository = mockCartRepository
        let subject = AddToCartModel(dependencies: mockDependencies, productId: 0)
        
        var states: [ProductDetailViewState] = []
        var iterator = subject.addToCart().makeAsyncIterator()
        
        // Collect exactly 3 states from the sequence
        while let state = try await iterator.next(), states.count < 3 {
            states.append(state)
        }
        
        #expect(states.count == 3, "Expected 3 states but got \(states.count)")
        
        guard case .addingToCart = states[safe: 0] else {
            Issue.record("Expected first state of .addingToCart, but got: \(states)")
            return
        }
        
        guard case .addedToCart = states[safe: 1] else {
            Issue.record("Expected second state of .addedToCart, but got: \(states)")
            return
        }
        
        guard case .viewing = states[safe: 2] else {
            Issue.record("Expected third state of .viewing, but got: \(states)")
            return
        }
    }
    
    /// Tests error handling in the add-to-cart behavior
    @Test("AddToCartModel handles errors correctly", .timeLimit(.minutes(1)))
    func testAddToCartError() async throws {
        let mockCartRepository = MockCartRepository(
            getCartProductsImpl: { Cart(products: []) },
            addProductToCartImpl: { _ in
                throw MockError(message: "Test error")
            },
            removeProductFromCartImpl: { _ in Cart(products: [])},
            checkoutImpl: { },
            cartCountStreamImpl: {
                let streamUUID = UUID()
                let stream = AsyncStream<Int> { continuation in
                    continuation.yield(0)
                    continuation.finish()
                }
                return (streamUUID, stream)
            },
            removeContinuationImpl: { _ in }
        )
        
        var mockDependencies = MockAppDependencies.noOp
        mockDependencies.mockCartRepository = mockCartRepository
        let subject = AddToCartModel(dependencies: mockDependencies, productId: 0)
        
        var states: [ProductDetailViewState] = []
        var iterator = subject.addToCart().makeAsyncIterator()
        
        // Collect first 2 states (addingToCart and error)
        // Note: StateSequence will have 3 states total, but we only check the error state
        if let state1 = try await iterator.next() {
            states.append(state1)
        }
        if let state2 = try await iterator.next() {
            states.append(state2)
        }
        
        #expect(states.count >= 2, "Expected at least 2 states but got \(states.count)")
        
        guard case .addingToCart = states[safe: 0] else {
            Issue.record("Expected first state of .addingToCart, but got: \(states)")
            return
        }
        
        guard case .addToCartError(let message, _) = states[safe: 1] else {
            Issue.record("Expected second state of .addToCartError, but got: \(states)")
            return
        }
        
        #expect(message.contains("Test error"), "Expected error message to contain 'Test error', but got: \(message)")
    }

}
