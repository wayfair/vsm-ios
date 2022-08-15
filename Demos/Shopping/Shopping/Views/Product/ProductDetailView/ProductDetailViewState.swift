//
//  ProductDetailViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/23/22.
//

import Combine
import Foundation

// MARK: - State & Model Definitions

enum ProductDetailViewState {
    case initialized
    case viewing(AddToCartModeling)
    case addingToCart
    case addedToCart(AddToCartModeling)
    case addToCartError(message: String, AddToCartModeling)
}

protocol AddToCartModeling {
    func addToCart() -> AnyPublisher<ProductDetailViewState, Never>
}

// MARK: - Model Implementations

struct AddToCartModel: AddToCartModeling {
    typealias Dependencies = CartRepositoryDependency & DispatchQueueSchedulingDependency
    let dependencies: Dependencies
    let productId: Int
    
    func addToCart() -> AnyPublisher<ProductDetailViewState, Never> {
        let publisher = CurrentValueSubject<ProductDetailViewState, Never>(.addingToCart)
        Task {
            do {
                try await dependencies.cartRepository.addProductToCart(productId: productId)
                publisher.value = .addedToCart(self)
                // Using a scheduler dependency allows time control for unit tests
                dependencies.dispatchQueue.global.schedule(after: .init(.now() + 2)) {
                    publisher.value = .viewing(self)
                }
            } catch {
                publisher.value = .addToCartError(message: "\(error)", self)
                // Using a scheduler dependency allows time control for unit tests
                dependencies.dispatchQueue.global.schedule(after: .init(.now() + 2)) {
                    publisher.value = .viewing(self)
                }
            }
        }
        return publisher.eraseToAnyPublisher()
    }
}

extension ProductDetailViewState {    
    var canAddToCart: Bool {
        switch self {
        case .viewing, .addedToCart, .addToCartError:
            return true
        case .addingToCart, .initialized:
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
}
