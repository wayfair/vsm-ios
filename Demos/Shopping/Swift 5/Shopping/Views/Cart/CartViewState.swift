//
//  CartViewState.swift
//  Shopping
//
//  Created by Albert Bori on 2/15/22.
//

import Combine
import Foundation
import VSM

// MARK: - State & Model Definitions

enum CartViewState {
    case initialized(CartLoaderModel)
    case loading
    case loaded(CartLoadedModel)
    case loadedEmpty(CartLoadedEmptyModel)
    case loadingError(CartLoadingErrorModel)
    case removingProduct(CartRemovingProductModel)
    case removingProductError(message: String, CartLoadedModel)
    case checkingOut(CartCheckoutOutModel)
    case checkoutError(message: String, CartLoadedModel)
    case orderComplete(CartOrderCompleteModel)
}

// MARK: - Protocols

// Protocol that allows both CartLoadedModel and CartLoadedEmptyModel to share
// the same reloadCart() implementation. This avoids code duplication since both
// states need to reload the cart when external changes occur (e.g., cart count changes).
protocol CartReloadable {
    var dependencies: CartLoadedModel.Dependencies { get }
}

extension CartReloadable {
    @StateSequenceBuilder
    func reloadCart() -> StateSequence<CartViewState> {
        CartViewState.loading
        Next { await getCartProducts() }
    }
    
    @concurrent
    private func getCartProducts() async -> CartViewState {
        do {
            let cart = try await dependencies.cartRepository.getCartProducts()
            if cart.products.isEmpty {
                return CartViewState.loadedEmpty(CartLoadedEmptyModel(dependencies: dependencies))
            }
            return CartViewState.loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
            
        } catch {
            return .loadingError(CartLoadingErrorModel(
                message: "Failed to load cart: \(error)",
                retry: { await getCartProducts() }
            ))
        }
    }
}

// MARK: - Model Implementations

struct CartLoaderModel {
    typealias Dependencies = CartRepositoryDependency & CartLoadedModel.Dependencies
    let dependencies: Dependencies
    
    @StateSequenceBuilder
    func loadCart() -> StateSequence<CartViewState> {
        CartViewState.loading
        Next { await getCartProducts() }
    }
    
    func refreshCart() async -> CartViewState {
        await getCartProducts()
    }
    
    @concurrent
    private func getCartProducts() async -> CartViewState {
        do {
            let cart = try await dependencies.cartRepository.getCartProducts()
            if cart.products.isEmpty {
                return CartViewState.loadedEmpty(CartLoadedEmptyModel(dependencies: dependencies))
            }
            return CartViewState.loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
            
        } catch {
            return .loadingError(CartLoadingErrorModel(
                message: "Failed to load cart: \(error)",
                retry: { await getCartProducts() }
            ))
        }
    }
}

// Represents the cart in a loaded state with products. Conforms to CartReloadable
// to share reload logic with CartLoadedEmptyModel.
struct CartLoadedModel: CartReloadable {
    typealias Dependencies = CartRepositoryDependency & CartRemovingProductModel.Dependencies & DispatchQueueSchedulingDependency
    let dependencies: Dependencies
    let cart: Cart
    
    func refreshCart() async -> CartViewState {
        await getCartProducts()
    }
    
    @concurrent
    private func getCartProducts() async -> CartViewState {
        do {
            let cart = try await dependencies.cartRepository.getCartProducts()
            if cart.products.isEmpty {
                return CartViewState.loadedEmpty(CartLoadedEmptyModel(dependencies: dependencies))
            }
            return CartViewState.loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
            
        } catch {
            return .loadingError(CartLoadingErrorModel(
                message: "Failed to load cart: \(error)",
                retry: { await getCartProducts() }
            ))
        }
    }
    
    func removeProduct(id: UUID) async -> CartViewState {
        do {
            let cart = try await dependencies.cartRepository.removeProductFromCart(cartId: id)
            if cart.products.isEmpty {
                return .loadedEmpty(.init(dependencies: dependencies))
            } else {
                return .loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
            }
        } catch {
            return .removingProductError(message: "Failed to remove cart item: \(error)", self)
        }
    }
    
    func checkout() -> AsyncStream<CartViewState> {
        AsyncStream { continuation in
            Task {
                continuation.yield(.checkingOut(CartCheckoutOutModel(cart: cart)))
                await performingCheckout(continuation)
                continuation.finish()
            }
        }
    }
    
    @concurrent
    private func performingCheckout(_ continuation: AsyncStream<CartViewState>.Continuation) async {
        do {
            try await dependencies.cartRepository.checkout()
            continuation.yield(.orderComplete(CartOrderCompleteModel(cart: cart)))
            
            try? await Task.sleep(for: .seconds(2))
            continuation.yield(.loadedEmpty(.init(dependencies: dependencies)))
            
        } catch {
            continuation.yield(.checkoutError(message: "Insufficient funds!", self))
        }
    }
}

struct CartLoadingErrorModel {
    let message: String
    let retry: () async -> CartViewState
}

// Represents the cart in an empty state (no products). Conforms to CartReloadable
// to share reload logic with CartLoadedModel, allowing both states to respond to
// external cart changes (e.g., when items are added from other screens).
struct CartLoadedEmptyModel: CartReloadable {
    typealias Dependencies = CartRepositoryDependency & CartLoadedModel.Dependencies
    let dependencies: Dependencies
    
    func refreshCart() async -> CartViewState {
        do {
            let cart = try await dependencies.cartRepository.getCartProducts()
            if cart.products.isEmpty {
                return CartViewState.loadedEmpty(CartLoadedEmptyModel(dependencies: dependencies))
            }
            return CartViewState.loaded(CartLoadedModel(dependencies: dependencies, cart: cart))
        } catch {
            return .loadingError(CartLoadingErrorModel(
                message: "Failed to load cart: \(error)",
                retry: { await self.refreshCart() }
            ))
        }
    }
}

struct CartRemovingProductModel {
    typealias Dependencies = CartRepositoryDependency
    let dependencies: Dependencies
    let cart: Cart
}

struct CartCheckoutOutModel {
    var cart: Cart
}

struct CartOrderCompleteModel {
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
