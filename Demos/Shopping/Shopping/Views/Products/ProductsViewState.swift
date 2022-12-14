//
//  ProductsViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Combine
import Foundation

// MARK: - State & Model Definitions

enum ProductsViewState {
    case initialized(ProductsLoaderModeling)
    case loading
    case loaded(ProductsLoadedModeling)
    case error(message: String, retry: () -> AnyPublisher<ProductsViewState, Never>)
}

protocol ProductsLoaderModeling {
    func loadProducts() -> AnyPublisher<ProductsViewState, Never>
}

protocol ProductsLoadedModeling {
    var products: [GridProduct] { get }
    var productDetailId: Int? { get }
    
    func showProductDetail(id: Int) -> ProductsViewState
}

// MARK: - Model Implementations

struct ProductsLoaderModel: ProductsLoaderModeling {
    typealias Dependencies = ProductRepositoryDependency
    let dependencies: Dependencies
    
    func loadProducts() -> AnyPublisher<ProductsViewState, Never> {
        let statePublisher = Just(ProductsViewState.loading)
        let productsPublisher = dependencies.productRepository.getGridProducts()
            .map { products in ProductsViewState.loaded(ProductsLoadedModel(products: products)) }
            .catch { error in Just(ProductsViewState.error(message: "\(error)", retry: { self.loadProducts() })).eraseToAnyPublisher() }
        return statePublisher
            .merge(with: productsPublisher)
            .eraseToAnyPublisher()
    }
}

struct ProductsLoadedModel: ProductsLoadedModeling {
    let products: [GridProduct]
    var productDetailId: Int? = nil
    
    func showProductDetail(id: Int) -> ProductsViewState {
        var mutableCopy = self
        mutableCopy.productDetailId = id
        return .loaded(mutableCopy)
    }
}
