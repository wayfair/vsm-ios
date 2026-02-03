//
//  ProductViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/14/22.
//

import Combine
import Foundation

// MARK: - State & Model Definitions

enum ProductViewState {
    case initialized(ProductDetailLoaderModel)
    case loading
    case loaded(ProductDetail)
    case error(message: String, retry: () -> AnyPublisher<ProductViewState, Never>)
}

// MARK: - Model Implementations

struct ProductDetailLoaderModel {
    typealias Dependencies = ProductRepositoryDependency
    let dependencies: Dependencies
    let productId: Int
    
    func loadProductDetail() -> AnyPublisher<ProductViewState, Never> {
        let statePublisher = Just(ProductViewState.loading)
        let productsPublisher = dependencies.productRepository.getProductDetail(id: productId)
            .map { product in ProductViewState.loaded(product) }
            .catch { error in Just(ProductViewState.error(message: "\(error)", retry: { self.loadProductDetail() })).eraseToAnyPublisher() }
        return statePublisher
            .merge(with: productsPublisher)
            .eraseToAnyPublisher()
    }
}
