//
//  AppDependencies.swift
//  Shopping
//
//  Created by Albert Bori on 2/12/22.
//

import Foundation

enum AppConstants {
    static var simulatedNetworkDelay: DispatchTime { .now() + 1 }
}

class AppDependencies: MainView.Dependencies {
    var productRepository: ProductRepository
    var cartRepository: CartRepository
    var favoritesRepository: FavoritesRepository
    var dispatchQueue: DispatchQueueScheduling
    var userDefaults: UserDefaults
    
    init(
        productRepository: ProductRepository,
        cartRepository: CartRepository,
        favoritesRepository: FavoritesRepository,
        dispatchQueue: DispatchQueueScheduling,
        userDefaults: UserDefaults
    ) {
        self.productRepository = productRepository
        self.cartRepository = cartRepository
        self.favoritesRepository = favoritesRepository
        self.dispatchQueue = dispatchQueue
        self.userDefaults = userDefaults
    }
}

// MARK: - Implementation

extension AppDependencies {
    static func buildProvider() -> AsyncResource<MainView.Dependencies> {
        return AsyncResource<MainView.Dependencies>({
            try await withCheckedThrowingContinuation({ continuation in
                DispatchQueue.global().asyncAfter(deadline: AppConstants.simulatedNetworkDelay) {
                    let productRepository = ProductDatabase()
                    let cartRepository = CartDatabase(dependencies: CartDatabaseDependencies(productRepository: productRepository))
                    let favoritesRepository = FavoritesDatabase(dependencies: FavoritesDatabaseDependencies(productRepository: productRepository))
                    let appDependencies = AppDependencies(
                        productRepository: productRepository,
                        cartRepository: cartRepository,
                        favoritesRepository: favoritesRepository,
                        dispatchQueue: DispatchQueueScheduler(),
                        userDefaults: UserDefaults.standard
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
            mockUserDefaults: UserDefaults()
        )
    }
    
    var mockProductRepository: MockProductRepository
    var mockCartRepository: MockCartRepository
    var mockFavoritesRepository: MockFavoritesRepository
    var mockDispatchQueue: MockDispatchQueueScheduler
    var mockUserDefaults: UserDefaults
    
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
}
