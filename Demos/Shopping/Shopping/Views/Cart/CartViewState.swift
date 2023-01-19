//
//  CartViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/15/22.
//

import Combine
import Foundation

// MARK: - State & Model Definitions

enum CartViewState {
    case initialized(CartLoaderModeling)
    case loading
    case loaded(CartLoadedModeling)
    case loadedEmpty
    case loadingError(CartLoadingErrorModeling)
    case removingProduct(CartRemovingProductModeling)
    case removingProductError(message: String, CartLoadedModeling)
    case checkingOut(CartCheckoutOutModeling)
    case checkoutError(message: String, CartLoadedModeling)
    case orderComplete(CartOrderCompleteModeling)
}

protocol CartLoaderModeling {
    func loadCart() -> AnyPublisher<CartViewState, Never>
}

protocol CartLoadedModeling {
    var cart: Cart { get }
    func removeProduct(id: Int) -> AnyPublisher<CartViewState, Never>
    func checkout() -> AnyPublisher<CartViewState, Never>
}

protocol CartLoadingErrorModeling {
    var message: String { get }
    var retry: () -> AnyPublisher<CartViewState, Never> { get }
}

protocol CartRemovingProductModeling {
    var cart: Cart { get }
}

protocol CartCheckoutOutModeling {
    var cart: Cart { get }
}

protocol CartOrderCompleteModeling {
    var cart: Cart { get }
}

// MARK: - Model Implementations

struct CartLoaderModel: CartLoaderModeling {
    typealias Dependencies = CartRepositoryDependency & CartLoadedModel.Dependencies
    let dependencies: Dependencies
    
    func loadCart() -> AnyPublisher<CartViewState, Never> {
        let statePublisher = Just(CartViewState.loading)
        let cartLoadingPublisher = dependencies.cartRepository.getCartProducts()
            .map { cart in
                if cart.products.isEmpty {
                    return CartViewState.loadedEmpty
                }
                return CartViewState.loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
            }
            .catch { error in
                Just(CartViewState.loadingError(CartLoadingErrorModel(message: "Failed to load cart: \(error)",
                                                                      retry: { loadCart() })))
            }
        return statePublisher
            .merge(with: cartLoadingPublisher)
            .eraseToAnyPublisher()
    }
}

struct CartLoadedModel: CartLoadedModeling {
    typealias Dependencies = CartRepositoryDependency & CartRemovingProductModel.Dependencies & DispatchQueueSchedulingDependency
    let dependencies: Dependencies
    let cart: Cart
    
    func removeProduct(id: Int) -> AnyPublisher<CartViewState, Never> {
        let loadingCart = Cart(products: cart.products.filter({ $0.cartId != id }))
        let statePublisher = CurrentValueSubject<CartViewState, Never>(CartViewState.removingProduct(CartRemovingProductModel(dependencies: dependencies, cart: loadingCart)))
        Task {
            do {
                let cart = try await dependencies.cartRepository.removeProductFromCart(cartId: id)
                if cart.products.isEmpty {
                    statePublisher.value = CartViewState.loadedEmpty
                } else {
                    statePublisher.value = .loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
                }
            } catch {
                statePublisher.value = .removingProductError(message: "Failed to remove cart item: \(error)", self)
            }
        }
        return statePublisher.eraseToAnyPublisher()
    }
    
    func checkout() -> AnyPublisher<CartViewState, Never> {
        let statePublisher = CurrentValueSubject<CartViewState, Never>(CartViewState.checkingOut(CartCheckoutOutModel(cart: cart)))
        Task {
            do {
                try await dependencies.cartRepository.checkout()
                statePublisher.value = .orderComplete(CartOrderCompleteModel(cart: cart))
            } catch {
                statePublisher.value = .checkoutError(message: "Insufficient funds!", self)
                // Using a scheduler dependency allows time control for unit tests
                dependencies.dispatchQueue.global.schedule(after: .init(.now() + 2)) {
                    statePublisher.value = .loaded(self)
                }
            }
        }
        return statePublisher.eraseToAnyPublisher()
    }
}

struct CartLoadingErrorModel: CartLoadingErrorModeling {
    let message: String
    let retry: () -> AnyPublisher<CartViewState, Never>
}

struct CartRemovingProductModel: CartRemovingProductModeling {
    typealias Dependencies = CartRepositoryDependency
    let dependencies: Dependencies
    let cart: Cart
}

struct CartCheckoutOutModel: CartCheckoutOutModeling {
    var cart: Cart
}

struct CartOrderCompleteModel: CartOrderCompleteModeling {
    var cart: Cart
}

extension CartViewState {
    var cart: Cart {
        switch self {
        case .initialized, .loading, .loadingError, .loadedEmpty:
            return Cart(products: [])
        case .loaded(let cartLoadedModeling), .checkoutError(_, let cartLoadedModeling), .removingProductError(_, let cartLoadedModeling):
            return cartLoadedModeling.cart
        case .removingProduct(let cartRemovingProductModeling):
            return cartRemovingProductModeling.cart
        case .checkingOut(let cartCheckoutOutModeling):
            return cartCheckoutOutModeling.cart
        case .orderComplete(let cartOrderCompleteModeling):
            return cartOrderCompleteModeling.cart
        }
    }
    
    var canCheckout: Bool {
        switch self {
        case .loaded, .removingProductError, .checkoutError:
            return true
        default:
            return false
        }
    }
    
    var isOrderComplete: Bool {
        if case .orderComplete = self {
            return true
        }
        return false
    }
    
    var isCheckingOut: Bool {
        if case .checkingOut = self {
            return true
        }
        return false
    }
}
