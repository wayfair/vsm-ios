//
//  FavoritesRepository.swift
//  Shopping
//
//  Created by Albert Bori on 2/9/22.
//

import Foundation

protocol FavoritesRepository: Actor {
    func getFavoritedProducts() async throws -> [FavoritedProduct]
    func addFavorite(productId: Int, name: String) async throws
    func removeFavorite(productId: Int) async throws
    func isFavorited(productId: Int) async throws -> Bool
    func favoriteStatusStream(for productId: Int) async -> AsyncStream<Bool>
    func removeFavoriteStatusStream(for productId: Int) async
    func favoritesListChangeStream() async -> AsyncStream<Void>
    func removeFavoritesListChangeStream() async
}

protocol FavoritesRepositoryDependency {
    var favoritesRepository: FavoritesRepository { get }
}

struct FavoritedProduct: Equatable {
    let id: Int
    let name: String
}

//MARK: - Implementation

final actor FavoritesDatabase: FavoritesRepository {
    typealias Dependencies = ProductRepositoryDependency
    
    private let dependencies: Dependencies
    private var favoritedProducts: [Int: String] = [:]
    private var favoriteStatusContinuations: [Int: [UUID: AsyncStream<Bool>.Continuation]] = [:]
    private var favoritesListChangeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]
    
    init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }
    
    deinit {
        favoriteStatusContinuations.values.forEach { continuations in
            continuations.values.forEach { $0.finish() }
        }
        favoriteStatusContinuations.removeAll()
        favoritesListChangeContinuations.values.forEach { $0.finish() }
        favoritesListChangeContinuations.removeAll()
    }
    
    func favoriteStatusStream(for productId: Int) async -> AsyncStream<Bool> {
        let streamId = UUID()
        let currentStatus = favoritedProducts[productId] != nil
        let stream = AsyncStream<Bool> { continuation in
            if favoriteStatusContinuations[productId] == nil {
                favoriteStatusContinuations[productId] = [:]
            }
            favoriteStatusContinuations[productId]?[streamId] = continuation
            
            // Immediately yield the current status
            continuation.yield(currentStatus)
            
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeFavoriteStatusStream(for: productId, streamId: streamId) }
            }
        }
        return stream
    }
    
    func removeFavoriteStatusStream(for productId: Int) async {
        // This is called from the protocol but we'll keep it for backward compatibility
        // It now removes all streams for this product
        favoriteStatusContinuations[productId]?.values.forEach { $0.finish() }
        favoriteStatusContinuations.removeValue(forKey: productId)
    }
    
    private func removeFavoriteStatusStream(for productId: Int, streamId: UUID) {
        favoriteStatusContinuations[productId]?[streamId]?.finish()
        favoriteStatusContinuations[productId]?.removeValue(forKey: streamId)
        if favoriteStatusContinuations[productId]?.isEmpty == true {
            favoriteStatusContinuations.removeValue(forKey: productId)
        }
    }
    
    func favoritesListChangeStream() async -> AsyncStream<Void> {
        let streamId = UUID()
        let stream = AsyncStream<Void> { continuation in
            favoritesListChangeContinuations[streamId] = continuation
            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeFavoritesListChangeStream(streamId: streamId) }
            }
        }
        return stream
    }
    
    func removeFavoritesListChangeStream() async {
        // This is called from the protocol but we'll keep it for backward compatibility
        // It now removes all list change streams
        favoritesListChangeContinuations.values.forEach { $0.finish() }
        favoritesListChangeContinuations.removeAll()
    }
    
    private func removeFavoritesListChangeStream(streamId: UUID) {
        favoritesListChangeContinuations[streamId]?.finish()
        favoritesListChangeContinuations.removeValue(forKey: streamId)
    }
    
    func isFavorited(productId: Int) async throws -> Bool {
        try await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        return (favoritedProducts[productId] != nil)
    }
    
    func getFavoritedProducts() async throws -> [FavoritedProduct] {
        try await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        
        return favoritedProducts.map { key, value in
            FavoritedProduct(id: key, name: value)
        }
    }
    
    func addFavorite(productId: Int, name: String) async throws {
        try await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        
        favoritedProducts[productId] = name
        favoriteStatusContinuations[productId]?.values.forEach { $0.yield(true) }
        favoritesListChangeContinuations.values.forEach { $0.yield(()) }
    }
    
    func removeFavorite(productId: Int) async throws {
        try await Task.sleep(for: AppConstants.simulatedAsyncNetworkDelay)
        
        if favoritedProducts[productId] != nil {
            favoritedProducts.removeValue(forKey: productId)
            favoriteStatusContinuations[productId]?.values.forEach { $0.yield(false) }
            favoritesListChangeContinuations.values.forEach { $0.yield(()) }
        }
    }
}

struct FavoritesDatabaseDependencies: FavoritesDatabase.Dependencies {
    var productRepository: ProductRepository
}

//MARK: Test Support

/// Test and preview stand-in; stub closures run on this actor’s executor.
actor MockFavoritesRepository: FavoritesRepository {
    
    init(
        getFavoritedProductsImpl: @escaping () async throws -> [FavoritedProduct],
        addFavoriteImpl: @escaping (Int, String) async throws -> Void,
        removeFavoriteImpl: @escaping (Int) async throws -> Void,
        isFavoritedImpl: @escaping (Int) async throws -> Bool,
        favoriteStatusStreamImpl: @escaping (Int) async -> AsyncStream<Bool>,
        removeFavoriteStatusStreamImpl: @escaping (Int) async -> Void,
        favoritesListChangeStreamImpl: @escaping () async -> AsyncStream<Void>,
        removeFavoritesListChangeStreamImpl: @escaping () async -> Void
    ) {
        self.getFavoritedProductsImpl = getFavoritedProductsImpl
        self.addFavoriteImpl = addFavoriteImpl
        self.removeFavoriteImpl = removeFavoriteImpl
        self.isFavoritedImpl = isFavoritedImpl
        self.favoriteStatusStreamImpl = favoriteStatusStreamImpl
        self.removeFavoriteStatusStreamImpl = removeFavoriteStatusStreamImpl
        self.favoritesListChangeStreamImpl = favoritesListChangeStreamImpl
        self.removeFavoritesListChangeStreamImpl = removeFavoritesListChangeStreamImpl
    }
    
    nonisolated static func noOp() -> MockFavoritesRepository {
        MockFavoritesRepository(
            getFavoritedProductsImpl: { [] },
            addFavoriteImpl: { _, _ in },
            removeFavoriteImpl: { _ in },
            isFavoritedImpl: { _ in false },
            favoriteStatusStreamImpl: { _ in AsyncStream { _ in } },
            removeFavoriteStatusStreamImpl: { _ in },
            favoritesListChangeStreamImpl: { AsyncStream { _ in } },
            removeFavoritesListChangeStreamImpl: { }
        )
    }
    
    let getFavoritedProductsImpl: () async throws -> [FavoritedProduct]
    func getFavoritedProducts() async throws -> [FavoritedProduct] {
        try await getFavoritedProductsImpl()
    }
    
    let addFavoriteImpl: (Int, String) async throws -> Void
    func addFavorite(productId: Int, name: String) async throws {
        try await addFavoriteImpl(productId, name)
    }
    
    let removeFavoriteImpl: (Int) async throws -> Void
    func removeFavorite(productId: Int) async throws {
        try await removeFavoriteImpl(productId)
    }
    
    let isFavoritedImpl: (Int) async throws -> Bool
    func isFavorited(productId: Int) async throws -> Bool {
        try await isFavoritedImpl(productId)
    }
    
    let favoriteStatusStreamImpl: (Int) async -> AsyncStream<Bool>
    func favoriteStatusStream(for productId: Int) async -> AsyncStream<Bool> {
        await favoriteStatusStreamImpl(productId)
    }
    
    let removeFavoriteStatusStreamImpl: (Int) async -> Void
    func removeFavoriteStatusStream(for productId: Int) async {
        await removeFavoriteStatusStreamImpl(productId)
    }
    
    let favoritesListChangeStreamImpl: () async -> AsyncStream<Void>
    func favoritesListChangeStream() async -> AsyncStream<Void> {
        await favoritesListChangeStreamImpl()
    }
    
    let removeFavoritesListChangeStreamImpl: () async -> Void
    func removeFavoritesListChangeStream() async {
        await removeFavoritesListChangeStreamImpl()
    }
}



