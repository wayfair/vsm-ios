//
//  ProductViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/14/22.
//

import Combine
import Foundation
import VSM

// MARK: - State & Model Definitions

enum ProductViewState {
    case initialized(ProductDetailLoaderModel)
    case loading
    case loaded(ProductDetail)
    case error(message: String, retry: () async -> ProductViewState)
}

// MARK: - Model Implementations

struct ProductDetailLoaderModel {
    typealias Dependencies = ProductRepositoryDependency
    let dependencies: Dependencies
    let productId: Int
    
    func loadProductDetail() -> StateSequence<ProductViewState> {
        StateSequence(
            { .loading },
            { await self.getProductDetail() }
        )
    }
    
    @concurrent
    func getProductDetail() async -> ProductViewState {
        do {
            let prodDetail = try await self.dependencies.productRepository.getProductDetail(id: productId)
            return .loaded(prodDetail)
        } catch {
            return .error(message: "\(error)", retry: { await self.getProductDetail() })
        }
    }
}

