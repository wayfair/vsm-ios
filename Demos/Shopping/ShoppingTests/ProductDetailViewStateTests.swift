//
//  ProductDetailViewStateTests.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import XCTest
@testable import Shopping

class ProductDetailViewStateTests: XCTestCase {

    /// Tests the state progression of the add-to-cart behavior of `AddToCartModel` (including time-control with an "immediate" scheduler)
    /// Scheduling convenience types are from https://github.com/pointfreeco/combine-schedulers
    func testAddToCart() throws {
        var mockDependencies = MockAppDependencies.noOp
        mockDependencies.mockCartRepository.addProductToCartImpl = { _ in
            usleep(1000) // Added 1ms delay because `addingToCart` state is skipped, if closure is instant
        }
        let subject = AddToCartModel(dependencies: mockDependencies, productId: 0)
        let output = try waitForPublisher(subject.addToCart(), expectedCount: 3, timeout: 5).get()
        if let firstOutput = output.first, case ProductDetailViewState.addingToCart = firstOutput { } else {
            XCTFail("Expected first state of .addingToCart, but got: \(output)")
        }
        if let secondOutput = output.dropFirst().first, case ProductDetailViewState.addedToCart = secondOutput { } else {
            XCTFail("Expected first state of .addedToCart, but got: \(output)")
        }
        if let thirdOutput = output.last, case ProductDetailViewState.viewing = thirdOutput { } else {
            XCTFail("Expected first state of .viewing, but got: \(output)")
        }
    }

}
