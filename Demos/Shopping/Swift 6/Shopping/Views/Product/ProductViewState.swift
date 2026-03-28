//
//  ProductViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/14/22.
//

import Foundation
import VSM

// MARK: - State & Model Definitions

enum ProductViewState: Sendable {
    case initialized(ProductDetailLoaderModel)
    case loading
    case loaded(ProductDetail)
    case error(message: String, retry: @Sendable () async -> ProductViewState)
}

// MARK: - Model Implementations

struct ProductDetailLoaderModel: Sendable {
    typealias Dependencies = ProductRepositoryDependency
    let dependencies: Dependencies
    let productId: Int
    
    @StateSequenceBuilder
    func loadProductDetail() -> StateSequence<ProductViewState> {
        ProductViewState.loading
        Next { await self.getProductDetail() }
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

