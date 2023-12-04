//
//  CartButtonViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/17/22.
//

import Combine
import Foundation

// MARK: - State & Model Definitions

enum CartButtonViewState {
    case initialized(CartCountLoaderModel)
    case loaded(cartItemCount: Int)
}

// MARK: - Model Implementations

struct CartCountLoaderModel {
    typealias Dependencies = CartRepositoryDependency
    let dependencies: Dependencies
    
    func loadCount() -> some Publisher<CartButtonViewState, Never> {
        dependencies.cartRepository.cartItemCountPublisher
            .map({ count in .loaded(cartItemCount: count) })
            .eraseToAnyPublisher()
    }
}

extension CartButtonViewState {
    /// Convenience `loaded(cartItemCount: Int)` state accessor with default of 0
    var cartItemCount: Int {
        if case .loaded(let cartItemCount) = self {
            return cartItemCount
        } else {
            return 0
        }
    }
}
