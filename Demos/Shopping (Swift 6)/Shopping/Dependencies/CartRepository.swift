//
//  CartRepository.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import AsyncAlgorithms
import Foundation

protocol CartRepository: Sendable {
    func getCartProducts() async throws -> Cart
    func addProductToCart(productId: Int) async throws
    func removeProductFromCart(cartId: UUID) async throws -> Cart
    func checkout() async throws
    
    func cartCountStream() async -> (UUID, AsyncStream<Int>)
    func removeContinuation(for id: UUID) async
}

protocol CartRepositoryDependency: Sendable {
    var cartRepository: CartRepository { get }
}

struct Cart: Sendable {
    var total: Decimal { products.map(\.price).reduce(0,+) }
    let products: [CartProduct]
}

struct CartProduct: Decodable, Sendable {
    let cartId: UUID
    let productId: Int
    let name: String
    let price: Decimal
}

//MARK: - Implementation

actor CartDatabase: CartRepository {
    typealias Dependencies = ProductRepositoryDependency
    
    private let dependencies: Dependencies
    private var cartCountContinuations: [UUID: AsyncStream<Int>.Continuation] = [:]

    private var cart: Cart = Cart(products: []) {
        didSet {
            let currentCount = cart.products.count
            cartCountContinuations.values.forEach {
                $0.yield(currentCount)
            }
        }
    }
        
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    func cartCountStream() -> (UUID, AsyncStream<Int>) {
        let currentCartCount = cart.products.count
        let continuationId = UUID()
        
        let cartCountStream = AsyncStream { continuation in
            self.cartCountContinuations[continuationId] = continuation
            
            continuation.yield(currentCartCount)
            
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(for: continuationId) }
            }
        }
        
        return (continuationId, cartCountStream)
    }
    
    func removeContinuation(for id: UUID) {
        cartCountContinuations[id] = nil
    }
    
    func getCartProducts() async throws -> Cart {
        // Pretend get from database or API
        try await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        return self.cart
    }
    
    func addProductToCart(productId: Int) async throws {
        let productDetail = try await dependencies.productRepository.getProductDetail(id: productId)
        var cartProducts = self.cart.products
        cartProducts.append(
            CartProduct(
                cartId: UUID(),
                productId: productId,
                name: productDetail.name,
                price: productDetail.price
            )
        )
            
        self.cart = Cart(products: cartProducts)
    }
    
    func removeProductFromCart(cartId: UUID) async throws -> Cart {
        var cartProducts = self.cart.products
        cartProducts.removeAll(where: { $0.cartId == cartId })
        self.cart = Cart(products: cartProducts)
        
        return self.cart
    }
    
    func checkout() async throws {
        enum Errors: Error {
            case insufficientFunds
        }
        
        try await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        
        if self.cart.total >= 600 {
            throw Errors.insufficientFunds
        } else {
            self.cart = Cart(products: [])
        }
    }
}

struct CartDatabaseDependencies: CartDatabase.Dependencies {
    var productRepository: ProductRepository
}

//MARK: Test Support

actor MockCartRepository: CartRepository {
    static var noOp: Self {
        Self.init(
            getCartProductsImpl: { Cart(products: []) },
            addProductToCartImpl: { _ in },
            removeProductFromCartImpl: { _ in Cart(products: [])},
            checkoutImpl: { },
            cartCountStreamImpl: {
                let streamUUID = UUID()
                let stream = AsyncStream<Int> { continuation in
                    continuation.yield(0)
                    continuation.finish()
                }
                
                return (streamUUID, stream)
            },
            removeContinuationImpl: { _ in }
        )
    }
    
    var getCartProductsImpl: () async throws -> Cart
    var addProductToCartImpl: (Int) async throws -> Void
    var removeProductFromCartImpl: (UUID) async throws -> Cart
    var checkoutImpl: () async throws -> Void
    var cartCountStreamImpl: () async -> (UUID, AsyncStream<Int>)
    var removeContinuationImpl: (UUID) async -> Void
    
    init(
        getCartProductsImpl: @escaping () async throws -> Cart,
        addProductToCartImpl: @escaping (Int) async throws -> Void,
        removeProductFromCartImpl: @escaping (UUID) async throws -> Cart,
        checkoutImpl: @escaping () async throws -> Void,
        cartCountStreamImpl: @escaping () async -> (UUID, AsyncStream<Int>),
        removeContinuationImpl: @escaping (UUID) async -> Void
    ) {
        self.getCartProductsImpl = getCartProductsImpl
        self.addProductToCartImpl = addProductToCartImpl
        self.removeProductFromCartImpl = removeProductFromCartImpl
        self.checkoutImpl = checkoutImpl
        self.cartCountStreamImpl = cartCountStreamImpl
        self.removeContinuationImpl = removeContinuationImpl
    }
    
    func getCartProducts() async throws -> Cart {
        try await getCartProductsImpl()
    }
    
    func addProductToCart(productId: Int) async throws {
        try await addProductToCartImpl(productId)
    }
    
    func removeProductFromCart(cartId: UUID) async throws -> Cart {
        try await removeProductFromCartImpl(cartId)
    }
    
    func checkout() async throws {
        try await checkoutImpl()
    }
    
    func cartCountStream() async -> (UUID, AsyncStream<Int>) {
        await cartCountStreamImpl()
    }
    
    func removeContinuation(for id: UUID) async {
        await removeContinuationImpl(id)
    }
}

