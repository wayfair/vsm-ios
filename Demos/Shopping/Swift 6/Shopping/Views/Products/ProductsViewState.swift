//
//  ProductsViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Foundation
import VSM

// MARK: - State & Model Definitions

enum ProductsViewState: Sendable {
    case initialized(ProductsLoaderModel)
    case loading
    case loaded(ProductsLoadedModel)
    case error(message: String, retry: @Sendable () async -> ProductsViewState)
}

// MARK: - Model Implementations

struct ProductsLoaderModel {
    typealias Dependencies = ProductRepositoryDependency
    let dependencies: Dependencies
    
    func loadProducts() -> StateSequence<ProductsViewState> {
        StateSequence(
            { .loading },
            { await fetchProductsFromServer() }
        )
    }
    
    @concurrent
    private func fetchProductsFromServer() async -> ProductsViewState {
        do {
            let products = try await dependencies.productRepository.getGridProducts()
            return .loaded(ProductsLoadedModel(products: products))
        } catch {
            return .error(message: "\(error)", retry: { await self.fetchProductsFromServer() })
        }
    }
}

struct ProductsLoadedModel {
    let products: [GridProduct]
    var productDetailId: Int? = nil
    
    func showProductDetail(id: Int) -> ProductsViewState {
        var mutableCopy = self
        mutableCopy.productDetailId = id
        return .loaded(mutableCopy)
    }
}
