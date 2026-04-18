//
//  AppDependencies.swift
//  Shopping
//
//  Created by Albert Bori on 2/12/22.
//

import Foundation

enum AppConstants {
    static let simulatedNetworkDuration: TimeInterval = 1
    static var simulatedNetworkNanoseconds: UInt64 { UInt64(simulatedNetworkDuration * 1_000_000_000) }
    static var simulatedNetworkDelay: DispatchTime { .now() + simulatedNetworkDuration }
    
    static var simulatedAsyncNetworkDelay: Duration { .seconds(1) }
}

final class AppDependencies: MainView.Dependencies {
    let productRepository: ProductRepository
    let cartRepository: CartRepository
    let favoritesRepository: FavoritesRepository
    let userDefaults: UserDefaultsProtocol
    let frameworkProvider: UIFrameworkProviding
    let profileRepository: ProfileRepository
    
    init(
        productRepository: ProductRepository,
        cartRepository: CartRepository,
        favoritesRepository: FavoritesRepository,
        userDefaults: UserDefaultsProtocol,
        frameworkProvider: UIFrameworkProviding,
        profileRepository: ProfileRepository
    ) {
        self.productRepository = productRepository
        self.cartRepository = cartRepository
        self.favoritesRepository = favoritesRepository
        self.userDefaults = userDefaults
        self.frameworkProvider = frameworkProvider
        self.profileRepository = profileRepository
    }
}

// MARK: - Dependencies Providing Protocol

protocol DependenciesProviding {
    func buildDependencies() async -> MainView.Dependencies
}

// MARK: - Concrete Provider Implementation

struct DependenciesProvider: DependenciesProviding {
    func buildDependencies() async -> MainView.Dependencies {
        try? await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        
        let productRepository = ProductDatabase()
        let cartRepository = CartDatabase(dependencies: CartDatabaseDependencies(productRepository: productRepository))
        let favoritesRepository = FavoritesDatabase(dependencies: FavoritesDatabaseDependencies(productRepository: productRepository))
        
        // Stub user defaults with an ephemeral implementation if this is a UI test
        let isUITesting = await ShoppingApp.isUITesting
        let userDefaults: UserDefaultsProtocol = isUITesting ? StubbedUserDefaults() : UserDefaultsWrapper()
        
        return AppDependencies(
            productRepository: productRepository,
            cartRepository: cartRepository,
            favoritesRepository: favoritesRepository,
            userDefaults: userDefaults,
            frameworkProvider: UIFrameworkProvider(dependencies: UIFrameworkProviderDependencies(userDefaults: UserDefaultsWrapper())),
            profileRepository: ProfileDatabase()
        )
    }
}

// MARK: - Legacy Static Method (Deprecated)

extension AppDependencies {
    static func buildProvider() async -> MainView.Dependencies {
        await DependenciesProvider().buildDependencies()
    }
}

// MARK: Test Support

struct MockDependenciesProvider: DependenciesProviding {
    let dependencies: MainView.Dependencies
    
    init(dependencies: MainView.Dependencies = MockAppDependencies.noOp()) {
        self.dependencies = dependencies
    }
    
    func buildDependencies() async -> MainView.Dependencies {
        dependencies
    }
}

struct MockAppDependencies: MainView.Dependencies {
    static func noOp() -> MockAppDependencies {
        MockAppDependencies(
            mockProductRepository: MockProductRepository.noOp(),
            mockCartRepository: MockCartRepository.noOp(),
            mockFavoritesRepository: MockFavoritesRepository.noOp(),
            mockUserDefaults: StubbedUserDefaults(),
            mockUIFrameworkProvider: MockUIFrameworkProvider.noOp(),
            mockProfileRepository: MockProfileRepository.noOp()
        )
    }
    
    let mockProductRepository: MockProductRepository
    let mockCartRepository: MockCartRepository
    let mockFavoritesRepository: MockFavoritesRepository
    let mockUserDefaults: UserDefaultsProtocol
    let mockUIFrameworkProvider: MockUIFrameworkProvider
    let mockProfileRepository: MockProfileRepository
    
    var productRepository: ProductRepository {
        mockProductRepository
    }
    
    var cartRepository: CartRepository {
        mockCartRepository
    }
    
    var favoritesRepository: FavoritesRepository {
        mockFavoritesRepository
    }
    
    var userDefaults: UserDefaultsProtocol {
        mockUserDefaults
    }
    
    var frameworkProvider: UIFrameworkProviding {
        mockUIFrameworkProvider
    }
    
    var profileRepository: ProfileRepository {
        mockProfileRepository
    }
}
