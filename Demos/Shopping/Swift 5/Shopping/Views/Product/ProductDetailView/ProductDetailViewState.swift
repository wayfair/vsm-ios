//
//  ProductDetailViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/23/22.
//

import Combine
import Foundation
import VSM

// MARK: - State & Model Definitions

enum ProductDetailViewState {
    case viewing(AddToCartModel)
    case addingToCart
    case addedToCart(AddToCartModel)
    case addToCartError(message: String, AddToCartModel)
}

// MARK: - Model Implementations

struct AddToCartModel {
    typealias Dependencies = CartRepositoryDependency & DispatchQueueSchedulingDependency
    let dependencies: Dependencies
    let productId: Int
    
    @StateSequenceBuilder
    func addToCart() -> StateSequence<ProductDetailViewState> {
        ProductDetailViewState.addingToCart
        Next { await performAddToCart() }
        Next { await resumeViewingState() }
    }
    
    @concurrent
    func performAddToCart() async -> ProductDetailViewState {
        do {
            try await Task.sleep(for: .seconds(2))
            try await dependencies.cartRepository.addProductToCart(productId: productId)
            
            return .addedToCart(self)
        } catch {
            return .addToCartError(message: error.localizedDescription, self)
        }
    }
    
    func resumeViewingState() async -> ProductDetailViewState {
        do {
            try await Task.sleep(for: .seconds(2))
            return .viewing(self)
            
        } catch {
            return .addToCartError(message: error.localizedDescription, self)
        }
    }
}

extension ProductDetailViewState {    
    var canAddToCart: Bool {
        switch self {
        case .viewing, .addedToCart, .addToCartError:
            return true
        case .addingToCart:
            return false
        }
    }
    
    var isAddingToCart: Bool {
        if case .addingToCart = self {
            return true
        } else {
            return false
        }
    }
    
    var isAddedToCart: Bool {
        if case .addedToCart = self {
            return true
        } else {
            return false
        }
    }
    
    var isAddToCartError: Bool {
        if case .addToCartError = self {
            return true
        } else {
            return false
        }
    }
    
    var addToCartErrorMessage: String? {
        if case .addToCartError(let message, _) = self {
            return message
        }
        return nil
    }
}
