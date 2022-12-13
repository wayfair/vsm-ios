//
//  AppDependencies.swift
//  Shopping
//
//  Created by Albert Bori on 2/12/22.
//

import Foundation

class AppDependencies: MainView.Dependencies {
    var productRepository: ProductRepository
    var cartRepository: CartRepository
    var favoritesRepository: FavoritesRepository
    var dispatchQueue: DispatchQueueScheduling
    var userDefaults: UserDefaults
    var frameworkProvider: UIFrameworkProviding
    
    init(
        productRepository: ProductRepository,
        cartRepository: CartRepository,
        favoritesRepository: FavoritesRepository,
        dispatchQueue: DispatchQueueScheduling,
        userDefaults: UserDefaults,
        frameworkProvider: UIFrameworkProviding
    ) {
        self.productRepository = productRepository
        self.cartRepository = cartRepository
        self.favoritesRepository = favoritesRepository
        self.dispatchQueue = dispatchQueue
        self.userDefaults = userDefaults
        self.frameworkProvider = frameworkProvider
    }
}

// MARK: - Implementation

extension AppDependencies {
    static func buildProvider() -> AsyncResource<MainView.Dependencies> {
        return AsyncResource<MainView.Dependencies>({
            try await withCheckedThrowingContinuation({ continuation in
                DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
                    let productRepository = ProductDatabase()
                    let cartRepository = CartDatabase(dependencies: CartDatabaseDependencies(productRepository: productRepository))
                    let favoritesRepository = FavoritesDatabase(dependencies: FavoritesDatabaseDependencies(productRepository: productRepository))
                    let appDependencies = AppDependencies(
                        productRepository: productRepository,
                        cartRepository: cartRepository,
                        favoritesRepository: favoritesRepository,
                        dispatchQueue: DispatchQueueScheduler(),
                        userDefaults: UserDefaults.standard,
                        frameworkProvider: UIFrameworkProvider(dependencies: UIFrameworkProviderDependencies(userDefaults: UserDefaults.standard))
                    )
                    continuation.resume(returning: appDependencies)
                }
            })
        })
    }
}

// MARK: Test Support

struct MockAppDependencies: MainView.Dependencies {
    static var noOp: MockAppDependencies {
        MockAppDependencies(
            mockProductRepository: MockProductRepository.noOp,
            mockCartRepository: MockCartRepository.noOp,
            mockFavoritesRepository: MockFavoritesRepository.noOp,
            mockDispatchQueue: MockDispatchQueueScheduler.immediate,
            mockUserDefaults: UserDefaults(),
            mockUIFrameworkProvider: MockUIFrameworkProvider.noOp
        )
    }
    
    var mockProductRepository: MockProductRepository
    var mockCartRepository: MockCartRepository
    var mockFavoritesRepository: MockFavoritesRepository
    var mockDispatchQueue: MockDispatchQueueScheduler
    var mockUserDefaults: UserDefaults
    var mockUIFrameworkProvider: MockUIFrameworkProvider
    
    var productRepository: ProductRepository {
        mockProductRepository
    }
    
    var cartRepository: CartRepository {
        mockCartRepository
    }
    
    var favoritesRepository: FavoritesRepository {
        mockFavoritesRepository
    }
    
    var dispatchQueue: DispatchQueueScheduling {
        mockDispatchQueue
    }
    
    var userDefaults: UserDefaults {
        mockUserDefaults
    }
    
    var frameworkProvider: UIFrameworkProviding {
        mockUIFrameworkProvider
    }
}
