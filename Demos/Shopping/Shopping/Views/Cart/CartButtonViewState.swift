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
    case initialized(CartCountLoaderModeling)
    case loaded(cartItemCount: Int)
}

protocol CartCountLoaderModeling {
    func loadCount() -> AnyPublisher<CartButtonViewState, Never>
}

// MARK: - Model Implementations

struct CartCountLoaderModel: CartCountLoaderModeling {
    typealias Dependencies = CartRepositoryDependency
    let dependencies: Dependencies
    
    func loadCount() -> AnyPublisher<CartButtonViewState, Never> {
        return dependencies.cartRepository.cartItemCountPublisher
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

// MARK: - Alternative approach using a simple single-state view model:

protocol Alt_CartButtonViewStateProviding {
    var cartItemCount: Int { get }
}

class Alt_CartButtonViewState: Alt_CartButtonViewStateProviding, ObservableObject {
    typealias Dependencies = CartRepositoryDependency
    @Published private(set) var cartItemCount: Int = 0
    
    init(dependencies: Dependencies) {
        dependencies.cartRepository.cartItemCountPublisher.assign(to: &$cartItemCount)
    }
}
