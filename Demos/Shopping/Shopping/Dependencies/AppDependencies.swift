//
//  AppDependencies.swift
//  Shopping
//
//  Created by Albert Bori on 2/12/22.
//

import Foundation

enum AppConstants {
    static var simulatedNetworkDuration: TimeInterval = 1
    static var simulatedNetworkNanoseconds: UInt64 { UInt64(simulatedNetworkDuration * 1_000_000_000) }
    static var simulatedNetworkDelay: DispatchTime { .now() + simulatedNetworkDuration }
}

class AppDependencies: MainView.Dependencies {
    var productRepository: ProductRepository
    var cartRepository: CartRepository
    var favoritesRepository: FavoritesRepository
    var dispatchQueue: DispatchQueueScheduling
    var userDefaults: UserDefaults
    var frameworkProvider: UIFrameworkProviding
    var profileRepository: ProfileRepository
    
    init(
        productRepository: ProductRepository,
        cartRepository: CartRepository,
        favoritesRepository: FavoritesRepository,
        dispatchQueue: DispatchQueueScheduling,
        userDefaults: UserDefaults,
        frameworkProvider: UIFrameworkProviding,
        profileRepository: ProfileRepository
    ) {
        self.productRepository = productRepository
        self.cartRepository = cartRepository
        self.favoritesRepository = favoritesRepository
        self.dispatchQueue = dispatchQueue
        self.userDefaults = userDefaults
        self.frameworkProvider = frameworkProvider
        self.profileRepository = profileRepository
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
                    
                    // Stub user defaults with an ephemeral implementation if this is a UI test
                    let userDefaults = ShoppingApp.isUITesting ? StubbedUserDefaults() : UserDefaults.standard
                    
                    let appDependencies = AppDependencies(
                        productRepository: productRepository,
                        cartRepository: cartRepository,
                        favoritesRepository: favoritesRepository,
                        dispatchQueue: DispatchQueueScheduler(),
                        userDefaults: userDefaults,
                        frameworkProvider: UIFrameworkProvider(dependencies: UIFrameworkProviderDependencies(userDefaults: UserDefaults.standard)),
                        profileRepository: ProfileDatabase()
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
            mockUIFrameworkProvider: MockUIFrameworkProvider.noOp,
            mockProfileRepository: MockProfileRepository.noOp
        )
    }
    
    var mockProductRepository: MockProductRepository
    var mockCartRepository: MockCartRepository
    var mockFavoritesRepository: MockFavoritesRepository
    var mockDispatchQueue: MockDispatchQueueScheduler
    var mockUserDefaults: UserDefaults
    var mockUIFrameworkProvider: MockUIFrameworkProvider
    var mockProfileRepository: MockProfileRepository
    
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
    
    var profileRepository: ProfileRepository {
        mockProfileRepository
    }
}
