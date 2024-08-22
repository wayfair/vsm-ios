//
//  ProductsViewStateTests.swift
//  ShoppingTests
//
//  Created by Albert Bori on 2/26/22.
//

import Combine
import XCTest
@testable import Shopping

class ProductsViewStateTests: XCTestCase {
    
    /// Tests the successful load state progression for `ProductsLoaderModel`
    func testLoadSuccess() throws {
        var mockDependencies = MockAppDependencies.noOp
        mockDependencies.mockProductRepository.getGridProductsImpl = { return .just([]) }
        let subject = ProductsLoaderModel(dependencies: mockDependencies)
        let output = try waitForPublisher(subject.loadProducts()).get()
        if let firstOutput = output.first, case ProductsViewState.loading = firstOutput { } else {
            XCTFail("Expected first state of .loading, but got: \(output)")
        }
        if let lastOuput = output.last, case ProductsViewState.loaded = lastOuput { } else {
            XCTFail("Expected first state of .loading, but got: \(output)")
        }
    }
    
    /// Tests the failure load state and retry state progression for `ProductsLoaderModel`
    func testLoadFailRetry() throws {
        var mockDependencies = MockAppDependencies.noOp
        mockDependencies.mockProductRepository.getGridProductsImpl = { return .fail(MockError()) }
        let subject = ProductsLoaderModel(dependencies: mockDependencies)
        let output = try waitForPublisher(subject.loadProducts()).get()
        if let firstOutput = output.first, case ProductsViewState.loading = firstOutput { } else {
            XCTFail("Expected first state of .loading, but got: \(output)")
        }
        if let lastOuput = output.last, case ProductsViewState.error(message: let message, retry: let retry) = lastOuput {
            XCTAssertEqual(message, "\(MockError())")
            // test retry
            let output = try waitForPublisher(retry()).get()
            if let firstOutput = output.first, case ProductsViewState.loading = firstOutput { } else {
                XCTFail("Expected first state of .loading, but got: \(output)")
            }
            if let lastOuput = output.last, case ProductsViewState.error(message: let message, retry: _) = lastOuput {
                XCTAssertEqual(message, "\(MockError())")
            } else {
                XCTFail("Expected first state of .error, but got: \(output)")
            }
        } else {
            XCTFail("Expected first state of .error, but got: \(output)")
        }
    }
    
    /// Tests the navigation binding action for `ProductsLoadedModel`
    func testNavigation() throws {
        let mockDependencies = MockAppDependencies.noOp
        let subject = ProductsLoadedModel(dependencies: mockDependencies, products: [], productDetailId: nil)
        let output = subject.showProductDetail(id: 1)
        if case ProductsViewState.loaded(let loadedModel) = output {
            XCTAssertEqual(loadedModel.productDetailId, 1)
        } else {
            XCTFail("Expected state of .loaded, but got: \(output)")
        }
    }
}
