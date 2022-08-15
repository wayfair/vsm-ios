//
//  CartRepository.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Combine
import Foundation

protocol CartRepository {
    var cartItemCountPublisher: AnyPublisher<Int, Never> { get }
    
    func getCartProducts() -> AnyPublisher<Cart, Error>
    func addProductToCart(productId: Int) async throws
    func removeProductFromCart(cartId: Int) async throws -> Cart
    func checkout() async throws
}

protocol CartRepositoryDependency {
    var cartRepository: CartRepository { get }
}

struct Cart {
    var total: Decimal { products.map(\.price).reduce(0,+) }
    let products: [CartProduct]
}

struct CartProduct: Decodable {
    let cartId: Int
    let productId: Int
    let name: String
    let price: Decimal
}

//MARK: - Implementation

class CartDatabase: CartRepository {
    typealias Dependencies = ProductRepositoryDependency
    let dependencies: Dependencies
    @Published private var cart: Cart = Cart(products: []) // Not thread-safe
    lazy private (set) var cartItemCountPublisher: AnyPublisher<Int, Never> = {
        $cart.map({ $0.products.count }).eraseToAnyPublisher()        
    }()
    private var cancellables = Set<AnyCancellable>()
        
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    func getCartProducts() -> AnyPublisher<Cart, Error> {
        // Pretend get from database or API
        return Future<Cart, Error> { promise in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                // Pretend to sync fetched cart products with ones in memory
                promise(.success(self.cart))
            }
        }.eraseToAnyPublisher()
    }
    
    func addProductToCart(productId: Int) async throws {
        return try await withCheckedThrowingContinuation({ continuation in
            dependencies.productRepository.getProductDetail(id: productId)
                .sink(receiveCompletion: { result in
                    switch(result) {
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    case .finished:
                        continuation.resume(returning: Void())
                    }
                }, receiveValue: { [weak self] productDetail in
                    guard let strongSelf = self else { return }
                    var cartProducts = strongSelf.cart.products
                    cartProducts.append(
                        CartProduct(
                            cartId: cartProducts.count + 1,
                            productId: productDetail.id,
                            name: productDetail.name,
                            price: productDetail.price
                        )
                    )
                    strongSelf.cart = Cart(products: cartProducts)
                })
                .store(in: &cancellables)
        })
    }
    
    func removeProductFromCart(cartId: Int) async throws -> Cart {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                var cartProducts = self.cart.products
                cartProducts.removeAll(where: { $0.cartId == cartId })
                self.cart = Cart(products: cartProducts)
                continuation.resume(returning: self.cart)
            }
        }
    }
    
    func checkout() async throws {
        enum Errors: Error {
            case insufficientFunds
        }
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                if self.cart.total >= 600 {
                    continuation.resume(with: .failure(Errors.insufficientFunds))
                } else {
                    self.cart = Cart(products: [])
                    continuation.resume(with: .success(Void()))
                }
            }
        }
    }
}

struct CartDatabaseDependencies: CartDatabase.Dependencies {
    var productRepository: ProductRepository
}

//MARK: Test Support

struct MockCartRepository: CartRepository {
    static var noOp: Self {
        Self.init(
            cartItemCountPublisher: .empty(),
            getCartProductsImpl: { .empty() },
            addProductToCartImpl: { _ in },
            removeProductFromCartImpl: { _ in Cart(products: [])},
            checkoutImpl: { }
        )
    }
    
    var cartItemCountPublisher: AnyPublisher<Int, Never>
    
    var getCartProductsImpl: () -> AnyPublisher<Cart, Error>
    func getCartProducts() -> AnyPublisher<Cart, Error> {
        getCartProductsImpl()
    }
    
    var addProductToCartImpl: (Int) async throws -> Void
    func addProductToCart(productId: Int) async throws {
        try await addProductToCartImpl(productId)
    }
    
    var removeProductFromCartImpl: (Int) async throws -> Cart
    func removeProductFromCart(cartId: Int) async throws -> Cart {
        try await removeProductFromCartImpl(cartId)
    }
    
    var checkoutImpl: () async throws -> Void
    func checkout() async throws {
        try await checkoutImpl()
    }
}
